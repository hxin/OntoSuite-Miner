#!/bin/sh
BASEDIR=$(dirname $0)

usage(){
cat <<EOF

Usage: $0 -o xxx.obo -s xxx.sqlte

-o obofile
-s output sqlite_file

The input obo_file should have a root node call 'all'
	
EOF
}

[ $# -eq 0 ] && usage && exit 1;

while getopts s:o opt
do
    case "$opt" in
	s)  sqlite_db="$OPTARG";;
	o)  obofile="$OPTARG";;
    
    \?) usage;exit 1;;
    esac
done


[ -e $sqlite_db ] && echo "$sqlite_db exist!" && exit 1
[ ! -e $obofile ] && echo "$obofile does not exist!" && exit 1

current_time=$(date "+%Y.%m.%d-%H.%M.%S")
ifname=$(basename "$obofile")
tmp_output=/tmp/ifname.$current_time

touch $sqlite_db

perl $BASEDIR/obo2sqlite.pl -o $obofile > $tmp_output

sqlite3 $sqlite_db < $tmp_output

echo "Done!"