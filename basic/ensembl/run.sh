#!/bin/sh
#############################
## This script is used to fetch data from ensembl FTP
## It fetch the following data and inserted into db
## 1.human genes
## 2.human homologs(currently fly and mouse)
## 3.human SNP
##
## It creates two db tables:
## 1.human_gene
## 2.human_homolog
## 3.human_variation
## 4.human_variation2gene
#############################

BASEDIR=$(dirname $0)

##load global incl
[ -f $BASEDIR/../../global.sh ] && . $BASEDIR/../../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }

scripts=$BASEDIR/scripts
tmp=$BASEDIR/tmp
chunks=$tmp/chunks
data=$BASEDIR/data
queries=$scripts/queries


##create/clean tmp folder
if [ $clean = 'y' ];then
	[ ! -d $tmp ] && mkdir $tmp || rm -rf $tmp/*
	[ ! -d $chunks ] && mkdir $chunks ||  rm -rf $chunks/*
	[ ! -d $data ] && mkdir $data || rm -rf $data/*
fi


#######fetch human gene
if [ $FETCH = 'y' ]; then
	echo "[$(date +"%T %D")] Fetching human gene..."
	if [ $testrun = 'y' ];then
		perl $BINDIR/biomart_xml_query.pl $queries/human_gene.xml |awk -F '\t' '$4~/^[0-9XY]/ {print}'| head -300 > $data/human_gene
	else
		perl $BINDIR/biomart_xml_query.pl $queries/human_gene.xml |awk -F '\t' '$4~/^[0-9XY]/ {print}' > $data/human_gene
	fi


	echo "[$(date +"%T %D")] Fetching homolog..."
	if [ $testrun = 'y' ];then
		`perl $BINDIR/biomart_xml_query.pl $queries/human_fly.xml | awk '/^EN.+\t[A-Z]/ {print $0."\tfly" > "/dev/stdout"}' | head -300  >$tmp/human_fly.homolog` &
		`perl $BINDIR/biomart_xml_query.pl $queries/human_mouse.xml |  awk '/^EN.+\t[A-Z]/ {print $0."\tmouse" > "/dev/stdout"}' | head -300 >$tmp/human_mouse.homolog` &
	else
		`perl $BINDIR/biomart_xml_query.pl $queries/human_fly.xml | awk '/^EN.+\t[A-Z]/ {print $0."\tfly"}' >$tmp/human_fly.homolog` &
		`perl $BINDIR/biomart_xml_query.pl $queries/human_mouse.xml | awk '/^EN.+\t[A-Z]/ {print $0."\tmouse"}' >$tmp/human_mouse.homolog` &
	fi



	echo "[$(date +"%T %D")] Fetching variation..."
	if [ $testrun = 'y' ];then
		`perl $BINDIR/biomart_xml_query.pl $queries/human_variation_test.xml |awk -F '\t' '$3~/^[0-9XY]/ {print}' >$data/human_variation` &
	else
		`perl $BINDIR/biomart_xml_query.pl $queries/human_variation.xml |awk -F '\t' '$3~/^[0-9XY]/ {print}'>$data/human_variation` &
	fi
	wait

	echo "[$(date +"%T %D")] Parsing..." 

	#####merge homolog
	cat /dev/null > $tmp/human_homolog
	for line in $(find $tmp -iname '*.homolog'); do
		cat $line >> $tmp/human_homolog
	done
	sort $tmp/human_homolog >$data/human_homolog


	echo '****************Result****************'
	for result in $(find $data -type f); do
		echo  $result Count:`wc -l $result | cut -d ' ' -f1`
		head -2 $result
		echo ...
		echo '#############################################################'
	done
fi

##insert into db
if [ $INSERT = 'y' ]; then
	echo "[$(date +"%T %D")] Inserting into $db"
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/human_gene -d $db -t human_gene
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/human_homolog -d $db -t human_homolog
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/human_variation -d $db -t human_variation


	#####calculate variation2gene
	echo "[$(date +"%T %D")] Calculating human variation to gene..." 
	perl $scripts/variation2gene.pl -d $db >$data/human_variation2gene

	##insert into db
	echo "[$(date +"%T %D")] Inserting into $db"
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/human_variation2gene -d $db -t human_variation2gene
fi

echo "Done..."



exit 0;
