#!/usr/bin/env bats

@test "should print warning when config file isnt sanitised" {
    run ./Newman-to-Slack.sh -f "./test/config/dirty.config"
    echo "$output" | grep "WARN: Cleaning config file"
}

@test "should print verbose when config file is loaded with verbose opts" {
    run ./Newman-to-Slack.sh -f "./test/config/valid.config" -v -v -v
    echo "$output" | grep "environment='test'"
}