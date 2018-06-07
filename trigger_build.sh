#!/bin/bash

set -e

usage() {
    cat <<EOU
Trigger build on Jenkins (requires a user with API token)
The script requires curl and jq.
Usage:
  -b, --base-url         Jenkins base URL
  -j, --job-path         path to the job (with build or buildWithParameters included)
  -u, --user             username to trigger the job
  -t, --token            API token for the user
  -p, --params           build parameters. buildWithParameters must be used for the trigger (optional)
  -v, --verbose          print URLs
  -w, --wait             wait for build to finish
  -h, --help             this help
EOU
}

VERBOSE=0
WAIT=0
HELP=0

TEMP=`getopt -o b:j:u:t:p:vwh --long base-url:,job-path:,user:,token:,params:,verbose,wait,help -n 'trigger_build.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -b|--base-url)
            JENKINS_URL=$2 ; shift 2 ;;
        -j|--job-path)
            JOB_PATH=$2 ; shift 2 ;;
        -u|--user)
            USERNAME=$2 ; shift 2 ;;
        -t|--token)
            TOKEN=$2 ; shift 2 ;;
        -p|--params)
            PARAMS=$2 ; shift 2 ;;
        -v|--verbose) VERBOSE=1 ; shift ;;
        -w|--wait) WAIT=1 ; shift ;;
        -h|--help) HELP=1 ; shift ;;
        --) shift ; break ;;
        *) usage ; exit 1 ;;
    esac
done

if [ $HELP -eq 1 ]
then
    usage
    exit 0
fi

if [ "$JENKINS_URL" = "" ] || \
       [ "$JOB_PATH" = "" ] || \
       [ "$USERNAME" = "" ] || \
       [ "$TOKEN" = "" ]
then
    echo "Parameter missing"
    echo
    usage
    exit 1
fi

CRUMB=$(curl \
            --silent \
            -u "$USERNAME:$TOKEN" \
            "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)"
     )

HEADER=""
if [[ ${CRUMB} =~ ^\.crumb:.+ ]]
then
    HEADER="--header \"$CRUMB\""
fi

TRIGGER_URL=$JENKINS_URL/$JOB_PATH
if [ "$PARAMS" != "" ]
then
    TRIGGER_URL=$TRIGGER_URL?$PARAMS
fi

if [ $VERBOSE -eq 1 ]
then
    echo "Trigger URL: $TRIGGER_URL"
fi

QUEUE_URL=$(curl \
                --silent \
                --dump-header - \
                --output /dev/null \
                --request POST \
                $HEADER \
                "$TRIGGER_URL" \
                --user "$USERNAME:$TOKEN" \
                | \
                grep -oP '^Location: \K.+$' \
                | \
                tr -d '[:space:]'
         )

if [ $WAIT -ne 1 ]
then
    exit 0
fi

if [ "$QUEUE_URL" = "" ]
then
    if [ $VERBOSE -eq 1 ]
    then
        echo "no Queue URL returned"
    fi
    exit 1
fi

if [ $VERBOSE -eq 1 ]
then
    echo "Queue URL: $QUEUE_URL"
fi

BUILD_URL=null
until [ "$BUILD_URL" != "null" ]
do
    sleep 1
    BUILD_URL=$(curl \
                    --silent \
                    --request POST \
                    $HEADER \
                    --user "$USERNAME:$TOKEN" \
                    "$QUEUE_URL/api/json" \
                    | \
                    jq -r '.executable.url'
             )
done

if [ $VERBOSE -eq 1 ]
then
    echo "Build URL: $BUILD_URL"
fi

BUILD_RESULT=null
until [ "$BUILD_RESULT" != "null" ]
do
    sleep 30
    BUILD_RESULT=$(curl \
                       --silent \
                       --request POST \
                       $HEADER \
                       --user "$USERNAME:$TOKEN" \
                       "$BUILD_URL/api/json" \
                       | jq -r '.result'
                )
done

if [ $VERBOSE -eq 1 ]
then
    echo "Build result: $BUILD_RESULT"
fi

if [ "$BUILD_RESULT" != "SUCCESS" ]
then
    exit 1
fi
