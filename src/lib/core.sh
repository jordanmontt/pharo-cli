#!/usr/bin/env bash
# Core helpers shared by every part of pharo-cli: messages, errors, exit codes
# and small string utilities. Everything here is Bash 3.2 compatible.

# Globals used by the other files.
# shellcheck disable=SC2034

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1     # a command failed or the user cancelled
readonly EXIT_USAGE=2     # the command line was wrong, or a question needs a terminal
readonly EXIT_NOT_FOUND=3 # no such image, script or import source
readonly EXIT_DOWNLOAD=4  # a download failed
readonly EXIT_VM=5        # the VM could not be started
readonly EXIT_TIMEOUT=124 # 'pharo run --timeout' stopped the VM (as timeout(1))

PHARO_CLI_COMMAND_NAME="pharo"
PHARO_CLI_PROGRAM_NAME="pharo-cli"
PHARO_CLI_REPOSITORY="jordanmontt/pharo-cli"

# Field separator for internal records whose fields may be empty (ASCII unit
# separator; a tab would not do because `read` merges consecutive tabs).
PHARO_CLI_SEP=$(printf '\037')

# True when --quiet was given: info prints nothing.
PHARO_CLI_QUIET=false

# Makes info print nothing, for --quiet.
info_be_quiet() {
    PHARO_CLI_QUIET=true
}

# Prints an informational message on stderr, so stdout carries only results
# (names, paths, JSON). Nothing is printed with --quiet.
info() {
    [ "$PHARO_CLI_QUIET" = true ] && return 0
    printf '%s\n' "$*" >&2
}

# Prints a warning on stderr.
warn() {
    printf '%s: warning: %s\n' "$PHARO_CLI_COMMAND_NAME" "$*" >&2
}

# Prints an error on stderr and exits with EXIT_ERROR.
die() {
    die_with "$EXIT_ERROR" "$*"
}

# Prints the error $2 on stderr and exits with the status $1.
die_with() {
    printf '%s: %s\n' "$PHARO_CLI_COMMAND_NAME" "$2" >&2
    exit "$1"
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

# Succeeds when stderr is a terminal. PHARO_CLI_TEST_TTY, set by the tests
# only, makes it succeed without one.
stderr_is_terminal() {
    [ -n "${PHARO_CLI_TEST_TTY:-}" ] || [ -t 2 ]
}

# Succeeds when a person can answer a question: stdin and stderr (where
# prompts and the picker are drawn) are both terminals. Agents and scripts
# have neither.
has_terminal() {
    [ -n "${PHARO_CLI_TEST_TTY:-}" ] || { [ -t 0 ] && [ -t 2 ]; }
}

# Exits with EXIT_USAGE and the message $1 unless a person can answer a
# question, so that nothing waits for an answer that never comes.
require_terminal() {
    has_terminal || die_with "$EXIT_USAGE" "$1"
}

# Prints a prompt on stderr (so stdout stays clean for scripts) and reads one
# line from stdin into the variable named $2. Fails when stdin is closed.
prompt() {
    printf '%s ' "$1" >&2
    IFS= read -r "$2"
}

# Asks a yes/no question. Succeeds only on an explicit y or yes. Without a
# terminal, exits with EXIT_USAGE: the command needs --yes.
confirm() {
    local answer=""
    require_terminal "cannot ask \"$1\" without a terminal; pass --yes"
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

# The physical path of the existing file or folder $1, with symlinked
# folders resolved (on macOS, /var is /private/var). A relative $1 is taken
# from the folder $2, or from the current folder.
physical_path() {
    local path="$1" dir
    case "$path" in
        /*) ;;
        *) path="${2:-.}/$path" ;;
    esac
    dir=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) || return 1
    printf '%s/%s\n' "$dir" "$(basename "$path")"
}

# Formats $1, seconds since the epoch, as "YYYY-MM-DD HH:MM". GNU date (Linux,
# or coreutils first in PATH on macOS) takes -d @secs, BSD date takes -r secs;
# the installed date decides, not the OS.
format_date() {
    date -d "@$1" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$1" '+%Y-%m-%d %H:%M'
}

# Formats $1, seconds since the epoch, as ISO 8601 in UTC, for JSON:
# 2026-11-27T14:05:09Z.
format_iso_date() {
    date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -r "$1" '+%Y-%m-%dT%H:%M:%SZ'
}

# The version of pharo-cli, read from the VERSION file at the project root.
pharo_cli_version() {
    local version
    IFS= read -r version <"$PHARO_CLI_ROOT/VERSION"
    printf '%s\n' "$version"
}
