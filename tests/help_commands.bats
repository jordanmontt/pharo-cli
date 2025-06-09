#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../src/help_commands.sh"

    export PROGRAM_NAME="pharo-cli"
    export COMMAND_NAME="pharo"
    export VERSION_NUMBER="0.8"
}

@test "print_version: displays correct version" {
    run print_version
    [ "$status" -eq 0 ]
    [ "$output" = "pharo-cli - A Pharo Images Manager [version 0.8]" ]
}

@test "print_help: includes all sections" {
    run print_help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "pharo-cli - A Pharo Images Manager [version 0.8]" ]]
    [[ "$output" =~ "Usage: pharo <command> [arguments]" ]]
    [[ "$output" =~ "Commands:" ]]
    [[ "$output" =~ "Developed by jordanmontt" ]]
}

@test "print_examples: includes all examples" {
    run print_examples
    [ "$status" -eq 0 ]
    [[ "$output" =~ "pharo new" ]]
    [[ "$output" =~ "pharo open -logLevel=4" ]]
    [[ "$output" =~ "pharo help" ]]
}