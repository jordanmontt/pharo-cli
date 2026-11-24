#!/usr/bin/env bash
# Core helpers shared by every part of pharo-cli: messages, errors, exit codes
# and small string utilities. Everything here is Bash 3.2 compatible.

# Globals used by the other files.
# shellcheck disable=SC2034

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1   # a command failed or the user cancelled
readonly EXIT_USAGE=2   # the command line was wrong

PHARO_CLI_COMMAND_NAME="pharo"
PHARO_CLI_PROGRAM_NAME="pharo-cli"
PHARO_CLI_REPOSITORY="jordanmontt/pharo-cli"

# Field separator for internal records whose fields may be empty (ASCII unit
# separator; a tab would not do because `read` merges consecutive tabs).
PHARO_CLI_SEP=$(printf '\037')

# Prints an informational message on stdout.
info() {
    printf '%s\n' "$*"
}

# Prints a warning on stderr.
warn() {
    printf '%s: warning: %s\n' "$PHARO_CLI_COMMAND_NAME" "$*" >&2
}

# Prints an error on stderr and exits with EXIT_ERROR.
die() {
    printf '%s: %s\n' "$PHARO_CLI_COMMAND_NAME" "$*" >&2
    exit "$EXIT_ERROR"
}

# Prints a usage error on stderr, points to the help, and exits with EXIT_USAGE.
# $1: message, $2: optional command name whose help is suggested.
usage_error() {
    printf '%s: %s\n' "$PHARO_CLI_COMMAND_NAME" "$1" >&2
    if [ -n "${2:-}" ]; then
        printf "Run '%s help %s' for usage.\n" "$PHARO_CLI_COMMAND_NAME" "$2" >&2
    else
        printf "Run '%s help' for usage.\n" "$PHARO_CLI_COMMAND_NAME" >&2
    fi
    exit "$EXIT_USAGE"
}

# Prints a prompt on stderr (so stdout stays clean for scripts) and reads one
# line from stdin into the variable named $2. Fails when stdin is closed.
prompt() {
    printf '%s ' "$1" >&2
    IFS= read -r "$2"
}

# Asks a yes/no question. Succeeds only on an explicit y or yes.
confirm() {
    local answer=""
    prompt "$1 [y/N]" answer || return 1
    case "$answer" in
        y | Y | yes | YES | Yes) return 0 ;;
        *) return 1 ;;
    esac
}

# Expands a leading ~ to $HOME.
expand_home() {
    case "$1" in
        "~") printf '%s\n' "$HOME" ;;
        \~/*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# Lowercases its argument (Bash 3.2 has no ${var,,}).
to_lower() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

# Succeeds when $1 is a non-empty string of digits.
is_number() {
    case "$1" in
        '' | *[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Succeeds when the command $1 is available on PATH.
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# The version of pharo-cli, read from the VERSION file at the project root.
pharo_cli_version() {
    local version
    IFS= read -r version <"$PHARO_CLI_ROOT/VERSION"
    printf '%s\n' "$version"
}
