#!/usr/bin/perl -w
##############################
## The script is used to find the nearest gene for each variation
## It needs table <human_gene> and <human_variation>
###############################

use strict;
use DBI;
use Getopt::Long;

my $usage = <<"USAGE";

Usage: $0 -d xx.sqlite
This script is used to generate variation2gene table 

 -d, --dbfile	sqlite db file

Example: $0 -d DisEnt.sqlite
USAGE

my $options={};
GetOptions($options,
	  	   "help|h",
           "dbfile|d=s"=>\my $dbfile,
	  );

if ($options->{help}) {
	print $usage;
	exit;
}


my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
die("cannot connect to databse $dbh") unless ($dbh->ping);
my $sth;

$sth = $dbh->prepare("select distinct variation_id from human_variation");
$sth->execute();
my @vars;
while ( my @row = $sth->fetchrow_array ) {
	push(@vars,$row[0]);
}



foreach my $var(@vars){
	##overlap
	$sth=$dbh->prepare("
		SELECT distinct variation_id,entrez_id, 'o' as position, 0 as distance
		FROM human_variation as v inner join human_gene as g
		on v.chromosome_name=g.chromosome_name and v.position>=g.start_position and v.position <=g.end_position 
		where variation_id=? and entrez_id !=''
		union all
		select * from (select variation_id,entrez_id,'d' as position, ABS(g.start_position-v.position) as distance
		from human_gene as g,human_variation as v
		where g.chromosome_name=v.chromosome_name and g.start_position>v.position and variation_id=? and entrez_id !=''
		order By ABS(g.start_position-v.position) Asc limit 1)
		union all
		select * from (select variation_id,entrez_id,'u' as position, ABS(g.end_position-v.position) as distance
		from human_gene as g,human_variation as v
		where g.chromosome_name=v.chromosome_name and g.end_position<v.position and variation_id=? and entrez_id !=''
		order By ABS(g.end_position-v.position) Asc limit 1)
		;"
	);
	$sth->execute($var,$var,$var);
	while ( my @row = $sth->fetchrow_array ) {
		print $row[0]."\t".$row[1]."\t".$row[2]."\t".$row[3]."\n";
	}	
}

exit;
