#!/bin/sh
BASEDIR=$(dirname $0)


##load global incl
[ -f $BASEDIR/../global.sh ] && . $BASEDIR/../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }

echo "[$(date +"%T %D")] omim..."
sh $BASEDIR/omim/run.sh 
echo ''


echo "[$(date +"%T %D")] variation..."
sh $BASEDIR/variation/run.sh 
echo ''


echo "[$(date +"%T %D")] generif..."
sh $BASEDIR/generif/run.sh 
echo ''


##insert into db
echo -n "[$(date +"%T %D")] joining tables..."
sqlite3 $db < $BASEDIR/sql/join.sqlite

exit 0;





echo "[$(date +"%T %D")] huge..."
sh $BASEDIR/huge/run.sh 
echo ''

echo "[$(date +"%T %D")] disgenet..."
sh $BASEDIR/disgenet/run.sh 
echo ''


##insert into db
echo -n "[$(date +"%T %D")] joining tables..."
sqlite3 $db < $BASEDIR/sql/join.sqlite



echo "Done!"
