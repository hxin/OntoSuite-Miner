#!/usr/bin/perl
########################################################
## This script is used to filter metamap & ncbo annotation
## input file should look something like this:
##	17608565	GO:1990603	dark adaptation	750	m
##	17608565	GO:2000144	transactivation (positive regulation of DNA-templated transcription, initiation)	614	m
##	17608565	GO:0007067	MITOSIS		n
##
## It require a sqlite db to retrive parent/children relationship. This db can be generated with the script 'create_ontology_sqlite_queries.pl' and an ontology obo file.
## 
## Stopwords can be specified in a text file in the same folder as the script and it should looks like this:
## 	DOID:4
##	DOID:225
## xin 04/02/2015
#######################################################




use strict;
use Data::Dumper;
use Getopt::Long;
use DBI;

my $usage = <<"USAGE";

########################################################
## This script is used to filter metamap & ncbo annotation
## input file should look something like this:
##	17608565	GO:1990603	dark adaptation	750	m
##	17608565	GO:2000144	transactivation (positive regulation of DNA-templated transcription, initiation)	614	m
##	17608565	GO:0007067	MITOSIS		n
##
## It require a sqlite db to retrive parent/children relationship. This db can be generated with the script 'create_ontology_sqlite_queries.pl' and an ontology obo file.
## 
## Stopwords can be specified in a text file in the same folder as the script and it should looks like this:
## 	DOID:4
##	DOID:225
## 
##
## xin 04/02/2015
#######################################################

Usage: $0 -i mapping.txt -o mapping.filtered -l xxx.sqlite -s xx.txt

 -i, --mapping_file 
 -o, --output
 -l, --dbfile
 -s, --stopwords

Example:perl $0 --mapping_file /home/xin/Workspace/DisEnt/disent/data/craft-1.0/articles/data/final4filter 
--out /home/xin/Workspace/DisEnt/disent/data/craft-1.0/articles/data/final4filter.filtered 
--dbfile /home/xin/Workspace/DisEnt/disent/data/GeneOntology.sqlite
--stopwords /home/xin/Workspace/DisEnt/disent/term_mapping/filter/stopwords

USAGE

if (!$ARGV[0]) {
	print $usage;
	exit;
}

my $options={};
GetOptions($options,
	  	   "help|h",
           "mapping_file|i=s"=>\my $in,
           "output|o=s"=>\my $out,
           "dbfile|l=s"=>\my $dbfile,
           "stopwords|s=s"=>\my $stopwords_source
           #"ontology_full_name|fn=s"=>\my $ontology_name,
	  );

if ($options->{help}) {
	print $usage;
	exit;
}


##config
my $MM_CUTOFF=600;

##final result will be save here
my $all={};
##db statement
my $sth;


#my $in = '/home/xin/Workspace/DisEnt/disent/annotation_sources/omim/data/HDO/d2t_raw';
#my $out = '/home/xin/Desktop/1';
#my $dbfile= '/home/xin/Workspace/DisEnt/disent/data/HDO.sqlite';
#my $stopwords_source='/home/xin/Workspace/DisEnt/disent/term_mapping/filter/stopwords';

my $stopwords_hashref;

##load stopwords
open (STOPWORD, $stopwords_source);
while (<STOPWORD>) {
	chomp;
	$stopwords_hashref->{$_}=1;
}

##connect to db
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
print "error connecting dbfile:$dbfile" if !$dbh->ping;

my $clookup=getChildrenLookup();
my $plookup=getParentsLookup();
my $alookup=getAltidTable();


open (MAPPING, $in);
while (<MAPPING>) {
	my $line = $_;
	chomp($line);
	my @items = split(/\t/, $line);
	#"Observational study of gene-disease association. (HuGE Navigator)","DOID:4","disease","581","m"
	my $mapping = new Mapping($items[1],$items[2],$items[3],$items[4]);
	push(@{$all->{$items[0]}},$mapping);
}

#print Dumper($all);

##filter
foreach my $des(keys %$all){
		my @keep_tmp;
		my @keep;
		my @delete;
		my @mappings = @{$all->{$des}};
		 	 
		##remove mapping in the stopwords
		@mappings = map {$_} grep { !exists($stopwords_hashref->{$_->getTid})} @mappings;
		
		##sort mm mapping by score and remove duplicate
		my @metamap = map {$_} grep { $_->getSource eq 'm' and $_->getScore > $MM_CUTOFF} @mappings;		
		@metamap = sort {$b->getScore <=> $a->getScore} @metamap;
		my %tmp;
		foreach my $mm(@metamap){
			if(defined $mm &  !exists($tmp{$mm->getTid})){
				$tmp{$mm->getTid}=1;
				push @keep,$mm;
			}
		}
		
		
		##if the term is found by NCBO, keep it.
		my %ncbo = map {$_->getTid=>$_} grep { $_->getSource eq 'n'} @mappings;
		##remove duplicate
		my @ncbo = values %ncbo;
		push @keep,@ncbo if(@ncbo);
		
#		##if the term is found by MetaMap and has the highest score, keep it.
#		my @metamap = map {$_} grep { $_->getSource eq 'm'} @mappings;
#		@metamap = sort {$b->getScore <=> $a->getScore} @metamap;
#		push @keep_tmp,@metamap[0] if defined(@metamap[0]);
		
		
		my %keep_Tid = map {$_->getTid=>1}  @keep;
		#remove duplicate item caused by alt_id
		#this may cause by alt_id. For example, DOID:0000000 is an alt_id of DOID:0060262
		foreach my $id(keys %keep_Tid){
			if(exists($alookup->{$id})){
				my $main_id=$alookup->{$id};
				if(exists($keep_Tid{$main_id})){
					$keep_Tid{$id}=0; 	
				}
			}
		}
		
		##only keep the most specified terms			
		foreach my $id(keys %keep_Tid){
			if($keep_Tid{$id}==1){
				my @ps=@{$plookup->{$id}} if(exists($plookup->{$id}));
				my @cs=@{$clookup->{$id}} if(exists($clookup->{$id})) ;
				##remove all parents
				if(@ps){
					foreach(@ps){
						$keep_Tid{$_}=0 if(exists($keep_Tid{$_}));	
					}
				}
				##remove self if it's parent of any terms
				if(@cs){
					my @c = grep( $keep_Tid{$_}, @cs );
					$keep_Tid{$id}=0 if(@c);
				}
			}
		}
		
		@keep = map {$_} grep { $keep_Tid{$_->getTid}==1} @keep;
		##filtering end
		@{$all->{$des}} = @keep;
		#print Dumper($all->{$des});
}


##output result
open (OUT,'>' ,$out);
foreach my $des(keys %$all){
		foreach(@{$all->{$des}}){
			printf OUT ("%s\t%s\t%s\t%s\t%s\n",$des,$_->getTid,$_->getTname,$_->getScore,$_->getSource);	
		}
}



sub getAltidTable{
	my $query="select t2.synonym,t1.id from term as t1,
				(select * from synonym where like_term_id=1) as t2
				where t1._id=t2._id";
	my $sth = $dbh->prepare($query);
	$sth->execute();	
	my $result={};
	while (my @row = $sth->fetchrow_array) { # retrieve one row
		$result->{$row[0]}=$row[1];
	}
	return $result;		
}



sub getChildrenLookup{
	my $query="select t2.id as parent, t1._offspring_id as child from 
				(select offspring._id ,term.id as  _offspring_id from offspring left join term on offspring._offspring_id=term._id) as t1 left join term as t2
				on t1._id=t2._id;";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	my $result={};
	while (my @row = $sth->fetchrow_array) { # retrieve one row
		if( !exists($result->{$row[0]}) ){
			$result->{$row[0]}=[];
		}
    	push($result->{$row[0]},$row[1]);
	}
	return $result;
}

sub getParentsLookup{
	my $query="select t1._offspring_id as child,t2.id as parent from 
				(select offspring._id ,term.id as  _offspring_id from offspring left join term on offspring._offspring_id=term._id) as t1 left join term as t2
				on t1._id=t2._id;";
	my $sth = $dbh->prepare($query);
	$sth->execute();
	my $result={};
	while (my @row = $sth->fetchrow_array) { # retrieve one row
		if( !exists($result->{$row[0]}) ){
			$result->{$row[0]}=[];
		}	
    	push($result->{$row[0]},$row[1]);
	}
	return $result;
}





package Mapping;
sub new
{
    my $class = shift;
    my $self = {
    	_tid => shift,
    	_tname=>shift,
    	_score =>shift,
    	_source =>shift,
    };
    bless $self, $class;
    return $self;
}



sub setSource{
	my ($self, $source) = @_;
	$self->{_source}= $source;
	return $self->{_source};
}
sub getSource{
	my ($self) = @_;
	return $self->{_source};
}



sub getTid{
	my ($self) = @_;
	return $self->{_tid};
}

sub getDes{
	my ($self) = @_;
	return $self->{_des};
}

sub getScore{
	my ($self) = @_;
	return $self->{_score};
}

sub getTname{
	my ($self) = @_;
	return $self->{_tname};
}





#$VAR1 = {
#          'The presence of MPO-G/G and A2M-Val/Val genotypes synergistically increased the risk of AD (OR, 25.5; 95% CI, 4.65-139.75).' => [
#                                                                                                                                             bless( {
#                                                                                                                                                      '_source' => 'm',
#                                                                                                                                                      '_tname' => 'AD (Alzheimer\'s disease)',
#                                                                                                                                                      '_tid' => 'DOID:10652',
#                                                                                                                                                      '_score' => '728'
#                                                                                                                                                    }, 'Mapping' )
#                                                                                                                                           ],
#          'A2M allele and genotype frequencies were similar between AD patients and controls.' => [
#                                                                                                    bless( {
#                                                                                                             '_source' => 'm',
#                                                                                                             '_tname' => 'AD (Alzheimer\'s disease)',
#                                                                                                             '_tid' => 'DOID:10652',
#                                                                                                             '_score' => '569'
#                                                                                                           }, 'Mapping' )
#                                                                                                  ],
#          'the inhibition of proteases on the surface of microorganisms by an ancestral alpha2M-like thiol ester protein may generate "arrays" of oligomannose glycans to which MBL or other lectins can bind' => [
#                                                                                                                                                                                                                    bless( {
#                                                                                                                                                                                                                             '_source' => 'm',
#                                                                                                                                                                                                                             '_tname' => 'CAN (chronic rejection of renal transplant)',
#                                                                                                                                                                                                                             '_tid' => 'DOID:2985',
#                                                                                                                                                                                                                             '_score' => '727'
#                                                                                                                                                                                                                           }, 'Mapping' )
#                                                                                                                                                                                                                  ],
#          'Ethnicity affects the genetic association of A2M with rheumatoid arthritis in South Asian and Caucasian patients living in East Midlands/United Kingdom.' => [
#                                                                                                                                                                          bless( {
#                                                                                                                                                                                   '_source' => 'm',
#                                                                                                                                                                                   '_tname' => 'rheumatoid arthritis',
#                                                                                                                                                                                   '_tid' => 'DOID:7148',
#                                                                                                                                                                                   '_score' => '570'
#                                                                                                                                                                                 }, 'Mapping' ),
#                                                                                                                                                                          bless( {
#                                                                                                                                                                                   '_source' => 'n',
#                                                                                                                                                                                   '_tname' => 'RHEUMATOID ARTHRITIS',
#                                                                                                                                                                                   '_tid' => 'DOID:7148',
#                                                                                                                                                                                   '_score' => ''
#                                                                                                                                                                                 }, 'Mapping' ),
#                                                                                                                                                                          bless( {
#                                                                                                                                                                                   '_source' => 'n',
#                                                                                                                                                                                   '_tname' => 'ARTHRITIS',
#                                                                                                                                                                                   '_tid' => 'DOID:848',
#                                                                                                                                                                                   '_score' => ''
#                                                                                                                                                                                 }, 'Mapping' )
#                                                                                                                                                                        ],
#          'an important involvement of alpha2M in regulation of increased proteolytic activity occurring in multiple sclerosis disease' => [
#                                                                                                                                             bless( {
#                                                                                                                                                      '_source' => 'm',
#                                                                                                                                                      '_tname' => 'multiple sclerosis',
#                                                                                                                                                      '_tid' => 'DOID:2377',
#                                                                                                                                                      '_score' => '743'
#                                                                                                                                                    }, 'Mapping' ),
#                                                                                                                                             bless( {
#                                                                                                                                                      '_source' => 'm',
#                                                                                                                                                      '_tname' => 'disease',
#                                                                                                                                                      '_tid' => 'DOID:4',
#                                                                                                                                                      '_score' => '732'
#                                                                                                                                                    }, 'Mapping' ),
#                                                                                                                                             bless( {
#                                                                                                                                                      '_source' => 'n',
#                                                                                                                                                      '_tname' => 'MULTIPLE SCLEROSIS',
#                                                                                                                                                      '_tid' => 'DOID:2377',
#                                                                                                                                                      '_score' => ''
#                                                                                                                                                    }, 'Mapping' ),
#                                                                                                                                             bless( {
#                                                                                                                                                      '_source' => 'n',
#                                                                                                                                                      '_tname' => 'DISEASE',
#                                                                                                                                                      '_tid' => 'DOID:4',
#                                                                                                                                                      '_score' => ''
#                                                                                                                                                    }, 'Mapping' )
#                                                                                                                                           ],
#          'Observational study of gene-disease association and gene-gene interaction. (HuGE Navigator)' => [
#                                                                                                             bless( {
#                                                                                                                      '_source' => 'm',
#                                                                                                                      '_tname' => 'disease',
#                                                                                                                      '_tid' => 'DOID:4',
#                                                                                                                      '_score' => '571'
#                                                                                                                    }, 'Mapping' ),
#                                                                                                             bless( {
#                                                                                                                      '_source' => 'n',
#                                                                                                                      '_tname' => 'DISEASE',
#                                                                                                                      '_tid' => 'DOID:4',
#                                                                                                                      '_score' => ''
#                                                                                                                    }, 'Mapping' )
#                                                                                                           ],
#          'An ancestral risk haplotype clade in ACE and putative multilocus association between ACE, A2M, and LRRTM3 in Alzheimer disease.' => [
#                                                                                                                                                 bless( {
#                                                                                                                                                          '_source' => 'm',
#                                                                                                                                                          '_tname' => 'Alzheimer\'s disease',
#                                                                                                                                                          '_tid' => 'DOID:10652',
#                                                                                                                                                          '_score' => '739'
#                                                                                                                                                        }, 'Mapping' ),
#                                                                                                                                                 bless( {
#                                                                                                                                                          '_source' => 'n',
#                                                                                                                                                          '_tname' => 'ALZHEIMER DISEASE',
#                                                                                                                                                          '_tid' => 'DOID:10652',
#                                                                                                                                                          '_score' => ''
#                                                                                                                                                        }, 'Mapping' ),
#                                                                                                                                                 bless( {
#                                                                                                                                                          '_source' => 'n',
#                                                                                                                                                          '_tname' => 'DISEASE',
#                                                                                                                                                          '_tid' => 'DOID:4',
#                                                                                                                                                          '_score' => ''
#                                                                                                                                                        }, 'Mapping' )
#                                                                                                                                               ],
#          'Genetic association of argyrophilic grain disease with polymorphisms in alpha-2 macroglobulin.' => [
#                                                                                                                bless( {
#                                                                                                                         '_source' => 'm',
#                                                                                                                         '_tname' => 'genetic disease',
#                                                                                                                         '_tid' => 'DOID:630',
#                                                                                                                         '_score' => '582'
#                                                                                                                       }, 'Mapping' ),
#                                                                                                                bless( {
#                                                                                                                         '_source' => 'n',
#                                                                                                                         '_tname' => 'DISEASE',
#                                                                                                                         '_tid' => 'DOID:4',
#                                                                                                                         '_score' => ''
#                                                                                                                       }, 'Mapping' )
#                                                                                                              ],
#          'Observational study of gene-disease association. (HuGE Navigator)' => [
#                                                                                   bless( {
#                                                                                            '_source' => 'm',
#                                                                                            '_tname' => 'disease',
#                                                                                            '_tid' => 'DOID:4',
#                                                                                            '_score' => '581'
#                                                                                          }, 'Mapping' ),
#                                                                                   bless( {
#                                                                                            '_source' => 'n',
#                                                                                            '_tname' => 'DISEASE',
#                                                                                            '_tid' => 'DOID:4',
#                                                                                            '_score' => ''
#                                                                                          }, 'Mapping' )
#                                                                                 ],
#          'Overexpression of serum A1BG is associated with non-small cell lung cancer.' => [
#                                                                                             bless( {
#                                                                                                      '_source' => 'm',
#                                                                                                      '_tname' => 'cancer of lung (lung carcinoma)',
#                                                                                                      '_tid' => 'DOID:3905',
#                                                                                                      '_score' => '595'
#                                                                                                    }, 'Mapping' ),
#                                                                                             bless( {
#                                                                                                      '_source' => 'n',
#                                                                                                      '_tname' => 'CANCER',
#                                                                                                      '_tid' => 'DOID:162',
#                                                                                                      '_score' => ''
#                                                                                                    }, 'Mapping' ),
#                                                                                             bless( {
#                                                                                                      '_source' => 'n',
#                                                                                                      '_tname' => 'LUNG CANCER',
#                                                                                                      '_tid' => 'DOID:1324',
#                                                                                                      '_score' => ''
#                                                                                                    }, 'Mapping' )
#                                                                                           ],
#          'MMP-9, DJ-1 and A1BG proteins are overexpressed in pancreatic juice from pancreatic ductal adenocarcinoma' => [
#                                                                                                                           bless( {
#                                                                                                                                    '_source' => 'm',
#                                                                                                                                    '_tname' => 'pancreatic ductal adenocarcinoma',
#                                                                                                                                    '_tid' => 'DOID:3498',
#                                                                                                                                    '_score' => '753'
#                                                                                                                                  }, 'Mapping' ),
#                                                                                                                           bless( {
#                                                                                                                                    '_source' => 'n',
#                                                                                                                                    '_tname' => 'ADENOCARCINOMA',
#                                                                                                                                    '_tid' => 'DOID:299',
#                                                                                                                                    '_score' => ''
#                                                                                                                                  }, 'Mapping' ),
#                                                                                                                           bless( {
#                                                                                                                                    '_source' => 'n',
#                                                                                                                                    '_tname' => 'DUCTAL ADENOCARCINOMA',
#                                                                                                                                    '_tid' => 'DOID:3008',
#                                                                                                                                    '_score' => ''
#                                                                                                                                  }, 'Mapping' ),
#                                                                                                                           bless( {
#                                                                                                                                    '_source' => 'n',
#                                                                                                                                    '_tname' => 'PANCREATIC DUCTAL ADENOCARCINOMA',
#                                                                                                                                    '_tid' => 'DOID:3498',
#                                                                                                                                    '_score' => ''
#                                                                                                                                  }, 'Mapping' )
#                                                                                                                         ],
#          'Observational study and meta-analysis of gene-disease association. (HuGE Navigator)' => [
#                                                                                                     bless( {
#                                                                                                              '_source' => 'm',
#                                                                                                              '_tname' => 'disease',
#                                                                                                              '_tid' => 'DOID:4',
#                                                                                                              '_score' => '573'
#                                                                                                            }, 'Mapping' ),
#                                                                                                     bless( {
#                                                                                                              '_source' => 'n',
#                                                                                                              '_tname' => 'DISEASE',
#                                                                                                              '_tid' => 'DOID:4',
#                                                                                                              '_score' => ''
#                                                                                                            }, 'Mapping' )
#                                                                                                   ],
#          'Senile systemic amyloidosis was associated with age, myocardial infarctions, the G/G (Val/Val) genotype of the exon 24 polymorphism in the alpha2-macroglobulin (alpha2M), and the H2 haplotype of the tau gene' => [
#                                                                                                                                                                                                                                 bless( {
#                                                                                                                                                                                                                                          '_source' => 'm',
#                                                                                                                                                                                                                                          '_tname' => 'amyloidosis',
#                                                                                                                                                                                                                                          '_tid' => 'DOID:9120',
#                                                                                                                                                                                                                                          '_score' => '727'
#                                                                                                                                                                                                                                        }, 'Mapping' ),
#                                                                                                                                                                                                                                 bless( {
#                                                                                                                                                                                                                                          '_source' => 'm',
#                                                                                                                                                                                                                                          '_tname' => 'Myocardial Infarctions (myocardial infarction)',
#                                                                                                                                                                                                                                          '_tid' => 'DOID:5844',
#                                                                                                                                                                                                                                          '_score' => '566'
#                                                                                                                                                                                                                                        }, 'Mapping' ),
#                                                                                                                                                                                                                                 bless( {
#                                                                                                                                                                                                                                          '_source' => 'n',
#                                                                                                                                                                                                                                          '_tname' => 'AMYLOIDOSIS',
#                                                                                                                                                                                                                                          '_tid' => 'DOID:9120',
#                                                                                                                                                                                                                                          '_score' => ''
#                                                                                                                                                                                                                                        }, 'Mapping' ),
#                                                                                                                                                                                                                                 bless( {
#                                                                                                                                                                                                                                          '_source' => 'n',
#                                                                                                                                                                                                                                          '_tname' => 'MYOCARDIAL INFARCTIONS',
#                                                                                                                                                                                                                                          '_tid' => 'DOID:5844',
#                                                                                                                                                                                                                                          '_score' => ''
#                                                                                                                                                                                                                                        }, 'Mapping' )
#                                                                                                                                                                                                                               ],
#          'alpha2-macroglobulin may facilitate conformational changes in prion protein in spontaneous forms of prion disease' => [
#                                                                                                                                   bless( {
#                                                                                                                                            '_source' => 'm',
#                                                                                                                                            '_tname' => 'Prion protein disease (prion disease)',
#                                                                                                                                            '_tid' => 'DOID:649',
#                                                                                                                                            '_score' => '588'
#                                                                                                                                          }, 'Mapping' ),
#                                                                                                                                   bless( {
#                                                                                                                                            '_source' => 'n',
#                                                                                                                                            '_tname' => 'PRION DISEASE',
#                                                                                                                                            '_tid' => 'DOID:649',
#                                                                                                                                            '_score' => ''
#                                                                                                                                          }, 'Mapping' ),
#                                                                                                                                   bless( {
#                                                                                                                                            '_source' => 'n',
#                                                                                                                                            '_tname' => 'DISEASE',
#                                                                                                                                            '_tid' => 'DOID:4',
#                                                                                                                                            '_score' => ''
#                                                                                                                                          }, 'Mapping' )
#                                                                                                                                 ],
#          'Data indicate that five important proteins, vimentin, gelsolin, alpha 2 HS glycoprotein (AHSG), glial fibrillary acidic protein (GFAP), and alpha1B-glycoprotein (A1BG) were expressed higher in Rheumatoid arthritis (RA) synovial fluid than non-RA samples.' => [
#                                                                                                                                                                                                                                                                                bless( {
#                                                                                                                                                                                                                                                                                         '_source' => 'm',
#                                                                                                                                                                                                                                                                                         '_tname' => 'rheumatoid arthritis',
#                                                                                                                                                                                                                                                                                         '_tid' => 'DOID:7148',
#                                                                                                                                                                                                                                                                                         '_score' => '566'
#                                                                                                                                                                                                                                                                                       }, 'Mapping' ),
#                                                                                                                                                                                                                                                                                bless( {
#                                                                                                                                                                                                                                                                                         '_source' => 'n',
#                                                                                                                                                                                                                                                                                         '_tname' => 'RHEUMATOID ARTHRITIS',
#                                                                                                                                                                                                                                                                                         '_tid' => 'DOID:7148',
#                                                                                                                                                                                                                                                                                         '_score' => ''
#                                                                                                                                                                                                                                                                                       }, 'Mapping' ),
#                                                                                                                                                                                                                                                                                bless( {
#                                                                                                                                                                                                                                                                                         '_source' => 'n',
#                                                                                                                                                                                                                                                                                         '_tname' => 'ARTHRITIS',
#                                                                                                                                                                                                                                                                                         '_tid' => 'DOID:848',
#                                                                                                                                                                                                                                                                                         '_score' => ''
#                                                                                                                                                                                                                                                                                       }, 'Mapping' )
#                                                                                                                                                                                                                                                                              ],
#          'Genetic association of alpha2-macroglobulin polymorphisms with Alzheimer\'s disease' => [
#                                                                                                     bless( {
#                                                                                                              '_source' => 'm',
#                                                                                                              '_tname' => 'Alzheimer\'s disease',
#                                                                                                              '_tid' => 'DOID:10652',
#                                                                                                              '_score' => '593'
#                                                                                                            }, 'Mapping' ),
#                                                                                                     bless( {
#                                                                                                              '_source' => 'n',
#                                                                                                              '_tname' => 'ALZHEIMER\'S DISEASE',
#                                                                                                              '_tid' => 'DOID:10652',
#                                                                                                              '_score' => ''
#                                                                                                            }, 'Mapping' ),
#                                                                                                     bless( {
#                                                                                                              '_source' => 'n',
#                                                                                                              '_tname' => 'DISEASE',
#                                                                                                              '_tid' => 'DOID:4',
#                                                                                                              '_score' => ''
#                                                                                                            }, 'Mapping' )
#                                                                                                   ],
#          'PAK-2 is activated in 1-LN prostate cancer cells by a proteinase inhibitor, alpha 2-macroglobulin' => [
#                                                                                                                   bless( {
#                                                                                                                            '_source' => 'm',
#                                                                                                                            '_tname' => 'prostate cancer',
#                                                                                                                            '_tid' => 'DOID:10283',
#                                                                                                                            '_score' => '742'
#                                                                                                                          }, 'Mapping' ),
#                                                                                                                   bless( {
#                                                                                                                            '_source' => 'n',
#                                                                                                                            '_tname' => 'CANCER',
#                                                                                                                            '_tid' => 'DOID:162',
#                                                                                                                            '_score' => ''
#                                                                                                                          }, 'Mapping' ),
#                                                                                                                   bless( {
#                                                                                                                            '_source' => 'n',
#                                                                                                                            '_tname' => 'PROSTATE CANCER',
#                                                                                                                            '_tid' => 'DOID:10283',
#                                                                                                                            '_score' => ''
#                                                                                                                          }, 'Mapping' )
#                                                                                                                 ],
#          'an 11-fold upregulated 13.8 kDa fragment of alpha 1-B glycoprotein (A1BG) as a biomarker for steroid-resistant nephrotic syndrome' => [
#                                                                                                                                                   bless( {
#                                                                                                                                                            '_source' => 'm',
#                                                                                                                                                            '_tname' => 'nephrotic syndrome',
#                                                                                                                                                            '_tid' => 'DOID:1184',
#                                                                                                                                                            '_score' => '738'
#                                                                                                                                                          }, 'Mapping' ),
#                                                                                                                                                   bless( {
#                                                                                                                                                            '_source' => 'n',
#                                                                                                                                                            '_tname' => 'NEPHROTIC SYNDROME',
#                                                                                                                                                            '_tid' => 'DOID:1184',
#                                                                                                                                                            '_score' => ''
#                                                                                                                                                          }, 'Mapping' ),
#                                                                                                                                                   bless( {
#                                                                                                                                                            '_source' => 'n',
#                                                                                                                                                            '_tname' => 'SYNDROME',
#                                                                                                                                                            '_tid' => 'DOID:225',
#                                                                                                                                                            '_score' => ''
#                                                                                                                                                          }, 'Mapping' )
#                                                                                                                                                 ],
#          'There is a significant genetic association of the 5 bp deletion and two novel polymorphisms in alpha-2-macroglobulin alpha-2-macroglobulin precursor with AD' => [
#                                                                                                                                                                              bless( {
#                                                                                                                                                                                       '_source' => 'm',
#                                                                                                                                                                                       '_tname' => 'AD (Alzheimer\'s disease)',
#                                                                                                                                                                                       '_tid' => 'DOID:10652',
#                                                                                                                                                                                       '_score' => '728'
#                                                                                                                                                                                     }, 'Mapping' )
#                                                                                                                                                                            ],
#          'results indicate that secondary proteolysis of alpha2-macroglobulin promotes impaired control of extracellular proteolytic activity, leading to local and distant tissue injuries during severe acute pancreatitis' => [
#                                                                                                                                                                                                                                    bless( {
#                                                                                                                                                                                                                                             '_source' => 'm',
#                                                                                                                                                                                                                                             '_tname' => 'acute pancreatitis',
#                                                                                                                                                                                                                                             '_tid' => 'DOID:2913',
#                                                                                                                                                                                                                                             '_score' => '568'
#                                                                                                                                                                                                                                           }, 'Mapping' ),
#                                                                                                                                                                                                                                    bless( {
#                                                                                                                                                                                                                                             '_source' => 'n',
#                                                                                                                                                                                                                                             '_tname' => 'ACUTE PANCREATITIS',
#                                                                                                                                                                                                                                             '_tid' => 'DOID:2913',
#                                                                                                                                                                                                                                             '_score' => ''
#                                                                                                                                                                                                                                           }, 'Mapping' ),
#                                                                                                                                                                                                                                    bless( {
#                                                                                                                                                                                                                                             '_source' => 'n',
#                                                                                                                                                                                                                                             '_tname' => 'PANCREATITIS',
#                                                                                                                                                                                                                                             '_tid' => 'DOID:4989',
#                                                                                                                                                                                                                                             '_score' => ''
#                                                                                                                                                                                                                                           }, 'Mapping' )
#                                                                                                                                                                                                                                  ],
#          'A2M gene was suggested to be associated with Alzheimer\'s disease.' => [
#                                                                                    bless( {
#                                                                                             '_source' => 'm',
#                                                                                             '_tname' => 'Alzheimer\'s disease',
#                                                                                             '_tid' => 'DOID:10652',
#                                                                                             '_score' => '589'
#                                                                                           }, 'Mapping' ),
#                                                                                    bless( {
#                                                                                             '_source' => 'n',
#                                                                                             '_tname' => 'ALZHEIMER\'S DISEASE',
#                                                                                             '_tid' => 'DOID:10652',
#                                                                                             '_score' => ''
#                                                                                           }, 'Mapping' ),
#                                                                                    bless( {
#                                                                                             '_source' => 'n',
#                                                                                             '_tname' => 'DISEASE',
#                                                                                             '_tid' => 'DOID:4',
#                                                                                             '_score' => ''
#                                                                                           }, 'Mapping' )
#                                                                                  ],
#          'Results of this study revealed no association between the I1000V polymorphism of A2M and Chinese sporadic AD in Guangzhou and Chengdu.' => [
#                                                                                                                                                        bless( {
#                                                                                                                                                                 '_source' => 'm',
#                                                                                                                                                                 '_tname' => 'AD (Alzheimer\'s disease)',
#                                                                                                                                                                 '_tid' => 'DOID:10652',
#                                                                                                                                                                 '_score' => '563'
#                                                                                                                                                               }, 'Mapping' )
#                                                                                                                                                      ],
#          'These data support an involvement of the suggested A2M risk haplotype in the pathogenesis of Alzheimer\'s disease and adds new evidence to the risk-allele depletion hypothesis.' => [
#                                                                                                                                                                                                  bless( {
#                                                                                                                                                                                                           '_source' => 'm',
#                                                                                                                                                                                                           '_tname' => 'Alzheimer\'s disease',
#                                                                                                                                                                                                           '_tid' => 'DOID:10652',
#                                                                                                                                                                                                           '_score' => '734'
#                                                                                                                                                                                                         }, 'Mapping' ),
#                                                                                                                                                                                                  bless( {
#                                                                                                                                                                                                           '_source' => 'n',
#                                                                                                                                                                                                           '_tname' => 'ALZHEIMER\'S DISEASE',
#                                                                                                                                                                                                           '_tid' => 'DOID:10652',
#                                                                                                                                                                                                           '_score' => ''
#                                                                                                                                                                                                         }, 'Mapping' ),
#                                                                                                                                                                                                  bless( {
#                                                                                                                                                                                                           '_source' => 'n',
#                                                                                                                                                                                                           '_tname' => 'DISEASE',
#                                                                                                                                                                                                           '_tid' => 'DOID:4',
#                                                                                                                                                                                                           '_score' => ''
#                                                                                                                                                                                                         }, 'Mapping' )
#                                                                                                                                                                                                ],
#          'A2M-D allele played a weak Alzheimer disease protective role, and APOE-E4 and A2M-G alleles might act synergistically in Alzheimer disease risk for mainland Han Chinese.' => [
#                                                                                                                                                                                           bless( {
#                                                                                                                                                                                                    '_source' => 'm',
#                                                                                                                                                                                                    '_tname' => 'Alzheimer\'s disease',
#                                                                                                                                                                                                    '_tid' => 'DOID:10652',
#                                                                                                                                                                                                    '_score' => '567'
#                                                                                                                                                                                                  }, 'Mapping' ),
#                                                                                                                                                                                           bless( {
#                                                                                                                                                                                                    '_source' => 'n',
#                                                                                                                                                                                                    '_tname' => 'ALZHEIMER DISEASE',
#                                                                                                                                                                                                    '_tid' => 'DOID:10652',
#                                                                                                                                                                                                    '_score' => ''
#                                                                                                                                                                                                  }, 'Mapping' ),
#                                                                                                                                                                                           bless( {
#                                                                                                                                                                                                    '_source' => 'n',
#                                                                                                                                                                                                    '_tname' => 'DISEASE',
#                                                                                                                                                                                                    '_tid' => 'DOID:4',
#                                                                                                                                                                                                    '_score' => ''
#                                                                                                                                                                                                  }, 'Mapping' )
#                                                                                                                                                                                         ],
#          'In this proteins two amino acid polymorphisms (Ile/Val A-->G) have been associated with an increased risk for Alzheimer\'s disease (AD) and the combination with CTSD-T allele seems to increase this risk.' => [
#                                                                                                                                                                                                                             bless( {
#                                                                                                                                                                                                                                      '_source' => 'm',
#                                                                                                                                                                                                                                      '_tname' => 'Alzheimer\'s disease',
#                                                                                                                                                                                                                                      '_tid' => 'DOID:10652',
#                                                                                                                                                                                                                                      '_score' => '732'
#                                                                                                                                                                                                                                    }, 'Mapping' ),
#                                                                                                                                                                                                                             bless( {
#                                                                                                                                                                                                                                      '_source' => 'm',
#                                                                                                                                                                                                                                      '_tname' => 'AD (Alzheimer\'s disease)',
#                                                                                                                                                                                                                                      '_tid' => 'DOID:10652',
#                                                                                                                                                                                                                                      '_score' => '727'
#                                                                                                                                                                                                                                    }, 'Mapping' ),
#                                                                                                                                                                                                                             bless( {
#                                                                                                                                                                                                                                      '_source' => 'n',
#                                                                                                                                                                                                                                      '_tname' => 'ALZHEIMER\'S DISEASE',
#                                                                                                                                                                                                                                      '_tid' => 'DOID:10652',
#                                                                                                                                                                                                                                      '_score' => ''
#                                                                                                                                                                                                                                    }, 'Mapping' ),
#                                                                                                                                                                                                                             bless( {
#                                                                                                                                                                                                                                      '_source' => 'n',
#                                                                                                                                                                                                                                      '_tname' => 'DISEASE',
#                                                                                                                                                                                                                                      '_tid' => 'DOID:4',
#                                                                                                                                                                                                                                      '_score' => ''
#                                                                                                                                                                                                                                    }, 'Mapping' )
#                                                                                                                                                                                                                           ]
#        };

