#!/bin/sh
BASEDIR=$(dirname $0)

##load global incl
[ -f $BASEDIR/global.sh ] && . $BASEDIR/global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }
export ROOTDIR
export BINDIR
export DATADIR
export db

clear
PERL5LIB=${PERL5LIB}:$ROOTDIR/lib/BioPerl-1.6.0
PERL5LIB=${PERL5LIB}:$ROOTDIR/lib/biomart/biomart-perl/lib
PERL5LIB=${PERL5LIB}:$ROOTDIR/lib/ensembl-api/ensembl/modules
PERL5LIB=${PERL5LIB}:$ROOTDIR/lib/ensembl-api/ensembl-compara/modules
PERL5LIB=${PERL5LIB}:$ROOTDIR/lib/ensembl-api/ensembl-variation/modules
PERL5LIB=${PERL5LIB}:$ROOTDIR/lib/ensembl-api/ensembl-functgenomics/modules
PERL5LIB=${PERL5LIB}:$ROOTDIR/lib/mylib
export PERL5LIB;


##perpare db
#[ -e $db ] && rm -rf $db && touch $db


if [ $basic = 'y' ]; then
	echo '****************************************************'| tee -a $log
	echo '*********************Basic data*********************'| tee -a $log
	echo '****************************************************'| tee -a $log
	sh $BASEDIR/basic/run.sh 2>&1 | tee -a $log
	echo ''
fi



if [ $sources = 'y' ]; then	
	echo '****************************************************'| tee -a $log
	echo '***********Annotation Sources***********************'| tee -a $log
	echo '****************************************************'| tee -a $log
	sh $BASEDIR/annotation_sources/run.sh 2>&1 | tee -a $log
	echo ''
fi

exit;
exit 0;
