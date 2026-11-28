#!/usr/bin/env bats
# pharo templates

load ../helpers/common

setup() {
    sandbox_setup
    serve_catalogue
}

@test "lists template ids and names" {
    run_pharo templates
    assert_success
    assert_line --index 0 --regexp '^ID +NAME$'
    assert_line --regexp '^pharo-14\.0-64bit-stable +Pharo 14\.0 - 64bit \(stable\)$'
    assert_line --regexp '^pharo-mooc +Pharo Mooc$'
}

@test "a filter keeps matching ids or names, ignoring case" {
    run_pharo templates MOOSE
    assert_success
    assert_line --index 0 --regexp '^ID +NAME$'
    assert_line --index 1 --regexp '^moose-suite-14-development '
    refute_output --partial pharo-mooc
}

@test "no match is reported" {
    run_pharo templates zzz
    assert_failure 1
    assert_output "No template matches 'zzz'."
}

@test "--refresh downloads the list again" {
    run_pharo templates
    run_pharo templates --refresh
    assert_success
    run curl_requests
    assert_equal "${#lines[@]}" 2
}

@test "--refresh fails when the list cannot be downloaded" {
    rm "$FAKE_HTTP_ROOT/files.pharo.org/pharo-launcher/sources.list"
    run_pharo templates --refresh
    assert_failure 4
    assert_output --partial "could not download the template list"
}

@test "--json prints a JSON array of id, name and url" {
    run_pharo templates pharo-14.0-64bit-stable --json
    assert_success
    assert_json '[.[] | keys] | unique' '[["id","name","url"]]'
    assert_json '.[0].id' '"pharo-14.0-64bit-stable"'
    run_pharo templates nothing-matches --json
    assert_failure 1
    assert_line --index 0 "[]"
}
