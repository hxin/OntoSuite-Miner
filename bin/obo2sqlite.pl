#!/usr/bin/perl
#################################################
## The script is used to create the sqlite db file that can be used in topOnto.XXX.db packages.
## The db file is also used during the mapping filtering processes for querying parent/children relationship.
##
## Xin 06/03/2015
################################################
 
use strict;
use LWP::UserAgent;
use Getopt::Long;
use Data::Dumper;
use DBI;
use GO::Parser;


my $usage = <<"USAGE";

Usage: $0  -o xx.obo 
This script is used to generate sql command for an ontology obo file. 
The output can be use to insert the ontology into a GO.db sqlite database.

 -o, --obofile	ontology in obo format

Example: $0 -o hdo.obo 
perl create_ontology_sqlite_queries.pl -obofile ./../data/go_cc_addall.obo > ./../data/go_cc_addall.sqlitequeries &
USAGE

if (!$ARGV[0]) {
	print $usage;
	exit;
}

my $options={};
GetOptions($options,
	  	   "help|h",
           "obofile|o=s"=>\my $obofile
	  );

if ($options->{help}) {
	print $usage;
	exit;
}
my $ontology='CC';
my $ontology_name='CC';


#my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
#die("cannot connect to databse $dbh") unless ($dbh->ping);
my $sth;

# ** FETCHING GRAPH OBJECTS FROM AN ONTOLOGY FILE **
my $parser = new GO::Parser( { handler => 'obj' } );    # create parser object
$parser->parse($obofile);                                # parse file -> objects
my $graph = $parser->handler->graph;    # get L<GO::Model::Graph> object

#my $max_id=findMaxID();
my $idTable=idTable();
my @obsTerms=obsTerms();


#foreach(@$terms_ref){
#	print $_->acc,"\n";
#}
#print scalar(@$terms_ref);
#print "\n###################\n";
#
#my $node_listref = $graph->get_all_nodes();
#print scalar(@$node_listref);
#exit;



####setup
print "BEGIN TRANSACTION;\n";
print <<INIT
CREATE TABLE go_ontology (
  ontology VARCHAR(9) PRIMARY KEY,               -- GO ontology (short label)	
  term_type VARCHAR(18) NOT NULL UNIQUE          -- GO ontology (full label)
);\n

INSERT INTO "go_ontology" VALUES('universal','universal');
INSERT INTO "go_ontology" VALUES('CC','cellular_component');

CREATE TABLE go_term (
  _id INTEGER PRIMARY KEY,
  go_id CHAR(10) NOT NULL UNIQUE,               -- GO ID
  term VARCHAR(255) NOT NULL,                   -- textual label for the GO term
  ontology VARCHAR(9) NOT NULL,                 -- REFERENCES go_ontology
  definition TEXT NULL,                         -- textual definition for the GO term
  FOREIGN KEY (ontology) REFERENCES go_ontology (ontology)
);\n

CREATE TABLE go_cc_offspring (
  _id INTEGER NOT NULL,                     -- REFERENCES go_term
  _offspring_id INTEGER NOT NULL,                -- REFERENCES go_term
  FOREIGN KEY (_id) REFERENCES go_term (_id),
  FOREIGN KEY (_offspring_id) REFERENCES go_term (_id)
);\n

CREATE TABLE go_cc_parents ( 
  _id INTEGER NOT NULL,                     -- REFERENCES go_term
  _parent_id INTEGER NOT NULL,                   -- REFERENCES go_term
  relationship_type VARCHAR(7) NOT NULL,                 -- type of GO child-parent relationship
  FOREIGN KEY (_id) REFERENCES go_term (_id),
  FOREIGN KEY (_parent_id) REFERENCES go_term (_id)
);\n

CREATE TABLE go_obsolete (
  go_id CHAR(10) PRIMARY KEY,                   -- GO ID
  term VARCHAR(255) NOT NULL,                   -- textual label for the GO term
  ontology VARCHAR(9) NOT NULL,                 -- REFERENCES go_ontology
  definition TEXT NULL,                         -- textual definition for the GO term
  FOREIGN KEY (ontology) REFERENCES go_ontology (ontology)
);\n

CREATE TABLE go_synonym (
  _id INTEGER NOT NULL,                     -- REFERENCES go_term
  synonym VARCHAR(255) NOT NULL,                -- label or GO ID
  secondary CHAR(10) NULL,                      -- GO ID
  like_go_id SMALLINT,                          -- boolean (1 or 0)
  FOREIGN KEY (_id) REFERENCES go_term (_id)
);\n

CREATE TABLE map_counts (
  map_name VARCHAR(80) PRIMARY KEY,
  count INTEGER NOT NULL
);\n

CREATE TABLE map_metadata (
  map_name VARCHAR(80) NOT NULL,
  source_name VARCHAR(80) NOT NULL,
  source_url VARCHAR(255) NOT NULL,
  source_date VARCHAR(20) NOT NULL
);\n

CREATE TABLE metadata (
  name VARCHAR(80) PRIMARY KEY,
  value VARCHAR(255)
);\n

INIT
;


####go_ontology
$sth=insertQuery('go_ontology',[uc($ontology),$ontology_name]);

print $sth."\n";
my $done={};
##IT
my $it = $graph->create_iterator;
while ( my $ni = $it->next_node_instance) {
		my $term = $ni->term;
		if(!$done->{$term->acc}){
			$done->{$term->acc}=1;
			
			##go_obsolete
			if ( $term->is_obsolete ) {
				$sth=insertQuery('go_obsolete',[$term->acc,$term->name,uc($ontology),$term->definition]);
				print $sth."\n";
			}else{
				##go_term
				$sth=insertQuery('go_term',[$idTable->{ $term->acc },$term->acc,$term->name,uc($ontology),$term->definition]);
				print $sth."\n";
	
				##go_synonym
				my $syn_l = $term->alt_id_list;
				foreach my $s(@$syn_l) {
					$sth=insertQuery('go_synonym',[$idTable->{ $term->acc }, $s, $s, 1]);
					print $sth."\n";
				}
				my $synstrs = $term->synonyms_by_type('exact');
				foreach my $s(@$synstrs) {
					$sth=insertQuery('go_synonym',[$idTable->{ $term->acc }, $s, $s, 0]);
					print $sth."\n";
				}
				
				##go_hdo_offspring
				##All children dir/indir
				my $child_ref = $graph->get_recursive_child_terms($term->acc);
				my $uniq_child={};
				foreach(@$child_ref){
					$uniq_child->{$_->acc} = $_;
				}
				foreach my $t(values %$uniq_child){
					if(!$t->is_obsolete){
						$sth=insertQuery("go_${ontology}_offspring",[$idTable->{ $term->acc }, $idTable->{$t->acc}]); 
						print $sth."\n" 
					}
				}
				
				##go_hdo_parents
				##direct DGA
				#my $parents_ref = $graph->get_parent_terms($term->acc);
				my $rel_listref = $graph->get_parent_relationships($term->acc);
				foreach my $r(@$rel_listref){
					if(!isobs($r->acc1)){
						$sth=insertQuery("go_${ontology}_parents",[$idTable->{ $term->acc }, $idTable->{$r->acc1},$r->type]);
						print $sth."\n" ;
					}
				}
			} #end if ( $term->is_obsolete )
		}#end if(!$done->{$term->acc})
	}
###map_counts
###does matter for now!
#my $c=getFirstResult("select count(*) from go_term;");
#print "UPDATE map_counts SET count = $c where map_name='TERM';\n";
#$c=getFirstResult("select count(*) from go_obsolete;");
#print "UPDATE map_counts SET count = $c where map_name='OBSOLETE';\n";
##$c=getFirstResult("select count(distinct _id) from go_hdo_parents;");
#$sth=insertQuery('map_counts',['HDOPARENTS',1000]);
#print $sth."\n" ;
##$c=getFirstResult("select count(distinct _id) from go_hdo_parents;");
#$sth=insertQuery('map_counts',['HDOCHILDREN',1000]);
#print $sth."\n" ;
#$sth=insertQuery('map_counts',['HDOANCESTOR',1000]);
#print $sth."\n" ;
#$sth=insertQuery('map_counts',['HDOOFFSPRING',1000]);
#print $sth."\n" ;

##map_metadata
#$sth=insertQuery('map_metadata',['HDOPARENTS','Gene Ontology','www.google.com','20130907']);
#print $sth."\n" ;
#$sth=insertQuery('map_metadata',['HDOCHILDREN','Gene Ontology','www.google.com','20130907']);
#print $sth."\n" ;
#$sth=insertQuery('map_metadata',['HDOANCESTOR','Gene Ontology','www.google.com','20130907']);
#print $sth."\n" ;
#$sth=insertQuery('map_metadata',['HDOOFFSPRING','Gene Ontology','www.google.com','20130907']);
#print $sth."\n" ;


print createIndex('go_term','go_id');
print createIndex('go_cc_parents','_id');
print createIndex('go_cc_parents','_parent_id');
print createIndex('go_cc_offspring','_id');
print createIndex('go_cc_offspring','_offspring_id');
##cleanup
print "COMMIT;\n";


exit;

sub insertQuery{
	my ($table,$pars)=@_;
	foreach(@$pars){
		$_ =~ s/\'/\'\'/g;
		$_ =~ s/\"/\"\"/g;
	}	
	my $sth = "INSERT INTO \"$table\" VALUES ('".join("','", @$pars)."');";
	return $sth;
}

sub createIndex{
	my ($table,$colume)=@_;
	my $n=int(rand(100));	
	my $sth = "CREATE INDEX ${table}_${n} ON $table ($colume);\n";
	return $sth;
}


#sub findMaxID{
#	#return 39838;
#	my $r=getFirstResult('SELECT _id FROM go_term order by _id DESC limit 1;');
#	return $r;
#}
#
#sub getFirstResult{
#	my $query=shift @_;
#	my $sth = $dbh->prepare($query);
#	$sth->execute();
#	my @data = $sth->fetchrow_array();
#	return $data[0];
#}


sub obsTerms{
	my $it      = $graph->create_iterator;
	my @array ;
	while ( my $ni = $it->next_node_instance ) {
		my $term = $ni->term;
		if($term->is_obsolete){
			push(@array,$term->acc);
		}
	}
	return @array;
}

sub isobs{
	my($acc) = @_;
	my @matches=  grep $_ eq $acc, @obsTerms;
	if(@matches){
		return 1;
	}else{
		return 0;
	}
}

sub idTable {	
	#my $id=shift @_;
	my $id = 0;
	my $table   = {};
	my $it      = $graph->create_iterator;
	while ( my $ni = $it->next_node_instance ) {
		my $term = $ni->term;
		$table->{ $term->acc } = 0;
	}
	foreach my $t ( sort keys %$table ) {
		$table->{$t} = ++$id;
	}
	##all should has id the same as in db
#	my $all_id=getFirstResult("SELECT _id FROM go_term where go_id='all'");
#	$all_id = 0 if(!$all_id);
#	$table->{"all"} = $all_id;
	return $table;
}

#my $term  = $graph->get_term("DOID:0050117");    # fetch a term by ID
#printf "Got term: %s %s\n", $term->acc, $term->name;
#my $ancestor_terms = $graph->get_recursive_parent_terms( $term->acc );
#foreach my $anc_term (@$ancestor_terms) {
#	printf "  Ancestor term: %s %s\n", $anc_term->acc, $anc_term->name;
#}

#my $it = $graph->create_iterator;
while ( my $ni = $it->next_node_instance ) {
	my $depth = $ni->depth;
	my $term  = $ni->term;
	if ( !$term->is_obsolete ) {
		printf "%s\t%s\t%s\t%s\n", $term->acc, $term->name, uc($ontology),
		  $term->definition;
	}
}

sub go_term {
	my ($graph) = @_;
	my $id      = 1;
	my $it      = $graph->create_iterator;
	while ( my $ni = $it->next_node_instance ) {
		my $term = $ni->term;
		if ( !$term->is_obsolete ) {
			printf "%s\t%s\t%s\t%s\t%s\n", $id++, $term->acc, $term->name,
			  uc($ontology), $term->definition;
		}
	}
}

sub go_obsolete {
	my ($graph) = @_;
	my $it = $graph->create_iterator;
	while ( my $ni = $it->next_node_instance ) {
		my $term = $ni->term;
		if ( $term->is_obsolete ) {
			printf "%s\t%s\t%s\t%s\n", $term->acc, $term->name, uc($ontology),
			  $term->definition;
		}
	}
}

sub go_ontology {
	printf "%s\t%s\n", uc($ontology), $ontology_name;
}

####@todo
####update term_name to row_id
sub go_synonym {
	my ($graph) = @_;
	my $it = $graph->create_iterator;
	while ( my $ni = $it->next_node_instance ) {
		my $term = $ni->term;
		if ( !$term->is_obsolete ) {
			my $syn_l = $term->alt_id_list;
			foreach (@$syn_l) {
				printf "%s\t%s\t%s\t%s\n", $term->acc, $_, $_, 1;
			}
			my $synstrs = $term->synonyms_by_type('exact');
			foreach (@$synstrs) {
				printf "%s\t%s\t%s\t%s\n", $term->acc, $_, '', 0;
			}
		}
	}
}
