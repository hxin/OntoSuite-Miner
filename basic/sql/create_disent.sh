#!/bin/sh
BASEDIR=$(dirname $0)

##load global incl
[ -f $BASEDIR/../../global.sh ] && . $BASEDIR/../../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }

if [ -e $DATADIR/DisEnt.sqlite ]; then
	echo "$DATADIR/DisEnt.sqlite exist! Do you want to remove it:[y/n]"
	read ans
	[ $ans = "y" ] && rm $DATADIR/DisEnt.sqlite && echo ""|sqlite3 $DATADIR/DisEnt.sqlite
fi

#sqlite3 $DATADIR/DisEnt.sqlite < $BASEDIR/db.sql
echo ".read $BASEDIR/db.sql"|sqlite3 $DATADIR/DisEnt.sqlite 
echo ".tables"|sqlite3 $DATADIR/DisEnt.sqlite