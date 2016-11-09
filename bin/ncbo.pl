#!/usr/bin/perl
###################
## This script is used to query ncbo annotator. 
## It receive text from stdin and one parameter to specify which ontology to use.
## example use: 
## echo "Alzheimer's disease"|perl ncbo.pl DOID
###################



use strict;
use DBI;
use Data::Dumper;

use LWP::UserAgent;
use URI::Escape;  
use XML::LibXML;
use Data::Dumper;
use Cwd 'abs_path';



##read config
my $config_ref={};
my $filename = abs_path($1).'/../.setting';
if (open(my $fh, '<:encoding(UTF-8)', $filename)) {
  while (my $row = <$fh>) {
    chomp $row;
    next if $row=~/^#|^$/;  
    my ($key, $value) = split(/=/,$row);
    #print $key."====".$value;
    $config_ref->{$key}=$value
  }
} else {
  warn "Could not open file '$filename' $!";
}



#my $t="A tubule with spermatocytes at leptotene/zygotene transition is labeled ZP, and tubules with apoptotic spermatocytes are marked with an asterisk. To ensure that A production was suppressed in concert with the dox-mediated inhibition of its precursor APPswe/ind, we measured A40 and A42 levels by ELISA in forebrain homogenates from young tet-off animals. At 1 mo of age, the mice lacked visible amyloid aggregates that might act as an intractable reservoir of peptide remaining in the brain after the transgene had been suppressed. To further ensure we could detect any such insoluble aggregates that might bias our measure of changes in peptide synthesis, we performed a sequential three-step extraction with PBS, 2% SDS, and 70% FA that would separate peptides by solubility. We compared the levels of human transgene-derived A40 and A42 in untreated mice at 4 and 6 wk of age to animals that had either been born and raised on dox or that had been left untreated for 4 wk and then placed on dox chow for 2 wk prior to harvest (the same groups described above for immunoblot analysis of APPswe/ind levels, line 107). Consistent with the reduction in full-length APPswe/ind synthesis shown by immunoblot (see Figure 1), we found that transgene-derived A levels were completely suppressed in animals born and raised on dox, and were sharply reduced following acute (2 wk) antibiotic treatment. Compared to the levels in untreated 4-wk-old mice, PBS-soluble A42 dropped by 95.2% following 2 wk of dox treatment and by 99.2% with chronic treatment (Figure 2A). Similarly, SDS-soluble A42 decreased by 75.2% and 94.8% following 2-wk or lifelong dox treatment (Figure 2B). Only the FA fraction revealed a small dox-resistant pool of peptide in acutely treated animals that we believe represents stable predeposit aggregates that have already accumulated by 4 wk of age when treatment was begun (Figure 2C). Indeed, animals that were born and raised on dox did not harbor this reservoir of treatment-resistant peptide, with 96.3% less A42 than untreated 4-wk-old mice. Measurement of total A in chronically treated mice, including endogenous and transgene-derived peptide, demonstrated that A levels in tet-off APP mice were reduced to the level of endogenous peptide found in nontransgenic animals (Figure 2D). Taken together with the immunoblotting data for full-length APPswe/ind, the ELISA measurements indicate that dox-mediated suppression of transgenic APPswe/ind synthesis leads to parallel reduction of A levels.";
#ncbo_annotator('GO',$t);
#exit;
#ncbo_annotator('HP','Abnormality of body height');
#ncbo_annotator('DOID','Alzheimer\'s disease');



my($ont)=shift @ARGV;

while ( <stdin> ) {
	chomp;
	my $text=$_;
	ncbo_annotator($ont,$text);
}

#my $f='/tmp/ncbo/text.2015.03.01-22.31.02/chunks/chunk_0000_doneraw';
#open (OMIM, "<" ,$f);
#my $ont='HP';
#while ( <OMIM> ) {
#	chomp;
#	my $text=$_;
#	ncbo_annotator($ont,$text);
#}API_KEY


sub ncbo_annotator{
my ($ont,$des)=@_;

$|=1;
#http://data.bioontology.org/documentation#nav_annotator
#my $API_KEY = 'f4f6d2e7-7726-402c-a4b0-6dfc533ad94e';  # Login to BioPortal (http://bioportal.bioontology.org/login) to get your API key
#my $API_KEY = '1cfae05f-9e67-486f-820b-b393dec5764b';  # Login to BioPortal (http://bioportal.bioontology.org/login) to get your API key 
my $API_KEY = $config_ref->{'API_KEY'};

#my $AnnotatorURL = 'http://data.bioontology.org/annotator';
#my $AnnotatorURL = 'http://129.215.164.32:8002/annotator'; 
my $AnnotatorURL = $config_ref->{'AnnotatorURL'};

my $ontologies=$ont;
#my $text = "EZH2 Y641 mutations are not associated with follicular lymphoma";
my $text = uri_escape($des);
my $format = "xml"; #xml, tabDelimited, text



# create a user agent
my $ua = new LWP::UserAgent;
$ua->agent('Annotator Client Example - Perl');
# create a POST request
my $req = new HTTP::Request POST => "$AnnotatorURL";
$req->content_type('application/x-www-form-urlencoded');
$req->content("ontologies=$ontologies&"
			."text=$text&"
			 ."format=$format&" 
			 ."apikey=$API_KEY"); 
# send request and get response.
my $response = $ua->request($req);
#print Dumper($response);

# create a parse to handle the output 
my $parser = XML::LibXML->new();


# Check the outcome of the response
if ($response->is_success) {
	my $time = localtime();
	#print "Call successful at $time\n";
  	#print $response->decoded_content;  # this line prints out unparsed response 
    # Parse the response 
	#print "Format: $format\n";
    if ($format eq "xml") {
 		my ($M_ConceptREF) = parse_annotator_response($response, $parser);
	#Print something for the user
	#print scalar (keys %{$M_ConceptREF}), " concepts found\n";
	if(%{$M_ConceptREF}){
		foreach my $c (keys %{$M_ConceptREF}){
  		 	#print $g,"\t",$did,"\t",$des,"\t",$c,"\t", $$M_ConceptREF{$c},"\t","@ref","\n";
		 	##need to print an empty column here to match the metamap result.
   		 	##ncbo doesn't give a score so just an empty column will do the job. 
   		 	##ncbo use '_' to replace ':' in the term id. need to parse it back forexample DOID_4 to DOID:4	
   		 	(my $new = $c) =~ s/_/:/; 
   		 	print $des,"\t",$new,"\t", $$M_ConceptREF{$c},"\t\tn\n";
   		 }    
	}  
  }
}else {
	my $time = localtime();
    print $response->status_line, " at $time\n";
	print $response->content, " at $time\n";
}


###################
# parse response
################### 
sub parse_annotator_response {
	my ($res, $parser) = @_;
    my $dom = $parser->parse_string($res->decoded_content);
	my $root = $dom->getDocumentElement();
	my %MatchedConcepts;

	my $results = $root->findnodes('/annotationCollection/annotation');
	foreach my $annotation ($results->get_nodelist){
		# Sample XPATH to extract concept info if needed
       	my $idurl=$annotation->findvalue('./annotatedClass/id');
       	my $idurl_rev=reverse $idurl;
       	$idurl_rev=~/(\w+)\//;
       	my $id_rev=$1;
       	my $id=reverse $id_rev;
       	
#        print "id = ", $annotation->findvalue('./annotatedClass/id'),"\n";
        my $annotations=$annotation->findnodes('./annotationsCollection/annotations');
        foreach ($annotations->get_nodelist){
        	my $nodes=$_;
#        	print "text = ", $nodes->findvalue('./text'),"\n";
#			print "matchType = ", $nodes->findvalue('./matchType'),"\n\n";
			$MatchedConcepts{$id} = $nodes->findvalue('./text');
        }
	}
		
#	my $results = $root->findnodes('/annotationCollection/annotation/annotationsCollection/annotations');
#	foreach my $c_node ($results->get_nodelist){
#                # Sample XPATH to extract concept info if needed
#		print "text = ", $c_node->findvalue('text'),"\n";
#		print "matchType = ", $c_node->findvalue('matchType'),"\n";
#		$MatchedConcepts{$c_node->findvalue('text')} = $c_node->findvalue('text');
#	}
	
	return (\%MatchedConcepts);
}



}
