#!/usr/bin/env bats

@test "should always pass when test is run (control test)" {
    result="$(echo 2 + 2 | bc)"
    [ "${result}" -eq 4 ]
}