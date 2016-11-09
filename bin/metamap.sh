#!/bin/sh
BASEDIR=$(dirname $0)
#####
## This script is used for mapping text into human disease ontology using metamap
## It reads input from a file in this format:
## gene_id	disease_id	disease_description
## The output format:
## gene_id	disease_id	disease_description	diod	doid_description	score
## Then chunks the input and queries metamap
## Note: one process can be runing at anytime! The tmp folder may cause problems!
#####

usage(){
cat <<EOF

Usage: $0 [OPTION]...

-s datasource [14_hdo,14_hpo,14_go]
-t switch to text mode
-i inputfile
-o outputfile


input should be blank line seperated and looks like this:
	text corpus
	
	text corpus
	
	text corpus
	
output is something like this:
text_corpus	diod	doid_description	score
EOF
}

[ $# -eq 0 ] && usage && exit 1;

while getopts s:i:o:t opt
do
    case "$opt" in
    s)  sourcedb="$OPTARG";;
    i)  in="$OPTARG";;
    o)  out="$OPTARG";;
    t)  textmode=yes;;
    \?) usage;exit 1;;
    esac
done



##load global incl
[ -f $BASEDIR/../global.sh ] && . $BASEDIR/../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }

[ -z $sourcedb ] && sourcedb=$MM_SOURCEDB;

##start metamap service
skr=`ps ax | grep taggerServer`
echo "[$(date +"%T %D")] Starting skr... " | tee -a $log
[ -z "$skr" ] && $MM_LOC/bin/skrmedpostctl start

wsd=`ps ax | grep DisambiguatorServer`
echo "[$(date +"%T %D")] Starting wsd..." | tee -a $log
[ -z "$wsd" ] && $MM_LOC/bin/wsdserverctl start && sleep 2m




if [ $textmode ];then
	while true; do
	    read -p "input your text:" text
	    echo ''
	    echo '----------------------------------------------------------------------'
	    echo $text |sh $MM $MM_PAR -V $sourcedb
	    echo ''	
		echo '----------------------------------------------------------------------'	
		echo ''	
	done	
	exit;	
fi


[ ! -s $in ] && echo "$in does not exist or is empty!" && exit 1;
#[ -z $out ] && out=/dev/stdout
[ -z $out ] && out=$in".out"



##print out the first line of the input 
#echo "[$(date +"%T %D")] First 2 lineS of your input file: " | tee -a $log
#head -2 $in | tee -a $log




##prepare tmp and chunk folder
current_time=$(date "+%Y.%m.%d-%H.%M.%S")
ifname=$(basename "$in")
[ ! -d /tmp/metamap ] && mkdir /tmp/metamap
tmp=/tmp/metamap/$ifname.$current_time
chunks=$tmp/chunks
mkdir $tmp $chunks



#echo "[$(date +"%T %D")] Start chunking files..." | tee -a $log
#echo "[$(date +"%T %D")] Create/Empty chunk folder..." | tee -a $log
#[ ! -d $tmp ] && mkdir $tmp || [ $cleantmp = 'y' ] && rm -rf $tmp/*
#[ ! -d $chunks ] && mkdir $chunks || [ $cleanchunks = 'y' ] && rm -rf $chunks/*
	


##prepare input file
echo "[$(date +"%T %D")] Pre-processing input..." | tee -a $log
#cat $in | tr '\t' '|' | awk '{print $0,"\n"}' > $tmp/in
#perl -ne ' $line =~ s/[^!-~\s]//g; print $1 ' 
##remove non asc-ii
perl -pe 's/[^!-~\s]//g' $in >$tmp/in



##chunk the input file into smaller files
echo "[$(date +"%T %D")] Chunking file..." | tee -a $log 
`cat $tmp/in >$chunks/source && cd $chunks && /usr/bin/split -n l/$metamap_file_chunk -a 4 -e -d ./source chunk_ && rm -f ./source && find . -type f -exec mv '{}' '{}'_raw \;`
#echo "chunks generated:" | tee -a $log 
#ls -h $chunks | tee -a $log 


##metamap
echo "[$(date +"%T %D")] Start metamap mapping..."|tee -a $log
totalfile=$(find $chunks/ -name '*_raw'|wc -l)
while [ -n "$(find $chunks/ -name '*_raw')" ] 
do
	echo "*******************************************\n""[$(date +"%T %D")]" $(find $chunks/ -name '*_raw'|wc -l) "/$totalfile file left for metamap...\n""*******************************************"	
	files=$(find $chunks -iname '*_raw'|head -$metamap_chunk)
	for line in $files; do 
		#filename=$(basename "$line")
		sh $MM $MM_PAR -V $sourcedb $line ${line}_parsed > /dev/null & 
	done
	#echo "[$(date +"%T %D")] Waiting for metamap to be finished..."|tee -a $log
	wait
	for line in $files; do 
		rename 's/_raw/_doneraw/' $line
	done
done

echo "[$(date +"%T %D")] Finish metamap! Joining result..." | tee -a $log
for line in $(find $chunks -iname 'chunk_*_parsed'); do 
	cat $line >> $chunks/all
done

##parse result
echo "[$(date +"%T %D")] Parsing result..."
grep -P 'Processing|^\s+' $chunks/all | perl $BINDIR/metamap_result_parser.pl > $out 
#cat $chunks/all | grep -P 'Processing|DOID[0-9]' | perl $BASEDIR/parser.pl > $out 


exit 0;
