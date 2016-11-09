#!/usr/bin/perl

use strict;
use Getopt::Long;
use Data::Dumper;





my $usage = <<"USAGE";

Usage: $0 -f1 mim2gene -f2 morbidmap

 -f1, mim2gene
 -f2, morbidmap
USAGE

my $options={};
GetOptions($options,
			 "help|h",
           "f1=s"=>\my $mim2gene,
           "f2=s"=>\my $morbidmap,
	  );

if ($options->{help} or $ARGV[0]) {
	print $usage;
	exit;
}


my $line;
my $m2g={};

open FILE, "<", $mim2gene or die $!;
while (<FILE>) {
	next if /^\s*#/;
	$line = $_;
	chomp($line);
	my ($mim_number,$type,$gene_id,$symbols) = split(/\t/, $line);
	$m2g->{$mim_number}->{'type'}=$type;
	$m2g->{$mim_number}->{'gene_id'}=$gene_id;
	$m2g->{$mim_number}->{'symbols'}=$symbols;
	
}
close FILE;

	

open FILE, "<", $morbidmap or die $!;
while (<FILE>) {
	$line = $_;
	chomp($line);
	my ($dis_name,$gene_symbols,$locus_mim_acc,$location) = split(/\|/, $line);
	my $disorder_mim_acc;

	if($dis_name =~ m/(.+),\s(\d{6})\s?\(\d\)/){
		$dis_name=$1;
		$disorder_mim_acc=$2;
		if($disorder_mim_acc==$locus_mim_acc){
			$locus_mim_acc='';
		}
	}elsif($dis_name =~ m/(.+)\s\([1234]\)/){
		$dis_name=$1;
		if(isPt($locus_mim_acc)){
			$disorder_mim_acc=$locus_mim_acc;
			$locus_mim_acc='';
		}else{
			$disorder_mim_acc='';
		}
	}
	if(defined($m2g->{$locus_mim_acc}->{'gene_id'})  && $m2g->{$locus_mim_acc}->{'gene_id'} ne '-'){
		print $locus_mim_acc."\t".$m2g->{$locus_mim_acc}->{'gene_id'}."\t".$disorder_mim_acc."\t".$dis_name."\t".$gene_symbols."\t".$location."\n";	
	}	
	    
}
close FILE;

sub isPt(){
	my ($mim_acc)=@_;
	my $t=$m2g->{$mim_acc}->{'type'};
	if($t eq 'phenotype' or $t eq 'gene/phenotype'){
		return 1;
	}else{
		return 0;
	}
}




#17,20-lyase deficiency, isolated, 202110 (3)|CYP17A1, CYP17, P450C17|609300|10q24.32
#Histiocytosis-lymphadenopathy plus syndrome, 602782 (3)|HJCD, HCLAP|602782|11q25
#{Autism susceptibility, X-linked 4} (4)|DELXp22.11, CXDELp22.11, AUTSX4|300830|Xp22.11
#Cone-rod dystrophy 6, 601777(3)|GUCY2D, GUC2D, LCA1, CORD6, RCD2|600179|17p13.1
