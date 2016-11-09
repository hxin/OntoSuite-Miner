#!/bin/sh
#############################
## This script is used to fetch data from ncbi FTP
## It fetch the following data and inserted into db
## 1.gene2ensembl mapping
## 2.entrez gene history (some of the entrez gene id is discontinued)
##
## It creates two db tables:
## 1.entrez2ensembl
## 2.gene_history
#############################


BASEDIR=$(dirname $0)

##load global incl
[ -f $BASEDIR/../../global.sh ] && . $BASEDIR/../../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }


tmp=$BASEDIR/tmp
data=$BASEDIR/data




##create/clean tmp folder
if [ $clean = 'y' ];then
	[ ! -d $tmp ] && mkdir $tmp ||  rm -rf $tmp/*
	[ ! -d $data ] && mkdir $data || rm -rf $data/*
fi

	
##e2e
if [ $FETCH = 'y' ]; then
	echo "[$(date +"%T %D")] Fetching entrez2ensembl mapping data from $e2e_url..." 
	`cd $tmp/ && wget -nv -N $e2e_url`
	chmod 664 $tmp/gene2ensembl.gz

	echo "[$(date +"%T %D")] Parsing ..."
	zcat $tmp/gene2ensembl.gz | cut -f 1,2,3 | tail -n+2 > $data/entrez2ensembl

	##gene history
	echo "[$(date +"%T %D")] Fetching  gene history data from $gene_hist_url..." 
	`cd $BASEDIR/tmp/ && wget -nv -N $gene_hist_url`
	chmod 664 $tmp/gene_history.gz	

	echo "[$(date +"%T %D")] Parsing..."
	zgrep "^9606" $tmp/gene_history.gz | tr -d '-' > $data/gene_history_entrez 

	##geneinfo
	echo "[$(date +"%T %D")] Fetching  geneinfo data from $all_geneinfo_url..." 
	`cd $BASEDIR/tmp/ && wget -nv -N $all_geneinfo_url`
	chmod 664 $tmp/All_Data.gene_info.gz

	##ncbi homologene
	echo "[$(date +"%T %D")] Fetching homologene data from $homologene..." 
	`cd $tmp/ && wget -nv -N $homologene`
	echo "[$(date +"%T %D")] Parsing..."
	cut -f1,2,3,4 $tmp/homologene.data >$data/homologene


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
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/entrez2ensembl -d $db -t entrez2ensembl
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/gene_history_entrez -d $db -t gene_history
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/homologene -d $db -t homologene
fi



exit 0;
