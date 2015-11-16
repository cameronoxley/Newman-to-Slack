#!/bin/bash

# set default global variables
date=`date +%s`
collection=''
env=''
global=''
webhook=''
url=''
summarize=false
stripColour=''
sendWebhook=true
verbose=false
additional=''
version='1.0'

usage="$(basename "$0") -- Runs a Newman test script and outputs the summary to a Slack webhook

Usage:
    -h 			show this help text
    -c 	[file]    	postman collection to run
    -u 	[url]     	postman collection url to run
    -e 	[file]    	postman environment to reference
    -g 	[file]    	postman global to reference
    -w 	[url] 	  	slack webhook to call
    -a 	[command] 	additional Newman command
    -S 			output summary
    -N  		disable webhook call
    -C  		disable colorized output to screen, use with -S or -V
    -v  		current script version
    -V  		verbose

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

# check if required vars were set
if [ -z "$collection" ] && [ -z "$url" ]
	then
		echo "$usage" >&2
		exit 1
fi

# remove excess options
shift "$((OPTIND-1))"

# process the script
function init () {

    # files used for data manipulation
    local output="$date-postman-newman-output.txt"
    local formatted="$date-postman-newman-formatted-output.txt"
    local summary="$date-postman-newman-summary.txt"
    local noColor="$date-postman-newman-noColor.txt"

    # call newman
    newman -c $collection $env $url $global $additional $stripColour > $output

    # remove multibyte white spaces for slack formatting
    sed 's/ / /g' $output > $formatted

    # output verbose file
    if [ "$verbose" = true ] ; then
        cat $formatted
    fi

    # only get summary lines
    awk '/^Summary:/,/^%Total/ {print}' $formatted > $summary

    # output summary if set
    if [ "$summarize" = true ] ; then
        cat $summary
    fi

    # call webhook
    if [ "$sendWebhook" = true ] ; then

        # remove colour from file
        `cat $summary | perl -pe 's/\x1b\[[0-9;]*m//g' > $noColor`

        # write to a single line
        results=$(cat $noColor |  while read line; do echo -n "$line\\n"; done)

        # post to slack (originally forked from https://gist.github.com/kiichi/938ea910f88bf43b0db1)
        curl -X POST --data-urlencode 'payload={"text": "```'"$results"'```"}' $webhook
    fi

    # cleanup
    rm -rf $output
    rm -rf $formatted
    rm -rf $summary
    rm -rf $noColor
}

# initialize script
init