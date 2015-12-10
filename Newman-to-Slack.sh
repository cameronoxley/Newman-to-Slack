#!/bin/bash

# check for errors and exit
set -e

# set default global variables
collection=''
env=''
global=''
webhook=''
url=''
stripColour=''
additional=''
summarize=false
sendWebhook=true
verbose=false
version='1.0.1'

usage="$(basename "$0") -- Runs a Newman test script and outputs the summary to a Slack webhook

Usage:
    -h            show this help text
    -c  [file]    postman collection to run
    -u  [url]     postman collection url to run
    -e  [file]    postman environment to reference
    -g  [file]    postman global to reference
    -w  [url]     slack webhook to call
    -a  [command] additional Newman command
    -S            output summary
    -N            disable webhook call (prints summary)
    -C            disable colorized output to screen, use with -S or -V
    -v            version
    -V            verbose

Where one of: -c [file] or -u [url] is required"

# pass input values
while getopts ':hSNVvCc:e:g:w:a:' option; do
    case "$option" in
        h)  echo "$usage"
            exit
            ;;
        c)  collection="-c $OPTARG"
            ;;
        u)  url="-u $OPTARG"
            ;;
        e)  env="-e $OPTARG"
            ;;
        g)  global="-g $OPTARG"
            ;;
        w)  webhook="$OPTARG"
            ;;
        a)  additional=$OPTARG
            ;;
        S)  summarize=true
            ;;
        N)  sendWebhook=false
            summarize=true
            ;;
        V)  verbose=true
            ;;
        v)  echo "$version" >&2
            exit 1
            ;;
        C)  stripColour='-C '
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
       \?)  printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done

# check if defaults were set and none overridden with blank
if [ -z "$collection" ] && [ -z "$url" ] ; then
    echo "$usage" >&2
    exit 1
fi

# check if verbose and summary are set, disable summary
if [ "$summarize" = true ] && [ "$verbose" = true ] ; then
    summarize=false
fi

# remove excess options
shift "$((OPTIND-1))"

# process the script
function init () {

    # call newman
    local output=$(newman -c $collection -e $env $url $global $additional $stripColour)

    # output verbose file
    if [ "$verbose" = true ] ; then
        echo "$output"
    fi

    # only get summary lines
    local summary=$(echo "$output" | awk '/^Summary:/,/^%Total/ {print}')

    # output summary if set
    if [ "$summarize" = true ] ; then
        echo "$summary"
    fi

    # call webhook
    if [ "$sendWebhook" = true ] ; then

        # remove colour from file
        local noColor=$(echo "$summary" | perl -pe 's/\x1b\[[0-9;]*m//g')

        # post to slack
        curl -X POST --data-urlencode 'payload={"text": "```'"$noColor"'```"}' $webhook
    fi
}

# initialize script
init
