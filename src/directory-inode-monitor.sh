#!/usr/bin/env bash
set -e

e() {
    echo "[$(date +%Y-%m-%d' '%H:%M:%S)] $1"
}

# usage
usage () {
  echo "Usage: ${0##*/} [-h|--help] [--delete-all] <dir> <threshold> <datadog-metric> <datadog-api-key> [datadog-tags]"
  exit 0
}

# default value
DATADOG_TAGS='environment:test'

# read arguments
for ARG in $@
do
    case "$1" in
        -h|--help) usage; ;;
        -d|--debug) isDebug=1; e "Debug mode"; set -x; shift; ;;
        --delete-all) DELETE_ALL=1; shift; ;;
        # *) shift; ;;
    esac
done

if [ $# -lt 4 ]; then usage; fi

DIR=$1
THRESHOLD=$2
DATADOG_METRIC=$3
DATADOG_API_KEY=$4
if [ ! -z $5 ]; then DATADOG_TAGS=$5; fi

# get inode usage
NUM="$(du --inodes -s ${DIR} | awk '{ print $1; }')"
e "$NUM inodes used by ${DIR}"

# push to datadog custom metric
e "Sending inode usage to Datadog custom metric ${DATADOG_METRIC}"
currenttime=$(date +%s)
curl  -X POST -H "Content-type: application/json" \
-d "{ \"series\" :
         [{\"metric\":\"${DATADOG_METRIC}\",
          \"points\":[[$currenttime, $NUM]],
          \"type\":\"gauge\",
          \"host\":\"$(hostname)\",
          \"tags\":[\"${DATADOG_TAGS}\"]}
        ]
    }" \
"https://app.datadoghq.com/api/v1/series?api_key=${DATADOG_API_KEY}"
e

# check inode usage against threshold
if (( $NUM < $THRESHOLD )); then
    e "Under threshold ${THRESHOLD}. All good."
else
    e "OVER threshold $THRESHOLD. ${DIR} needs some clean up."
    if [ ! -z $DELETE_ALL ]; then
        e "Deleting everything in ${DIR} ... "
        rm -rf ${DIR}/*
        e "Deleted everything in ${DIR}"
    fi
fi