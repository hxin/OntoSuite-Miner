#!/bin/sh
##############################
## use biomart to fetch data
## http://www.ensembl.org/biomart/martview/eb985e1b1bc159fe1e6cdb74cf6c76cc
##############################
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
	[ ! -d $tmp ] && mkdir $tmp
	[ ! -d $chunks ] && mkdir $chunks || rm -rf $chunks/*
	[ ! -d $data ] && mkdir $data || rm -rf $data/*
fi



if [ $FETCH = 'y' ]; then
	echo "[$(date +"%T %D")] Fetching variation and phenotypes..."
	#echo "[$(date +"%T %D")] Filtering variants from HGMD which have no phenotype data ..."
	#perl $BINDIR/biomart_xml_query.pl $queries/v2p_test.xml | sort | uniq >$data/variation_v2p
	#perl $BINDIR/biomart_xml_query.pl $queries/v2p.xml |tee $data/variation_v2p
	if [ $testrun = 'y' ];then
		perl $BINDIR/biomart_xml_query.pl $queries/v2p.xml | head -300| sort | uniq | grep -P '^rs' >$data/variation_v2p
	else
		perl $BINDIR/biomart_xml_query.pl $queries/v2p.xml | sort | uniq | grep -P '^rs'|cut -f1,2,3,4,5,6,7,8,9,10,12|awk '$3~/^[0-9XY]/ {print}'|sort|uniq| grep -v 'phenotype not specified' >$data/variation_v2p
	fi
	
	echo "[$(date +"%T %D")] Mapping genes to variants..."
	####add index to VAR table here!!!!!!!!!
	###@todo
sqlite3 $db >$data/variation_g2p <<EOF
DROP TABLE IF EXISTS "source_VAR";
CREATE temp TABLE "VAR" ("variation_id" VARCHAR, "variation_source" VARCHAR, "chromosome_name" VARCHAR, "position" INTEGER, "allele" VARCHAR, "study_type" VARCHAR, "study_external_ref" VARCHAR, "study_description" VARCHAR, "study_source" VARCHAR, "phenotype_description" TEXT,  "p_value" FLOAT);
.separator \t
.import $data/variation_v2p VAR
CREATE INDEX tmp1_variation_id ON VAR (variation_id);
CREATE INDEX tmp2_variation_source ON VAR (variation_source);
CREATE INDEX tmp3_chromosome_name ON VAR (chromosome_name);
CREATE INDEX tmp4_position ON VAR (position);
select t2.entrez_id,t2.position as relative_position,t2.distance,t1.* from VAR as t1 left join human_variation2gene as t2 on t1.variation_id=t2.variation_id where t2.entrez_id!="";
EOF
	
#	echo '****************Result****************'
#	for result in $(find $data -type f); do
#		echo  $result Count:`wc -l $result | cut -d ' ' -f1`
#		head -2 $result
#		echo ...
#		echo '#############################################################'
#	done
#
fi


if [ $MAP = 'y' ]; then
	head -$testnumber $data/variation_g2p|cut -f13 |sort| uniq | awk '{print $0."\n"}'> $BASEDIR/tmp/text
	echo "[$(date +"%T %D")] preparing folder..."
	[ ! -d $BASEDIR/tmp/$ONTNAME ] && mkdir $BASEDIR/tmp/$ONTNAME ;
	[ ! -d $BASEDIR/data/$ONTNAME ] && mkdir $BASEDIR/data/$ONTNAME;
	
	sh $BINDIR/mapping.sh -i $BASEDIR/tmp/text -t $(cd $BASEDIR/tmp/$ONTNAME && pwd) -d $(cd $BASEDIR/data/$ONTNAME && pwd)
fi


if [ $INSERT = 'y' ]; then
#insert into db
	echo "[$(date +"%T %D")] Inserting into $db"
	sqlite3 $db < $BASEDIR/sql/create.sqlite
	sqlite3 $db < $BASEDIR/sql/$ONTNAME/mappingtable.sqlite
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/variation_g2p -d $db -t source_VAR
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/$ONTNAME/d2t_raw -d $db -t mapping_${ONTNAME}_VAR_raw
	perl $BINDIR/import2sqlite.pl -c -i $BASEDIR/data/$ONTNAME/d2t_filtered -d $db -t mapping_${ONTNAME}_VAR_filter
	sqlite3 $db < $BASEDIR/sql/$ONTNAME/join.sqlite
	echo "[$(date +"%T %D")] Done!"
fi

exit 0;



#name='variation';
#des='ensembl variation database'
#link='http://www.ensembl.org/info/genome/variation/index.html'
#
#
#
#
#
#
