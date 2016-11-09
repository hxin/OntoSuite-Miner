#!/usr/bin/perl

use strict;
use DBI;
use Data::Dumper;
use Getopt::Long;

my $usage = <<"USAGE";

Usage: $0 -d xx.sqlite -o xx.obo -sn xxx -fn xxx
This script is used to generate sql command for an ontology obo file. 
The output can be use to insert the ontology into a GO.db sqlite database.

 -d, --dbfile	sqlite db file from GO.db
 -o, --obofile	ontology in obo format
 -sn, --ontology_short_name	short name of the ontology
 -fn, --ontology_full_name	full name of the ontology

Example: $0 -d GO.sqlite -o hdo.obo -sn HDO -fn Human_disease_ontology
USAGE

my $options={};
GetOptions($options,
	  	   "help|h",
           "dbfile|d=s"=>\my $dbfile,  
	  );

if ($options->{help} or $ARGV[0]) {
	print $usage;
	exit;
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
die("cannot connect to databse $dbh") unless ($dbh->ping);
my $sth="select t1.entrez_id,term_id,group_concat(source) as source, count(source) as source_count from (";

my $query="select table_d2g from source_meta";
my $sth = $dbh->prepare($query);
$sth->execute();
my @data = $sth->fetchrow_array();
foreach my $d2g (@data){
	$sth .= "select distinct entrez_id,term_id,'o' as source from d2g_OMIM where term_id != '' union all";
}
