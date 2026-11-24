#!/usr/bin/env bats
# The settings library: defaults, config file, environment overrides and
# validation.

load helpers/common

setup() { sandbox_setup; }

@test "every setting has a default, a type and a description" {
    run_lib 'config_table'
    assert_success
    while IFS='|' read -r key default type description; do
        [ -n "$key" ] && [ -n "$type" ] && [ -n "$description" ] || fail "incomplete setting line: $key"
    done <<<"$output"
}

@test "the defaults apply when nothing is set" {
    run_lib 'config_get imagesDir; config_get defaultTemplate; config_get vmStatus; config_get openMode; config_get autoOpenOnNew; config_get picker; config_get templatesCacheTtl; config_get filesServer; config_get templatesUrl'
    assert_success
    assert_line --index 0 "$HOME/Documents/PharoCliImages"
    assert_line --index 1 stable
    assert_line --index 2 stable
    assert_line --index 3 foreground
    assert_line --index 4 true
    assert_line --index 5 auto
    assert_line --index 6 86400
    assert_line --index 7 https://files.pharo.org
    assert_line --index 8 https://files.pharo.org/pharo-launcher/sources.list
}

@test "the config file overrides a default" {
    write_config "openMode=background"
    run_lib 'config_get openMode; config_origin openMode'
    assert_output "background
file"
}

@test "an environment variable overrides the config file" {
    write_config "openMode=background"
    run env PHARO_CLI_OPEN_MODE=foreground PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; config_get openMode; config_origin openMode'
    assert_output "foreground
env"
}

@test "environment variable names are the key in upper snake case" {
    run_lib 'config_env_name imagesDir; config_env_name templatesCacheTtl; config_env_name vmArgs'
    assert_output "PHARO_CLI_IMAGES_DIR
PHARO_CLI_TEMPLATES_CACHE_TTL
PHARO_CLI_VM_ARGS"
}

@test "the config file location follows XDG_CONFIG_HOME" {
    run env XDG_CONFIG_HOME="$SANDBOX/xdg" PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; config_file'
    assert_output "$SANDBOX/xdg/pharo-cli/config"
}

@test "a leading ~ in a path setting is expanded, in the file and the environment" {
    write_config "imagesDir=~/my images"
    run_lib 'config_get imagesDir; config_raw imagesDir'
    assert_output "$HOME/my images
~/my images"
    run env PHARO_CLI_IMAGES_DIR="~/other" PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; config_get imagesDir'
    assert_output "$HOME/other"
}

@test "values are read literally: no quoting, no command execution" {
    write_config 'vmArgs=--logLevel=4 $(touch '"$SANDBOX"'/pwned)'
    run_lib 'config_get vmArgs'
    assert_output '--logLevel=4 $(touch '"$SANDBOX"'/pwned)'
    [ ! -e "$SANDBOX/pwned" ]
}

@test "comments and unknown lines in the config file are ignored" {
    write_config "# openMode=background" "garbage line" "picker=select"
    run_lib 'config_get openMode; config_get picker'
    assert_output "foreground
select"
}

@test "the last value wins when a key appears twice" {
    write_config "picker=fzf" "picker=select"
    run_lib 'config_get picker'
    assert_output select
}

@test "a value may contain =" {
    write_config "vmArgs=--logLevel=4"
    run_lib 'config_get vmArgs'
    assert_output -- "--logLevel=4"
}

@test "config_set keeps other keys and comments and replaces the old value" {
    write_config "# my settings" "picker=fzf" "openMode=background"
    run_lib 'config_set picker select && cat "$(config_file)"'
    assert_output "# my settings
openMode=background
picker=select"
}

@test "config_set creates the config folder" {
    run_lib 'config_set picker select && cat "$(config_file)"'
    assert_output "picker=select"
}

@test "config_unset removes only that key" {
    write_config "picker=fzf" "openMode=background"
    run_lib 'config_unset picker && cat "$(config_file)" && config_get picker'
    assert_output "openMode=background
auto"
}

@test "config_reset removes the config file" {
    write_config "picker=fzf"
    run_lib 'config_reset; [ ! -e "$(config_file)" ] && config_get picker'
    assert_output auto
}

@test "validation: enums accept only their values" {
    run_lib 'config_validate openMode background && config_validate openMode sideways'
    assert_failure
    assert_output "'openMode' must be one of: foreground, background"
}

@test "validation: booleans, numbers, URLs, paths and templates" {
    run_lib 'config_validate autoOpenOnNew false && config_validate autoOpenOnNew yes'
    assert_failure
    assert_output "'autoOpenOnNew' must be true or false"
    run_lib 'config_validate templatesCacheTtl 60 && config_validate templatesCacheTtl soon'
    assert_output "'templatesCacheTtl' must be a whole number"
    run_lib 'config_validate filesServer https://mirror.example && config_validate templatesUrl file:///tmp/s.list && config_validate filesServer mirror.example'
    assert_output "'filesServer' must be an http(s) or file URL"
    run_lib 'config_validate imagesDir ""'
    assert_output "'imagesDir' cannot be empty"
    run_lib 'config_validate defaultTemplate ""'
    assert_output "'defaultTemplate' cannot be empty"
    run_lib 'config_validate vmArgs "" && echo ok'
    assert_output ok
}

@test "validation: values cannot span several lines" {
    run_lib 'config_validate vmArgs "a
b"'
    assert_failure
    assert_output "values cannot span several lines"
}

@test "completion values: enums, booleans and template keywords" {
    run_lib 'config_suggested_values vmStatus; config_suggested_values autoOpenOnNew; config_suggested_values defaultTemplate; config_suggested_values imagesDir'
    assert_output "stable
latest
true
false
stable
latest"
}
