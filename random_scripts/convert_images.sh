#!/bin/bash

OPTIND=1

verbose=0
let DES_WIDTH=3000;
let DES_HEIGHT=3000;

usage(){
	echo "Usage: $0 -f foldername"
    echo "-v Verbose"
    echo "-w Set max width for landscape"
    echo "-g Set max height for portrait"
    echo "default height and width is 3000px"
	exit 1
}

while getopts "h?vg:w:f:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    v)  verbose=1
        ;;
    g)  DES_WIDTH=$OPTARG
        ;;
    w)  DES_HEIGHT=$OPTARG
        ;;
    f)  FOLDER=$OPTARG
        ;;
    esac
done

function log(){
    if [[ $verbose -eq 1 ]];
    then
        echo "$@"
    fi
}


for file in $FOLDER/*.jpg; do
    WIDTH=$(identify -format '%w' $file);
    HEIGHT=$(identify -format '%h' $file);
    log "Width: ${WIDTH}"
    log "Heigh: ${HEIGHT}"

    if [[ "$WIDTH" -ge "$HEIGHT" ]];
    then
        PERCENT=$(($DES_WIDTH*100/$WIDTH));
        log "landscape ${PERCENT}";
    else
        PERCENT=$(($DES_HEIGHT*100/$HEIGHT));
        log "portrait ${PERCENT}";
    fi
    if [[ "$PERCENT" -lt 99 ]];
    then
        convert -resize ${PERCENT}% $file $file
        log "$file converted"
    else
        log "$file doesn't need shrinking"
    fi
done
