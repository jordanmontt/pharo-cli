#!/usr/bin/env bash
# @command list
# @alias l
# @alias ls
# @summary List the images, most recently opened or created first.
# @option -q --quiet Print only the image names, one per line.
# @option --json Print a JSON array with one object per image, with the fields of 'pharo info --json' except size_bytes.
# @example pharo list -q | Print only the names, for scripts.

cmd_list() {
    local quiet=false json=false names name dir version last
    while [ $# -gt 0 ]; do
        case "$1" in
            -q | --quiet) quiet=true ;;
            --json) json=true ;;
            *)
                common_option list "$1" || check_argument_count list 0 1
                ;;
        esac
        shift
    done
    if [ "$quiet" = true ] && [ "$json" = true ]; then
        usage_error "give either --quiet or --json, not both" list
    fi
    names=$(images_list)
    if [ "$json" = true ]; then
        [ -z "$names" ] || while IFS= read -r name; do
            info_json "$name" false
        done <<NAMES | json_array
$names
NAMES
        [ -n "$names" ] || echo "[]"
        return "$EXIT_OK"
    fi
    if [ -z "$names" ]; then
        [ "$quiet" = true ] && return "$EXIT_OK"
        info "No images in $(images_dir). Create one with '$PHARO_CLI_COMMAND_NAME new'."
        return "$EXIT_OK"
    fi
    if [ "$quiet" = true ]; then
        printf '%s\n' "$names"
        return "$EXIT_OK"
    fi
    {
        printf 'NAME\tPHARO\tLAST OPENED\n'
        while IFS= read -r name; do
            dir=$(image_path "$name")
            if version=$(image_pharo_version "$dir"); then
                version=$(image_version_label "$version")
            else
                version="?"
            fi
            last=$(image_meta_get "$dir" lastOpened) && last=$(format_date "$last") || last="never opened"
            printf '%s\t%s\t%s\n' "$name" "$version" "$last"
        done <<NAMES
$names
NAMES
    } | list_columns
}

# Aligns tab separated columns (column(1) is not installed everywhere).
list_columns() {
    awk -F '\t' '
        { for (i = 1; i <= NF; i++) { cell[NR, i] = $i; if (length($i) > width[i]) width[i] = length($i) } if (NF > columns) columns = NF }
        END {
            for (row = 1; row <= NR; row++) {
                line = ""
                for (i = 1; i <= columns; i++) line = line (i < columns ? sprintf("%-" width[i] + 2 "s", cell[row, i]) : cell[row, i])
                print line
            }
        }'
}
