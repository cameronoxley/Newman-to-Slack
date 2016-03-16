#!/usr/bin/env bash

# check for errors and exit
set -e

# config overridable args
collection=''
env=''
global=''
webhook=''
url=''
additional_args=''

# config environment
config_file=''
config_file_secured=''

# global vars
strip_colour=''
summarize=false
verbose=0
send_webhook=true

# show the version number
version() {
    echo '1.1.1' >&2
}

# show the help and usage
show_help() {

    local script=$(basename "$0")

    usage="$script -- Runs a Newman test script and outputs the summary to a Slack webhook

    options:
        -h, --help                        show this help text
        -c, --collection      [file]      postman collection to run
        -r, --config          [file]      run a bash configuration environment (overwrites passed args)
        -u, --url             [url]       postman collection url to run
        -e, --environment     [file]      postman environment to reference
        -w, --slack_webhook   [url]       slack webhook to call
        -g, --global          [file]      postman global to reference
        -a, --newman_command  [command]   additional Newman command
        -S, --summary                     output summary
        -N, --no_webhook                  disable webhook call (prints summary)
        -C, --no_color                    disable colorized output to screen, use with -S or -V
        -v, --verbose         [-v -v]     verbose add more -v for increased verbosity
        -V, --version                     version

    Where one of: -c [file] or -u [url] is required

    examples:

    $ $script -c \"mycollection.json.postman_collection\" -w \"https://hooks.slack.com/services/my/private/url\" -e \"myenvironment.postman_environment\"
    $ $script -u \"https://www.getpostman.com/collections/\" -w \"https://hooks.slack.com/services/my/private/url\" -a \"-R -E 'output.html'\"
    $ $script -r \"config.cfg\"
    "

    echo "$usage" >&2
}

# fail an arg that takes an option argument
fail_option_arg() {
    declare arg_name="$1"

    printf '\nERROR: %s requires a non-empty option argument.\n\n' "$arg_name" >&2
    show_help
}

# parse opts
parse_args() {
    while :; do

        arg="$1"

        # check for empy opts
        if [ "" = "$1" ]; then
            break;
        fi

        # drop pointless leading arg
        if [ "${arg:0:1}" != "-" ]; then
            shift
            continue
        fi

        case $arg in
            -h|-\?|--help) # call a "show_help" function to display a synopsis, then exit.
                show_help
                exit
                ;;
            -C|--no_color) # do this first for error messages
                strip_colour='-C '
                ;;
            -c|--collection)
                if [ -n "$2" ]; then
                    collection=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -u|--url)
                if [ -n "$2" ]; then
                    url=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -e|--environment)
                if [ -n "$2" ]; then
                    env=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -g|--global)
                if [ -n "$2" ]; then
                    global=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -w|--slack_webhook)
                if [ -n "$2" ]; then
                    webhook=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -a|--newman_command)
                if [ -n "$2" ]; then
                    additional_args=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -r|--config)
                if [ -n "$2" ]; then
                    config_file=$2
                    config_file_secured="/tmp/$config_file" #FIXME: Use mktemp for temporary files, always cleanup with a trap.
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -N|--no_webhook)
                send_webhook=false
                summarize=true
                ;;
            -S|--summarize)
                summarize=true
                ;;
            -V|--version)
                version
                exit 1
                ;;
            -v|--verbose)
                verbose=$((verbose + 1)) # Each -v argument adds 1 to verbosity.
                ;;
            --) # End of all options.
                shift
                break
                ;;
            -?*)
                printf 'WARN: Unknown option (ignored): %s\n' "$arg" >&2
                ;;
            *)  # default case: If no more options then break out of the loop.
                break
        esac

        shift
    done
}

# fetches the source config
load_config () {

    declare overrideable_vars=( '^env=' '^collection=' '^webhook=' '^global=' '^additional_args=' )
    declare config_filter='^#|^[^ ]*=[^;]*'

	if [ -f "$config_file" ] ; then

		# check if the file contains bash commands and other junk
		if egrep -q -v "$config_filter" "$config_file"; then

			echo "WARN: Cleaning config file" >&2

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

        # output verbose info
        if [ "$verbose" -gt 2 ] ; then
            printf '\nLoaded Config file:\n\n %s \n\n' "$(cat $config_file)" >&2
        elif [ "$verbose" -gt 1 ] ; then
            echo 'Loaded Config file' >&2
        fi

	else
        printf '\nERROR: Could not locate file %s.\n\n' "$config_file" >&2
		exit -1
	fi
}

# validate required args and check options
validate_check_args() {
    
    # validate required args
    if [ -z "$collection" ] && [ -z "$url" ] ; then # check one of -c and -u being called
        printf "\nERROR: One of -c [file] or -u [url] is required\n\n" >&2
        show_help
        exit 1

    elif [ -n "$collection" ] && [ -n "$url" ] ; then # check against both -c and -u being called
        printf "\nERROR: Only one of -c [file] or -u [url] is required\n\n" >&2
        show_help
        exit 1
    fi

    # if verbose and summary are set, disable summary
    if [ "$summarize" = true ] && [ "$verbose" -gt 0 ] ; then
        summarize=false
    fi
}

# preprend newman args to commands
 prepend_newman_args () {

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
main () {

    #load args
    parse_args "$@"

    # check if we need to load the config
    if [ -n "$config_file" ] ; then
        load_config
    fi

    validate_check_args

	# prepend newman arguments to vars
	prepend_newman_args

    # call newman
    local output=$(newman $collection $env $url $global $additional_args $strip_colour)

    # output verbose file
    if [ "$verbose" -gt 0 ] ; then
        echo "$output" >&2
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
        local no_color=$(echo "$summary" | perl -pe 's/\x1b\[[0-9;]*m//g')

        # post to slack (originally forked from https://gist.github.com/kiichi/938ea910f88bf43b0db1)
        curl -X POST --data-urlencode 'payload={"text": "```'"$no_color"'```"}' $webhook
    fi
}

# initialize script
main "$@"
