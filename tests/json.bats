#!/usr/bin/env bats
# Writing JSON without jq.

load helpers/common

setup() { sandbox_setup; }

@test "strings are escaped, empty values are null, other types are printed as they are" {
    run_lib 'S=$PHARO_CLI_SEP; { json_field text string "a\\b\"c	d$(printf "\001")é"; json_field none string ""; json_field count number 42; json_field flag bool true; json_field inner json "{\"x\":1}"; json_field sep string "x${S}y"; } | json_object'
    assert_success
    assert_output "{\"text\":\"a\\\\b\\\"c\\td\\u0001é\",\"none\":null,\"count\":42,\"flag\":true,\"inner\":{\"x\":1},\"sep\":\"x\\u001fy\"}"
}

@test "arrays join one value per line" {
    run_lib 'printf "1\n{}\n\"a\"\n" | json_array; printf "" | json_array'
    assert_output '[1,{},"a"]
[]'
}

@test "dates are ISO 8601 in UTC" {
    run_lib 'json_date 0; json_date ""; echo "|"'
    assert_output "1970-01-01T00:00:00Z
|"
}
