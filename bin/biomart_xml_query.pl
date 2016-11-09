# an example script demonstrating the use of BioMart webservice
# http://www.ensembl.org/biomart/martview/ef1717796500e6e2719a4550c6185c24
# This is an example query:
#<?xml version="1.0" encoding="UTF-8"?>
#<!DOCTYPE Query>
#<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.6" >
#			
#	<Dataset name = "hsapiens_snp" interface = "default" >
#		<Filter name = "variation_set_name" value = "All phenotype-associated variants"/>
#		<Filter name = "with_validated" excluded = "0"/>
#		<Attribute name = "refsnp_id" />
#		<Attribute name = "chr_name" />
#		<Attribute name = "chrom_start" />
#		<Attribute name = "study_external_ref" />
#		<Attribute name = "source_name" />
#		<Attribute name = "phenotype_description" />
#	</Dataset>
#</Query>
# 
# 
use strict;
use LWP::UserAgent;

open (FH,$ARGV[0]) || die ("\nUsage: perl $0 Query.xml\n\n");
#open (FH,'/home/xin/Workspace/DisEnt/disent/basic/ensembl/scripts/queries/human_variation.xml') || die ("\nUsage: perl $0 Query.xml\n\n");
my $xml;
while (<FH>){
    $xml .= $_;
}
close(FH);

#my $path="http://www.biomart.org/biomart/martservice?";
my $path="http://www.ensembl.org/biomart/martservice?";

my $request = HTTP::Request->new("POST",$path,HTTP::Headers->new(),'query='.$xml."\n");
my $ua = LWP::UserAgent->new;

my $response;

$ua->request($request, 
	     sub{   
		 my($data, $response) = @_;
		 if ($response->is_success) {
		     print "$data";
		 }
		 else {
		     warn ("Problems with the web server: ".$response->status_line);
		 }
	     },1000);
