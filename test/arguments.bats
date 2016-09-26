#!/usr/bin/env bats

@test "should always pass when test is run" {
    run ./Newman-to-Slack.sh -V
    echo "$output" >&2
    result="$(echo 2 + 2 | bc)"
    [ "${result}" -eq 4 ]
}

@test "should print instructions when no arguments are passed" {
    run ./Newman-to-Slack.sh
    [ $status -eq 1 ]
    [ "${#lines[@]}" -gt 3 ]
    echo "$output" | grep "Options:"
}

@test "should print version number when -V and --version are passed" {
    run ./Newman-to-Slack.sh -V
    [ "$status" -eq 0 ]
    [ $(expr "$output" : "[0-9][0-9.][0-9.]*") -ne 0 ]
}

@test "should print help when -h and --help are passed" {
    run ./Newman-to-Slack.sh -h
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -gt 3 ]
    echo "$output" | grep "Options:"
}

@test "should print required args when invalid is passed" {
    run ./Newman-to-Slack.sh
    [ "$status" -eq 1 ]
    echo "$output" | grep "ERROR: One of"
}

@test "should print required args when only one of required args is passed" {
    run ./Newman-to-Slack.sh -w http://
    [ "$status" -eq 1 ]
    echo "$output" | grep "ERROR: One of"
}

@test "should fail for a non-empty option argument when argument isnt passed" {
    run ./Newman-to-Slack.sh -e
    [ "$status" -eq 1 ]
    echo "$output" | grep "ERROR: -e requires a non-empty option argument."
}

@test "should print error when cant find config file" {
    run ./Newman-to-Slack.sh -f invalid.config
    [ "$status" -eq 1 ]
    echo "$output" | grep "ERROR: Could not locate file*"
}

@test "should ignore unknown arguments when given" {
    run ./Newman-to-Slack.sh -Q
    [ "$status" -eq 1 ]
    echo "$output" | grep "WARN: Unknown option (ignored): -Q"
}