#!/bin/bash

# read the options
TEMP=`getopt -o t:,h:: --long type:,help:: -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
	-h|--help)
	    echo "linuxdocs.sh Build the documentation for a boost library" ;
	    exit 0
	    ;;
        -t|--type)
            case "$2" in
                "") typeoption='not_specified' ; shift 2 ;;
                 *) typeoption=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [ -n "$1" ]; then
    echo "library path is $1. Changing to that directory"
    cd $1
else
    workingdir=$(pwd)
    echo "Using working directory $workingdir"
fi

echo "Type is $typeoption"
