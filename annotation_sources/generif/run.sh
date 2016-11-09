#!/bin/sh
BASEDIR=$(dirname $0)

##load global incl
[ -f $BASEDIR/../../global.sh ] && . $BASEDIR/../../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }


if [ $clean = 'y' ];then
	[ ! -d $BASEDIR/tmp ] && mkdir $BASEDIR/tmp;
	[ ! -d $BASEDIR/data ] && mkdir $BASEDIR/data;
fi

echo "Creating annotation from generif...this takes 9 hours(ncbo 8 threads) 49 hours(MM 5 threads).... + 2 hours parsing"

if [ $FETCH = 'y' ]; then
##download Generif
	echo "[$(date +"%T %D")] Fetching from $generif_url..." 
	(cd $BASEDIR/tmp/ && wget -v -N $generif_url)
	chmod 664 $BASEDIR/tmp/generifs_basic.gz
	
################################
## The generif dataset contains some negative associations. 
## Some of the rifs are describing genes that are not associated to a certain function or disease.
## We tested 200 rif with the work 'NOT' and about 50+% are describing negative associations. So we decide to delete all the rifs that contains the work 'NOT'.
## e.g AKT1 pleckstrin homology domain (E17K) mutations do not play a roles in chronic lymphocytic leukaemia and acute myeloid leukaemia
## also remove rifs with 'Observational study of...'
################################
		echo "[$(date +"%T %D")] Parsing ..."
		echo "[$(date +"%T %D")] Deleting noisy rifs (with the word 'NOT')..."
		zgrep -P "^9606" $BASEDIR/tmp/generifs_basic.gz |cut -f2,3,5 | grep -v -P -i "\sNOT\s" | awk -F "\t" '{print $1"\tpubmed/"$2"\t"$3}'|grep -v -P 'Observational study of' >$BASEDIR/data/GeneRIF_basic
fi


if [ $MAP = 'y' ]; then
	head -$testnumber $BASEDIR/data/GeneRIF_basic|cut -f3 |sort| uniq | awk '{print $0."\n"}'> $BASEDIR/tmp/text
	echo "[$(date +"%T %D")] preparing folder..."
	[ ! -d $BASEDIR/tmp/$ONTNAME ] && mkdir $BASEDIR/tmp/$ONTNAME ;
	[ ! -d $BASEDIR/data/$ONTNAME ] && mkdir $BASEDIR/data/$ONTNAME;
	sh $BINDIR/mapping.sh -i $BASEDIR/tmp/text -t $(cd $BASEDIR/tmp/$ONTNAME && pwd) -d $(cd $BASEDIR/data/$ONTNAME && pwd)
	##here
#	echo "[$(date +"%T %D")] Mapping ..."
#	
#	[ ! -d $BASEDIR/tmp/$ONTNAME ] && mkdir $BASEDIR/tmp/$ONTNAME ;
#	[ ! -d $BASEDIR/data/$ONTNAME ] && mkdir $BASEDIR/data/$ONTNAME;
#	
#	[ $USE_METAMAP = 'y' ] && sh $BINDIR/metamap.sh -i $BASEDIR/tmp/text -o $BASEDIR/tmp/$ONTNAME/m &
#	sleep 2s
#	[ $USE_NCBO = 'y' ] && sh $BINDIR/ncbo.sh -i $BASEDIR/tmp/text -o $BASEDIR/tmp/$ONTNAME/n -l $NCBOONT & 
#	wait
#	
#	echo "[$(date +"%T %D")] Filtering result ..."
#	cat $BASEDIR/tmp/$ONTNAME/m  $BASEDIR/tmp/$ONTNAME/n > $BASEDIR/data/$ONTNAME/d2t_raw
#	perl $BINDIR/filter.pl -i $BASEDIR/data/$ONTNAME/d2t_raw -o $BASEDIR/data/$ONTNAME/d2t_filtered -l $FILTER_DB -s $DATADIR/stopwords	
fi


##insert into db
if [ $INSERT = 'y' ]; then
	echo "[$(date +"%T %D")] Inserting into $db"
	sqlite3 $db < $BASEDIR/sql/create.sqlite
	sqlite3 $db < $BASEDIR/sql/$ONTNAME/mappingtable.sqlite
##SQLITE .import will quote each column with double-quote. So if a column starts with double-quote, it create errors.
## example :"rapid or intermediate NAT2 genotypes" are associated with an elevated risk for acute myeloid leukemia.
## solution: Only temp solution. Put another double quote to enclose the whole column. It will still give error but will insert the column right.
	perl $BINDIR/import2sqlite.pl -i $BASEDIR/data/GeneRIF_basic -d $db -t source_GENERIF
	perl $BINDIR/import2sqlite.pl -i $BASEDIR/data/$ONTNAME/d2t_raw -d $db -t  mapping_${ONTNAME}_GENERIF_raw
	perl $BINDIR/import2sqlite.pl -i $BASEDIR/data/$ONTNAME/d2t_filtered -d $db -t  mapping_${ONTNAME}_GENERIF_filter
	sqlite3 $db < $BASEDIR/sql/$ONTNAME/join.sqlite
	echo "[$(date +"%T %D")] Done!"
fi
exit 0;
