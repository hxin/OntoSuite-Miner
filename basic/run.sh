#!/bin/sh
BASEDIR=$(dirname $0)

##create db schema
echo "[$(date +"%T %D")] Create db tables..."
sqlite3 $db <$BASEDIR/sql/create.sqlite

echo "[$(date +"%T %D")] Ensembl..."
sh $BASEDIR/ensembl/run.sh
echo ''

echo "[$(date +"%T %D")] NCBI..."
sh $BASEDIR/ncbi/run.sh









