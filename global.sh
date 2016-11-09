#!/bin/sh
BASEDIR=$(dirname $0)

config=$BASEDIR/.setting


if [ -f $config ] ; then
    . $config
else
	echo "config file $config is missing, aborting..."
	exit 1
fi

#*****************************************
#** to terminate all subshell jobs on exit
#*****************************************
trap "kill 0" 2 3 9 6




