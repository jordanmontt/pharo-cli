#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../src/api.sh"
    source "$BATS_TEST_DIRNAME/../src/command_parser.sh"

    export TEST_DIR=$(mktemp -d)
    export PHARO_IMAGES_DIR="$TEST_DIR/images"
    mkdir -p "$PHARO_IMAGES_DIR"
    export PROGRAM_NAME="pharo-cli"
    export COMMAND_NAME="pharo"
    export VERSION_NUMBER="0.8"
    export LOCAL_VM_DIR="$TEST_DIR/fake_vm"
    mkdir -p "$LOCAL_VM_DIR"

    # Mock fzf and other dependencies
    fzf() { echo "test-image"; }
    export -f fzf
    trash() { mv "$1" "$TEST_DIR/trash"; }
    export -f trash
    curl() { echo "Mock download"; }
    export -f curl
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "parse_user_input: calls open_command" {
    mkdir -p "$PHARO_IMAGES_DIR/test-image"
    touch "$PHARO_IMAGES_DIR/test-image/test.image"
    run parse_user_input open
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Opening Pharo image" ]]
}

@test "parse_user_input: handles unknown command" {
    run parse_user_input invalid
    [ "$status" -eq 1 ]
    [ "$output" = "Unknow command invalid" ]
}

@test "parse_user_input: calls help command" {
    run parse_user_input help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "pharo-cli - A Pharo Images Manager" ]]
}