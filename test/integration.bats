#!/usr/bin/env bats

# use environment vars, else set defaults for test
WEBHOOK="${WEBHOOK:=https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX}"
COLLECTION="${COLLECTION:='test/collections/PostmanEcho.postman_collection.json'}"

@test "should be successful when correct args given" {
    run ./Newman-to-Slack.sh -w $WEBHOOK -c $COLLECTION
    [ $status -eq 0 ]
}