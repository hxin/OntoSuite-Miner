#!/bin/sh
BASEDIR=$(dirname $0)

usage(){
cat <<EOF
Note: Metamap return the result text and will trim the last space if there are any.
example : xxxx\s will become xxxx
Trim the last space in advance 

This sctipt is used to run metamap and nabo annotator to find ontology terms in the input file.
input should be blank line seperated and looks like this:
	text corpus
	
	text corpus
	
	text corpus
	
output is something like this:
text_corpus	diod	doid_description	score

Usage: $0 

-i input text
-t output tmp folder
-d output data folder 
	
EOF
}

[ $# -eq 0 ] && usage && exit 1;
#echo $#
#echo $@;


while getopts i:t:d: opt
do
    case "$opt" in
    i)  in="$OPTARG";;
    t)  out_tmp="$OPTARG";;
    d)  out_data="$OPTARG";;
    \?) usage;exit 1;;
    esac
done

##load global incl
[ -f $BASEDIR/../global.sh ] && . $BASEDIR/../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }


echo "[$(date +"%T %D")] Mapping ..."
[ $USE_METAMAP = 'y' ] && sh $BINDIR/metamap.sh -i $in -o $out_tmp/m &
sleep 2s
[ $USE_NCBO = 'y' ] && sh $BINDIR/ncbo.sh -i $in -o $out_tmp/n -l $NCBOONT & 
wait

##replace the text by its id 
	
echo "[$(date +"%T %D")] Filtering result ..."
cat $out_tmp/m  $out_tmp/n > $out_data/d2t_raw
[ $USE_FILTER = 'y' ] && perl $BINDIR/filter.pl -i $out_data/d2t_raw -o $out_data/d2t_filtered -l $FILTER_DB -s $BINDIR/stopwords	
