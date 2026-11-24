#!/usr/bin/env bash
# @command templates
# @alias t
# @summary List the templates that 'pharo new' can use.
# @description Besides these ids, 'pharo new' accepts stable, latest, and a Pharo version such as 14. The list comes from Pharo Launcher's template list and is cached (see the templatesUrl and templatesCacheTtl settings).
# @arg [filter:none] Show only the templates whose id or name contains this text (case does not matter).
# @option --refresh Download the template list again instead of using the cached copy.
# @example pharo templates moose | List the templates whose id or name contains moose.

cmd_templates() {
    local filter="" refresh=false count=0 rows
    while [ $# -gt 0 ]; do
        case "$1" in
            --refresh) refresh=true ;;
            *)
                common_option templates "$1" || {
                    count=$((count + 1))
                    filter="$1"
                }
                ;;
        esac
        shift
    done
    check_argument_count templates 1 "$count"
    if [ "$refresh" = true ]; then
        templates_refresh || die "could not download the template list from $(config_get templatesUrl)"
    fi
    rows=$(templates_list | awk -F "$PHARO_CLI_SEP" -v filter="$(to_lower "$filter")" '
        filter == "" || index(tolower($1), filter) || index(tolower($2), filter) { print $1 "\t" $2 }')
    if [ -z "$rows" ]; then
        info "No template matches '$filter'."
        return "$EXIT_ERROR"
    fi
    { printf 'ID\tNAME\n'; printf '%s\n' "$rows"; } | list_columns
}
