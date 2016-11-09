#!/usr/bin/perl
package myFunctions;

use strict;
use LWP::UserAgent;
use PadWalker;
use Data::Dumper;
use DBI;
use GO::Parser;



sub createOntologyObject{
	my $parser = _parseOBO(shift @_);
	my $graph = $parser->handler->graph;
	die("graph is empty") if !$graph;
	return $graph; 
}

sub findChildrenTerms{
	my $graph=shift @_;
	my $term=shift @_;
	my $children_ref=$graph->get_recursive_child_terms($term);
	return $children_ref;
#	foreach(@$children_ref){
#		print $_->acc,"\n";
#	}
}

sub createOntologyObjectWithTerms{
	my $full=shift @_;
	my $terms_ref=shift @_;
	my $subgraph = $full->subgraph_by_terms($terms_ref);
	return $subgraph;	
}

sub findShortestPath{
	my $graph=shift @_;
	my $term1=shift @_;
	my $term2=shift @_;
	
	my $paths1=$graph->paths_to_top($term1);
	#my $paths2=$graph->paths_to_top($term2);
	return $paths1;
	
}


sub _parseOBO{
	my $oboFile = shift @_;
	die("$oboFile not found!") if !$oboFile;
	my $parser = new GO::Parser( { handler => 'obj' } );    # create parser object
	$parser->parse($oboFile);                                # parse file -> objects
	return $parser;
}



sub _connectSQLITE{
	my $dbfile = shift @_;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
	die("bad connection to $dbfile") if !$dbh->ping;
    return $dbh;	
}





1;
