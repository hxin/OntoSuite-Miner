#!/bin/sh

#####
## This script is used for mapping text into human disease ontology using NCBO Annotator
## It reads input from a file in this format:
## gene_id	disease_id	disease_description
## Then chunks the input and queries NCBO Annotator
## Note: one process can be running at anytime! The tmp folder may cause problems!
#####

BASEDIR=$(dirname $0)

usage(){
cat <<EOF

Usage: $0 [OPTION]...

-t switch to text mode
-i inputfile
-o outputfile
-l ontology

input should be line seperated and looks like this:
	disease_description1
	disease_description2
	disease_description3
	
output is something like this:
disease_description	diod	doid_description	score"
EOF
}



[ $# -eq 0 ] && usage && exit 1;

#echo $@;

while getopts l:i:o:t opt
do
    case "$opt" in
    l)  ontology="$OPTARG";;
    i)  in="$OPTARG";;
    o)  out="$OPTARG";;
    t)  textmode=yes;;
    \?) usage;exit 1;;
    esac
done



##load global incl
[ -f $BASEDIR/../global.sh ] && . $BASEDIR/../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }


[ -z $NCBOONT ] && echo "use default ontology DOID" && NCBOONT='DOID'


if [ $textmode ];then
	while true; do
	    read -p "input your text:" text
	    echo ''
	    echo '----------------------------------------------------------------------'
	    echo $text | perl $BINDIR/ncbo.pl "$NCBOONT"
	    echo '----------------------------------------------------------------------'
		echo ''	
	done	
	exit;	
fi


[ ! -s $in ] && echo "$in does not exist or is empty!" && exit 1;
#[ -z $out ] && out=/dev/stdout
[ -z $out ] && out=$in".out"

##print out the first line of the input 
#echo "[$(date +"%T %D")] First 2 lines of your input file: " | tee -a $log
#head -2 $in | tee -a $log


##prepare tmp and chunk folder
current_time=$(date "+%Y.%m.%d-%H.%M.%S")
ifname=$(basename "$in")
[ ! -d /tmp/ncbo ] && mkdir /tmp/ncbo
tmp=/tmp/ncbo/$ifname.$current_time
chunks=$tmp/chunks
mkdir $tmp $chunks
	
	
##chunk the input file into smaller files
##prepare tmp and chunk folder
#echo "[$(date +"%T %D")] Start chunking files..." | tee -a $log
#echo "[$(date +"%T %D")] Create/Empty chunk folder..." | tee -a $log
#[ ! -d $tmp ] && mkdir $tmp ||  rm -rf $tmp/*
#[ ! -d $chunks ] && mkdir $chunks || rm -rf $chunks/*
	
##prepare input file
perl -pe 's/[^!-~\s]//g' $in | sed '/^$/d' >$tmp/in

##chunk file
echo "[$(date +"%T %D")] Chunking file..." | tee -a $log 
`cat $tmp/in >$chunks/source && cd $chunks && /usr/bin/split -n l/$ncbo_file_chunk -a 4 -e -d ./source chunk_ && rm -f ./source && find . -type f -exec mv '{}' '{}'_raw \;`
#echo "chunks generated:" | tee -a $log 
#ls $chunks | tee -a $log 
	

	
##run ncbo.pl to map text to HDO
echo "[$(date +"%T %D")] Start NCBO mapping..."| tee -a $log
totalfile=$(find $chunks/ -name '*_raw'|wc -l)
while [ -n "$(find $chunks/ -name '*_raw')" ] 
do
	echo "*******************************************\n""[$(date +"%T %D")]" $(find $chunks/ -name '*_raw'|wc -l) "/$totalfile file left for ncbo...\n""*******************************************"
	files=$(find $chunks -iname '*_raw'|head -$ncbo_chunk)
	#echo "[$(date +"%T %D")] Waiting for NCBO process to be finished..."| tee -a $log
	for line in $files; do 
		#filename=$(basename "$line")
		##better remove empty line in the file
		cat $line  |perl $BINDIR/ncbo.pl "$NCBOONT" > $line'_parsed' &
	done
	wait
	for line in $files; do 
		rename 's/_raw/_doneraw/' $line
	done
done


echo "[$(date +"%T %D")] Finish NCBO! Joining result..."| tee -a $log
for line in $(find $chunks -iname 'chunk_*_parsed'); do 
	cat $line >> $chunks/all	
done

##parse result
echo "[$(date +"%T %D")] Parsing result..."| tee -a $log
cat $chunks/all > $out
echo "[$(date +"%T %D")] Done...!"| tee -a $log
	
	
exit 0;

