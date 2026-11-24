#!/usr/bin/env bash
# Loads pharo-cli and dispatches the command line to a command. Sourced by
# bin/pharo, which sets PHARO_CLI_ROOT.

for pharo_cli_file in "$PHARO_CLI_ROOT"/src/lib/*.sh "$PHARO_CLI_ROOT"/src/commands/*.sh; do
    # shellcheck source=/dev/null
    . "$pharo_cli_file"
done
unset pharo_cli_file

pharo_main() {
    local command
    registry_load
    os_load
    case "${1:-}" in
        '' | -h | --help)
            help_overview
            return "$EXIT_OK"
            ;;
        -v | --version)
            help_version
            return "$EXIT_OK"
            ;;
        __complete)
            shift
            complete_words "$@"
            return "$EXIT_OK"
            ;;
        -*)
            usage_error "unknown option: $1"
            ;;
    esac
    command=$(registry_resolve "$1") || usage_error "unknown command: $1"
    shift
    "$(registry_function "$command")" "$@"
}

# Handles the options every command accepts. $1 is the command, $2 the
# argument being parsed. Returns 1 when $2 is not one of them.
common_option() {
    case "$2" in
        -h | --help)
            help_command "$1"
            exit "$EXIT_OK"
            ;;
        -?*)
            usage_error "unknown option for '$1': $2" "$1"
            ;;
    esac
    return 1
}

# Fails with a usage error when a command gets more positional arguments than
# it takes. $1 is the command, $2 the number taken, $3 the number given.
check_argument_count() {
    [ "$3" -le "$2" ] || usage_error "too many arguments for '$1'" "$1"
}
