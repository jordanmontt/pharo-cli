#!/usr/bin/env bash
# @command templates
# @alias t
# @summary List the templates that 'pharo new' can use.
# @description Besides these ids, 'pharo new' accepts stable, latest, and a Pharo version such as 14. The list comes from Pharo Launcher's template list and is cached (see the templatesUrl and templatesCacheTtl settings).
# @arg [filter:none] Show only the templates whose id or name contains this text (case does not matter).
# @option --refresh Download the template list again instead of using the cached copy.
# @option --json Print a JSON array with one object per template: id, name and url.
# @example pharo templates moose | List the templates whose id or name contains moose.

cmd_templates() {
    local filter="" refresh=false json=false count=0 rows id name url
    while [ $# -gt 0 ]; do
        case "$1" in
            --refresh) refresh=true ;;
            --json) json=true ;;
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
        templates_refresh || die_with "$EXIT_DOWNLOAD" "could not download the template list from $(config_get templatesUrl)"
    fi
    rows=$(templates_list | awk -F "$PHARO_CLI_SEP" -v filter="$(to_lower "$filter")" '
        filter == "" || index(tolower($1), filter) || index(tolower($2), filter)')
    if [ "$json" = true ]; then
        [ -z "$rows" ] || while IFS="$PHARO_CLI_SEP" read -r id name url; do
            { json_field id string "$id"; json_field name string "$name"; json_field url string "$url"; } | json_object
        done <<ROWS | json_array
$rows
ROWS
        [ -n "$rows" ] || echo "[]"
    fi
    if [ -z "$rows" ]; then
        info "No template matches '$filter'."
        return "$EXIT_ERROR"
    fi
    [ "$json" = true ] && return "$EXIT_OK"
    printf '%s\n' "$rows" | awk -F "$PHARO_CLI_SEP" 'BEGIN { print "ID\tNAME" } { print $1 "\t" $2 }' | list_columns
}
