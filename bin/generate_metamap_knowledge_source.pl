###################################
## The script is used to convert a .obo file into the format  
## for metamap data file builder.
##
## issue: currently remove all non-ascii character, can add a parser to translate these non-ascii into ascii
## 
################################### 
##
## http://metamap.nlm.nih.gov/#Downloads
## http://www.ncbi.nlm.nih.gov/books/NBK9685/
## http://www.ncbi.nlm.nih.gov/books/NBK9682/
## http://metamap.nlm.nih.gov/Installation.shtml
## http://metamap.nlm.nih.gov/Docs/README_dfb.html
## http://metamap.nlm.nih.gov/Docs/CreatingTheEFODataSetForMetaMap.html
##cd 01metawordindex/
##./01CreateWorkFiles
##./02Suppress
##./03FilterPrep
##echo 'no'|./04FilterStrict
##./05GenerateMWIFiles
##
##cd ../02treecodes/
##./01GenerateTreecodes
##
##cd ../03variants/
##./01GenerateVariants
##
##cd ../04synonyms/
##./01GenerateSynonyms
##
##cd ../05abbrAcronyms/
##./01GenerateAbbrAcronyms
###########


use strict;
use Getopt::Long;
use Data::Dumper;

my $usage = <<"USAGE";

Usage: $0 -i xx.obo -out out_folder -n HDO
The script is used to convert a .obo file into the format for metamap data file builder.

 -o, --output folder  the generated metamap file will be save in this folder
 -i, --obofile	ontology in obo format
 -s, --ontology_shortname short name for ontology
 -l, --ontology_fullname full name for ontology

Example: $0 -i /home/xin/Workspace/DisEnt/disent/data/hp.obo -o /home/xin/Workspace/DisEnt/disent/ontology_source/hpo -s HDO -l "human disease ontology"
USAGE

if (!$ARGV[0]) {
	print $usage;
	exit;
}

my $options={};
GetOptions($options,
	  	   "help|h",
           "obofile|i=s"=>\my $obofile,
           "output|o=s"=>\my $out,
           "ontology_shortname|s=s"=>\my $ontology_name,
           "ontology_fullname|l=s"=>\my $ontology_fullName,
	  );


###set it to 99999999 in real case
my $testNumber=9999999999999;
my $remove_obsolete=1;


###parse the obo
###remove to ASCii
#my $hdo=parseDOFile("/home/xin/Workspace/DisEnt/disent/data/doid_addall.obo");
my $hdo=parseDOFile($obofile);


###change base on source
#my $SAB="HPO";
#my $STY="HPO";
my $SAB=$ontology_name;
my $STY=$ontology_name;
####################

########
#my $output='~/Desktop/';
my $output=$out;
########


####no need to chage 
my $LUI=100000;
my $SUI=100000;
my $AUI=1000000;
my $Source_id="T5";
my $TUI="T001";
####################

##remove obsoleted terms
if($remove_obsolete==1){
	foreach my $c(keys %{$hdo}){
		if($hdo->{$c}->{'is_obsolete'} eq 'true'){
			delete $hdo->{$c};
		}
	}
}



my $do={};
foreach my $c(keys %{$hdo}){
	$do->{$c}=[];
	my $hash={};
	#MRCON
	$hash->{'String'}=$hdo->{$c}->{'name'};
	$hash->{'SUI'}="T".$SUI++;
	$hash->{'LUI'}="L".$LUI++;
	$hash->{'Term_Status'}="P";
	$hash->{'ISPREF'}="Y";
	
	$hash->{'AUI'}="A".$AUI++;
	#MRSO
	$hash->{'SAB'}=$SAB;
	#MRSTY
	$hash->{'TUI'}=$TUI;
	$hash->{'STY'}=$STY;
	
	push(@{$do->{$c}},$hash);

}

my $counter=0;
foreach my $id(keys %{$hdo}){	
		my $syms_arrayref=$hdo->{$id}->{'synonyms'};
		foreach my $syn(@{$syms_arrayref}){
			##any parse?
			##$syn
			$syn=(split(/\"/, $syn))[1];
			
			my $hash;		
			#MRCON
			$hash->{'String'}=$syn;
			$hash->{'SUI'}="T".$SUI++;
			$hash->{'LUI'}="L".$LUI++;
			$hash->{'Term_Status'}="S";
			$hash->{'ISPREF'}="N";
			$hash->{'AUI'}="A".$AUI++;
			#MRSO
			$hash->{'SAB'}=$SAB;
			#MRSTY
			$hash->{'TUI'}=$TUI;
			$hash->{'STY'}=$STY;
			
			push(@{$do->{$id}},$hash);	
		}
}

createMRCONSO($do,$output);
createMRRANK($do,$output);
createMRSAB($do,$output);
createMRSAT($do,$output);
createMRSTY($do,$output);
exit;









# 'DOID:0014667' => [
#                              {
#                                'STY' => 'Disease',
#                                'String' => 'disease of metabolism',
#                                'Source ID' => 'T5',
#                                'SUI' => 'T100004',
#                                'LUI' => 'L100004',
#                                'TUI' => 'T001',
#                                'Term_Type' => 'PT',
#                                'Term_Status' => 'P',
#                                'SAB' => 'HDO'
#                              },
#                              {
#                                'STY' => 'Disease',
#                                'String' => 'metabolic disease ',
#                                'Source ID' => 'T5',
#                                'SUI' => 'T100010',
#                                'LUI' => 'L100010',
#                                'TUI' => 'T001',
#                                'Term_Type' => 'NP',
#                                'Term_Status' => 'S',
#                                'SAB' => 'HDO'
#                              }
#                            ]



#####################
#Col.	Description
#CUI	Unique identifier for concept
#LAT	Language of term
#TS	Term status
#LUI	Unique identifier for term
#STT	String type
#SUI	Unique identifier for string
#ISPREF	Atom status - preferred (Y) or not (N) for this string within this concept
#AUI	Unique identifier for atom - variable length field, 8 or 9 characters
#SAUI	Source asserted atom identifier [optional]
#SCUI	Source asserted concept identifier [optional]
#SDUI	Source asserted descriptor identifier [optional]
#SAB	Abbreviated source name (SAB).  Maximum field length is 20 alphanumeric characters.  Two source abbreviations are assigned: 
#Root Source Abbreviation (RSAB) — short form, no version information, for example, AI/RHEUM, 1993, has an RSAB of "AIR"
#Versioned Source Abbreviation (VSAB) — includes version information, for example, AI/RHEUM, 1993, has an VSAB of "AIR93"
#Official source names, RSABs, and VSABs are included on the Source Vocabularies page.
#TTY	Abbreviation for term type in source vocabulary, for example PN (Metathesaurus Preferred Name) or CD (Clinical Drug). Possible values are listed on the Abbreviations Used in Data Elements page.
#CODE	Most useful source asserted identifier (if the source vocabulary has more than one identifier), or a Metathesaurus-generated source entry identifier (if the source vocabulary has none)
#STR	String
#SRL	Source restriction level
#SUPPRESS	Suppressible flag. Values = O, E, Y, or N
#
#O: All obsolete content, whether they are obsolesced by the source or by NLM. These will include all atoms having obsolete TTYs, and other atoms becoming obsolete that have not acquired an obsolete TTY (e.g. RxNorm SCDs no longer associated with current drugs, LNC atoms derived from obsolete LNC concepts). 
#
#E: Non-obsolete content marked suppressible by an editor. These do not have a suppressible SAB/TTY combination.
#
#Y: Non-obsolete content deemed suppressible during inversion. These can be determined by a specific SAB/TTY combination explicitly listed in MRRANK.
#
#N: None of the above
#
#Default suppressibility as determined by NLM (i.e., no changes at the Suppressibility tab in MetamorphoSys) should be used by most users, but may not be suitable in some specialized applications. See the MetamorphoSys Help page for information on how to change the SAB/TTY suppressibility to suit your requirements. NLM strongly recommends that users not alter editor-assigned suppressibility, and MetamorphoSys cannot be used for this purpose.
#CVF	Content View Flag. Bit field used to flag rows included in Content View. This field is a varchar field to maximize the number of bits available for use.

#####################

sub createMRCONSO{
	my ($do,$dir)=@_;
	open (MYFILE, ">$dir/MRCONSO.RRF");
	foreach my $c(keys %{$do}){
		foreach my $t(@{$do->{$c}}){
			printf MYFILE "%s|ENG|%s|%s|PF|%s|%s|%s||||%s|PT|%s|%s|0|N||\n",$c,$t->{'Term_Status'},
																			$t->{'LUI'},$t->{'SUI'},$t->{'ISPREF'},$t->{'AUI'},$t->{'SAB'},$t->{'SAB'}."1",$t->{'String'};
		}
	}
	close (MYFILE);
}


sub createMRSTY{
	my ($do,$dir)=@_;
	open (MYFILE, ">$dir/MRSTY.RRF");
	foreach my $c(keys %{$do}){
		printf MYFILE "%s|T001|A0.0.0.0.0.0|Disease Semantic Type|||\n",$c;
	}
	close (MYFILE);
}


sub createMRSAT{
	##can be empty
	my ($do,$dir)=@_;
	open (MYFILE, ">$dir/MRSAT.RRF");
	close (MYFILE);	
}

##back for the number 26368 and 8695
##these are the number of terms and CUI numbers in the MRCONSO file
sub createMRSAB{
	my ($do,$dir)=@_;
	open (MYFILE, ">$dir/MRSAB.RRF");
	print MYFILE "C4000006|C4000006|${ontology_name}_2014|${ontology_name}|${ontology_fullName}|||||||||0|26368|8695||||ENG|ascii|Y|Y|";
	close (MYFILE);	
}



sub createMRRANK{
	my ($do,$dir)=@_;
	open (MYFILE, ">$dir/MRRANK.RRF");
	printf MYFILE "%d|%s|%s|%s|\n",400,$SAB,"PT","N";
	printf MYFILE "%d|%s|%s|%s|\n",399,$SAB,"SY","N";
	close (MYFILE);	
}





sub parseDOFile{
	my $file_path=shift @_;
	my %return;
	my $line;
	my $start=0;
	my $line_count=0;
	my $current_id;
	open FILE, "<", $file_path or die $!;
READLINE:while ( <FILE> ) {
        $line=$_;
        chomp($line);
        
        ##remove non ascii 
        $line =~ s/[^!-~\s]//g;
#       print Dumper(%return) if $line_count++==100;
#		last if $line_count++==3;
#		exit if $line_count>100;
		return \%return if keys( %return )>=$testNumber;
        if($line =~ m/^\[Term\]/){
        	#start
        	$start=1;
        	#print $line;
        	next READLINE;        
        }
		if($start){
			if($line =~ m/^id:/){
	        	$current_id=(split(/ /, $line,2))[1];
	        	#parse id remove comma
	        	$current_id =~ s/\://;
	        	$return{$current_id}={};
	        	$return{$current_id}->{'synonyms'}=[];
	        	$return{$current_id}->{'xrefs'}=[];
	        	$return{$current_id}->{'parents'}=[];
	        	next READLINE;       
	        }elsif($line =~ m/^name:/){
	        	my $name=(split(/ /,$line,2))[1];
	        	$return{$current_id}->{'name'}=$name;
	        	next READLINE;
	        }elsif($line =~ m/^def:/){
	        	my $def=(split(/ /,$line,2))[1];
	        	$return{$current_id}->{'def'}=$def;
	        	next READLINE;
	        }elsif($line =~ m/^comment:/){
	        	my $comment=(split(/ /,$line,2))[1];
	        	$return{$current_id}->{'comment'}=$comment;
	        	next READLINE;
	        }elsif($line =~ m/^synonym:/){
	        	my $s=(split(/ /, $line,2))[1];
	        	push(@{$return{$current_id}->{'synonyms'}},$s);
	        	next READLINE;
	        }elsif($line =~ m/^xref:/){
	        	my $ref=(split(/ /,$line,2))[1];
	        	push(@{$return{$current_id}->{'xrefs'}},$ref);
	        	next READLINE;
	        }elsif($line =~ m/^is_a:/){
	        	my $parent=(split(/ /,$line,2))[1];
	        	$parent=(split(/ ! /,$parent,2))[0];
	        	push(@{$return{$current_id}->{'parents'}},$parent);
	        	next READLINE;
	        }elsif($line =~ m/^is_obsolete:/){
	        	my $obsolete=(split(/ /,$line,2))[1];
	        	$return{$current_id}->{'is_obsolete'}=$obsolete;
	        	next READLINE;
	        }elsif($line =~ m/^subset:/){
	        	#do nothing
	        	next READLINE;
	        }elsif($line =~ m/^\n/ ){
	        	#end
	        	$start=0;
	        	$current_id=0;
	        	next READLINE;
			}
		}#end start
    }
    return \%return;
}






