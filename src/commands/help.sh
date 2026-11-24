#!/usr/bin/env bash
# @command help
# @alias h
# @summary Show the help, for every command or for one.
# @arg [command:command] The command to explain.
# @example pharo help | Show every command, setting and example.
# @example pharo help new | Show the arguments and options of new.

cmd_help() {
    local count=0 name="" command
    while [ $# -gt 0 ]; do
        common_option help "$1" || {
            count=$((count + 1))
            name="$1"
        }
        shift
    done
    check_argument_count help 1 "$count"
    if [ -z "$name" ]; then
        help_overview
        return "$EXIT_OK"
    fi
    command=$(registry_resolve "$name") || usage_error "unknown command: $name"
    help_command "$command"
}
