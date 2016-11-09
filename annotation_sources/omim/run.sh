#!/bin/sh
BASEDIR=$(dirname $0)

##load global incl
[ -f $BASEDIR/../../global.sh ] && . $BASEDIR/../../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }

if [ $clean = 'y' ];then
	[ ! -d $BASEDIR/tmp ] && mkdir $BASEDIR/tmp;
	[ ! -d $BASEDIR/data ] && mkdir $BASEDIR/data;
fi


echo "Creating annotation from omim...this takes 10 mis.... + 2 mins parsing"


if [ $FETCH = 'y' ]; then
	echo "[$(date +"%T %D")] Fetching from $mim2gene_url..." 
	(cd $BASEDIR/tmp/ && wget -nv -N $mim2gene_url)
	chmod 664 $BASEDIR/tmp/mim2gene.txt
	echo "[$(date +"%T %D")] Fetching from $morbidmap_url..." 
	(cd $BASEDIR/tmp/ && wget -nv -N $morbidmap_url)
	chmod 664 $BASEDIR/tmp/morbidmap

	echo "[$(date +"%T %D")] Parsing ..."
	perl $BASEDIR/scripts/omim_d2g.pl -f1 $BASEDIR/tmp/mim2gene.txt -f2 $BASEDIR/tmp/morbidmap > $BASEDIR/data/OMIM_raw
fi

if [ $MAP = 'y' ]; then
	head -$testnumber $BASEDIR/data/OMIM_raw|cut -f4 |sort| uniq | awk '{print $0."\n"}'> $BASEDIR/tmp/text
	echo "[$(date +"%T %D")] preparing folder..."
	[ ! -d $BASEDIR/tmp/$ONTNAME ] && mkdir $BASEDIR/tmp/$ONTNAME ;
	[ ! -d $BASEDIR/data/$ONTNAME ] && mkdir $BASEDIR/data/$ONTNAME;
	
	sh $BINDIR/mapping.sh -i $BASEDIR/tmp/text -t $(cd $BASEDIR/tmp/$ONTNAME && pwd) -d $(cd $BASEDIR/data/$ONTNAME && pwd)
fi


##insert into db
if [ $INSERT = 'y' ]; then
	echo "[$(date +"%T %D")] Inserting into $db"
	sqlite3 $db < $BASEDIR/sql/create.sqlite
	sqlite3 $db < $BASEDIR/sql/$ONTNAME/mappingtable.sqlite
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/OMIM_raw -d $db -t  source_OMIM
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/$ONTNAME/d2t_raw -d $db -t  mapping_${ONTNAME}_OMIM_raw
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/$ONTNAME/d2t_filtered -d $db -t  mapping_${ONTNAME}_OMIM_filter
	sqlite3 $db < $BASEDIR/sql/$ONTNAME/join.sqlite
	echo "[$(date +"%T %D")] Done!"
fi
exit 0;























exit;



if [ $NEED_UPDATE_DB -eq 1 ]; then
	echo "[$(date +"%T %D")] Updating db..."$(date +"%T")
	mysql -h $HOST -u $USER -p$PSW $DB <$BASEDIR/db.sql
	mysqlimport -h $HOST -u $USER -p$PSW -c mim_acc,type,entrez_id,gene_symbol -L $DB $BASEDIR/tmp/OMIM_mim2gene.txt	
	perl $BASEDIR/omim_d2g.pl $DB $HOST $USER $PSW $MORBIDMAP > $D2G
	mysqlimport -h $HOST -u $USER -p$PSW -c description,disorder_mim_acc,gene_symbol,locus_mim_acc,location -L $DB $D2G
fi


exit 0;

#create two table base on the ftp file
if [ $USECACHE = 'n' ]; then
wget -O $BASEDIR/tmp/mim2gene.txt ftp://anonymous:xin.he%40ed.ac.uk@grcf.jhmi.edu/OMIM/mim2gene.txt
wget -O $BASEDIR/tmp/morbidmap.txt ftp://grcf.jhmi.edu/OMIM/morbidmap
fi


#create db tables
mysql -h $HOST -u $USER -p$PSW $DB <$BASEDIR/omim.sql

#disease2gene
echo 'Parsing omim raw file...'$(date +"%T")
perl $BASEDIR/disease2gene/omim_d2g.pl $DB $HOST $USER $PSW $BASEDIR/tmp/morbidmap > $BASEDIR/tmp/OMIM_disease2gene.txt

mysqlimport -h $HOST -u $USER -p$PSW -c description,disorder_mim_acc,gene_symbol,locus_mim_acc,location -L $DB $BASEDIR/tmp/OMIM_disease2gene.txt
#mim2gene

#sed -e 's/\t-/ /g' $BASEDIR/tmp/mim2gene.txt | tail -n+2 > $BASEDIR/tmp/OMIM_mim2gene.txt
cat $BASEDIR/tmp/mim2gene.txt | tail -n+2 > $BASEDIR/tmp/OMIM_mim2gene.txt

echo 'inserting into db...'$(date +"%T")
mysqlimport -h $HOST -u $USER -p$PSW -c mim_acc,type,entrez_id,gene_symbol -L $DB $BASEDIR/tmp/OMIM_mim2gene.txt


#echo "caculating omim_human_gene2disease..."$(date +"%T")
#mysql -h $HOST -u $USER -p$PSW $DB <$BASEDIR/caculate_omim_gene2disease.sql
