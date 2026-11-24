#!/usr/bin/env bash
# @command version
# @alias v
# @summary Show the version of pharo-cli.
# @example pharo version | Print the version.

cmd_version() {
    while [ $# -gt 0 ]; do
        common_option version "$1" || check_argument_count version 0 1
        shift
    done
    help_version
}
