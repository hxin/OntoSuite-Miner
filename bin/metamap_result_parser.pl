#!/usr/bin/perl
use strict;
my $line;

my $dis_des;
my @dos;
READLINE:while (<>) {
	$line = $_;
	chomp($line);
	
	if( $line =~ m/^Processing.+tx\.(\d+):\s(.*)/) {

		if($1 == "1"){
			foreach my $d(@dos){
				print $dis_des,"\t",$d,"\tm\n";
			}
			$dis_des=$2;
			@dos=();
			next READLINE;	
		}else{
			$dis_des .= $2;
			next READLINE;
		}
	}
	
	#    770  DOID225:syndrome
	if ( $line =~ m/^\s+(\d+)\s+([a-zA-Z]+)([0-9]+):(.+)/ ) {
		my $do_id="$2:$3";
		#print "\t".$id."\t".hdoid2des($id)."\t".$1;
		push(@dos,$do_id."\t".$4."\t".$1);
		#print $current_id,"\t",$current_des,"\t",$do_id,"\t",$3,"\t",$1,"\n";
		next READLINE;
	}
	

}

##print the last line
foreach my $d(@dos){
	print $dis_des,"\t",$d,"\tm\n";
}



