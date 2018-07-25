#!/usr/bin/env bash

# check for errors and exit
set -e

# config overridable args
collection=''
environment=''
global=''
webhook=''
additional=''

# config environment
config_file=''
config_file_secured=''

# global vars
newman_required_ver='3.1.0'
node_required_ver='4.0.0'
newman_args='--reporter-cli-no-failures --reporter-cli-no-assertions --reporter-cli-no-console --no-color'
verbose=0

# show the version number
version() {
    echo '2.1.0'
}

# show the help and usage
show_help() {

    local script=$(basename "$0")

    usage="$script -- Runs a Newman test script and outputs the summary to a Slack webhook

    Options:
        -h, --help                        Show this help text
        -c, --collection      [arg]       URL or path to a Postman Collection
        -f, --config          [file]      Run a bash configuration environment (overwrites passed args)
        -e, --environment     [file]      Postman Environment to reference
        -w, --webhook         [url]       Slack Webhook URL
        -g, --global          [file]      Postman Global Environment
        -a, --additional      [command]   Additional Newman command
        -v, --verbose         [-v -v]     Verbose (add more -v for increased verbosity)
        -V, --version                     Version

    Where: -c [arg] and -w [url] are required

    Examples:

    $ $script -c \"mycollection.json.postman_collection\" -w \"https://hooks.slack.com/services/url\" -e \"myenvironment.postman_environment\"
    $ $script -c \"https://www.getpostman.com/collections/\" -w \"https://hooks.slack.com/services/url\" -a \"--ignore-redirects\"
    $ $script -f \"config.config\"
    "

    echo "$usage"
}

# fail an arg that takes an option argument
fail_option_arg() {
    declare arg_name="$1"

    printf '\nERROR: %s requires a non-empty option argument.\n\n' "$arg_name" >&2
    show_help
    exit 1
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
                exit 0
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
            -e|--environment)
                if [ -n "$2" ]; then
                    environment=$2
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
            -w|--webhook)
                if [ -n "$2" ]; then
                    webhook=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -a|--additional)
                if [ -n "$2" ]; then
                    additional=$2
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -f|--config)
                if [ -n "$2" ]; then
                    config_file=$2
                    config_file_secured="/tmp/$config_file" #FIXME: Use mktemp for temporary files, always cleanup with a trap.
                    shift
                else
                    fail_option_arg "$arg"
                    exit 1
                fi
                ;;
            -V|--version)
                version
                exit 0
                ;;
            -v|--verbose)
                verbose=$((verbose + 1)) # Each -v argument adds 1 to verbosity.
                ;;
            --) # End of all options.
                shift
                break
                ;;
            -?*)
                printf '\nWARN: Unknown option (ignored): %s\n' "$arg" >&2
                ;;
            *)  # default case: If no more options then break out of the loop.
                break
        esac

        shift
    done
}

# fetches the source config
load_config () {

    declare overrideable_vars=( '^environment=' '^collection=' '^webhook=' '^global=' '^additional=' )
    declare config_filter='^#|^[^ ]*=[^;]*'

    if [ -f "$config_file" ] ; then

        # check if the file contains bash commands and other junk
        if egrep -q -v "$config_filter" "$config_file"; then

            echo "\nWARN: Cleaning config file" >&2

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
            printf '\nLoaded Config file:\n\n %s \n\n' "$(cat $config_file)"
        elif [ "$verbose" -gt 1 ] ; then
            echo '\nLoaded Config file'
        fi

    else
        printf '\nERROR: Could not locate file %s.\n\n' "$config_file" >&2
        exit 1
    fi
}

# calidates required programs
validate_install() {

    # check newman is installed
    command -v newman >/dev/null 2>&1 || { echo >&2 "\nERROR: Newman is required. See https://github.com/postmanlabs/newman. Aborting"; exit 1;}

    # check curl is installed
    command -v curl >/dev/null 2>&1 || { echo >&2 "\nERROR: cURL is required. See https://curl.haxx.se/download.html. Aborting"; exit 1;}

    # check version of newman is correct
    local current_newman_ver="$(newman --version | head -n1 | cut -d" " -f4)"
    if [ "$(printf "$newman_required_ver\n$current_newman_ver" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | head -n1)" == "$current_newman_ver" ] && [ "$current_newman_ver" != "$newman_required_ver" ]; then 
        printf "\nERROR: A newer version of Newman (%s) is required. See https://github.com/postmanlabs/newman/blob/develop/MIGRATION.md. Aborting" "$newman_required_ver" >&2
        exit 1
    fi

    # newman 3.1+ requires node to be > 4
    local current_node_ver="$(node --version | cut -d "v" -f 2 )"
    if [ "$(printf "$node_required_ver\n$current_node_ver" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | head -n1)" == "$current_node_ver" ] && [ "$current_node_ver" != "$node_required_ver" ]; then 
        printf "\nERROR: A newer version of Node (%s) is required for Newman %s. Aborting" "$node_required_ver" "$newman_required_ver" >&2
        exit 1
    fi
}

# validate required args and check options
validate_check_args() {
    
    # validate required args
    if [ -z "$collection" ] || [ -z "$webhook" ] ; then # check one of -c and -u being called
        printf "\nERROR: -c [arg] and -w [url] are required\n\n" >&2
        show_help
        exit 1
    fi
}

# prepend newman args to commands
 prepend_newman_args () {

    if [ -n "$global" ] ; then
        global="-g $global"
    fi

    if [ -n "$environment" ] ; then
        env="-e $environment"
    fi
}

# process the script
main () {

    # validate newman install
    validate_install

    # load args
    parse_args "$@"

    # check if we need to load the config
    if [ -n "$config_file" ] ; then
        load_config
    fi

    # validate arguments
    validate_check_args

    # prepend newman arguments to vars
    prepend_newman_args

    # call newman
    local output=$(newman run $collection $env $url $global $additional_args $newman_args)

    # output verbose file
    if [ "$verbose" -gt 0 ] ; then
        echo "$output"
    fi

    date=`date +%F\ %r`

    # post to slack
    curl -X POST --data-urlencode 'payload={"text": "'"$date"':```'"$output"'```"}' $webhook
}

# initialize script
main "$@"
