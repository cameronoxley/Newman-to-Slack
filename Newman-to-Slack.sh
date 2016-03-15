#!/bin/bash

# check for errors and exit
set -e

# version constant
readonly version='1.1.0'

# set default global variables (can be overridden by config)
collection=''
env=''
global=''
webhook=''
url=''
additional_args=''

# config environment
config_file=''
config_file_secured=''

# local vars
strip_colour=''
summarize=false
verbose=false
send_webhook=true

# readonly vars
readonly overrideable_vars=( '^env=' '^collection=' '^webhook=' '^global=' '^additional_args=' )
readonly config_filter='^#|^[^ ]*=[^;]*'

usage="$(basename "$0") -- Runs a Newman test script and outputs the summary to a Slack webhook

Usage:
    -h            show this help text
    -r [file]     run a bash configuration environment (overwrites passed args)
    -c [file]     postman collection to run
    -u [url]      postman collection url to run
    -e [file]     postman environment to reference
    -w [url]      slack webhook to call
    -g [file]     postman global to reference
    -a [command]  additional Newman command
    -S            output summary
    -N            disable webhook call (prints summary)
    -C            disable colorized output to screen, use with -S or -V
    -v            version
    -V            verbose

Where one of: -c [file] or -u [url] is required"

# pass input values
while getopts ':hSNVvCc:e:g:w:a:r:u:' option; do
    case "$option" in
        h)  echo "$usage"
            exit
            ;;
        c)  collection="$OPTARG"
            ;;
        u)  url="$OPTARG"
            ;;
        r)  config_file="$OPTARG"
			config_file_secured="/tmp/$config_file"
            ;;
        e)  env="$OPTARG"
            ;;
        g)  global="$OPTARG"
            ;;
        w)  webhook="$OPTARG"
            ;;
        a)  additional_args="$OPTARG"
            ;;
        S)  summarize=true
            ;;
        N)  send_webhook=false
            summarize=true
            ;;
        V)  verbose=true
            ;;
        v)  echo "$version" >&2
            exit 1
            ;;
        C)  strip_colour='-C '
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

# remove excess options
shift "$((OPTIND-1))"

# fetches the source config
function loadConfig () {

	if [ -f "$config_file" ] ; then

		# check if the file contains bash commands and other junk
		if egrep -q -v "$config_filter" "$config_file"; then

			echo "Cleaning config file" >&2

			# filter to a clean file
			egrep "$config_filter" "$config_file" > "$config_file_secured"
			config_file="$config_file_secured"
		fi

		# load the file and only override the vars we accept
		for i in "${overrideable_vars[@]}"
		do
			# bash 3.2 fix for source process substitution
			source /dev/stdin <<<"$(grep "$i" "$config_file")"
		done

	else
		printf "\nError: Could not locate file '$config_file'" >&2
		exit 1
	fi
}

# preprend newman args to commands
function prependNewmanArgs () {

	if [ -n "$url" ] ; then
        url="-u $url"
    fi

    if [ -n "$global" ] ; then
        global="-g $global"
    fi

    if [ -n "$env" ] ; then
        env="-e $env"
    fi

    if [ -n "$collection" ] ; then
        collection="-c $collection"
    fi
}

# process the script
function init () {

	# prepend newman arguments to vars
	prependNewmanArgs

    # call newman
    local output=$(newman $collection $env $url $global $additional_args $strip_colour)

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
    if [ "$send_webhook" = true ] ; then

        # remove colour from file
        local noColor=$(echo "$summary" | perl -pe 's/\x1b\[[0-9;]*m//g')

        # post to slack
        curl -X POST --data-urlencode 'payload={"text": "```'"$noColor"'```"}' $webhook
    fi
}

# check if we need to load the config
 if [ -n "$config_file" ] ; then
 	loadConfig
 fi

# validate required args
if [ -z "$collection" ] && [ -z "$url" ] ; then
	printf "\nError: One of -c [file] or -u [url] is required\n\n" >&2
	echo "$usage" >&2
    exit 1
elif [ -n "$collection" ] && [ -n "$url" ] ; then
	# check against both -c and -u being called
	printf "\nError: Only one of -c [file] or -u [url] is required\n\n" >&2
    echo "$usage" >&2
    exit 1
fi

# if verbose and summary are set, disable summary
if [ "$summarize" = true ] && [ "$verbose" = true ] ; then
    summarize=false
fi

# initialize script
init
