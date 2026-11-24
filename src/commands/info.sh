#!/usr/bin/env bash
# @command info
# @alias i
# @summary Show details about an image.
# @arg [image:image] The image. Without it, you choose one from a list.

cmd_info() {
    local name="" count=0 dir image version format value
    while [ $# -gt 0 ]; do
        common_option info "$1" || {
            count=$((count + 1))
            name="$1"
        }
        shift
    done
    check_argument_count info 1 "$count"
    [ -n "$name" ] || name=$(pick_image "Show") || exit "$EXIT_ERROR"
    image_require "$name"
    dir=$(image_path "$name")
    image=$(image_file "$dir")
    {
        printf 'Name\t%s\n' "$name"
        printf 'Folder\t%s\n' "$dir"
        printf 'Image file\t%s\n' "$(basename "$image")"
        if version=$(image_pharo_version "$dir"); then
            printf 'Pharo version\t%s\n' "$(image_version_label "$version")"
        else
            printf 'Pharo version\tunknown (no pharo.version file)\n'
        fi
        format=$(image_format "$image")
        printf 'Image format\t%s\n' "$(info_format_label "$format")"
        if vm_present "$dir"; then
            printf 'VM\t%s\n' "$(vm_binary "$dir")"
        else
            printf "VM\tnone yet (downloaded when the image is opened)\n"
        fi
        value=$(image_meta_get "$dir" origin) || value="unknown"
        printf 'Template\t%s\n' "$value"
        if value=$(image_meta_get "$dir" created); then
            printf 'Created\t%s\n' "$(format_date "$value")"
        else
            printf 'Created\tunknown\n'
        fi
        if value=$(image_meta_get "$dir" lastOpened); then
            printf 'Last opened\t%s\n' "$(format_date "$value")"
        else
            printf 'Last opened\tnever\n'
        fi
        printf 'Size\t%s\n' "$(du -sh "$dir" | cut -f 1 | tr -d ' ')"
    } | awk -F '\t' '{ printf "%-15s%s\n", $1 ":", $2 }'
}

# Describes the image format number $1.
info_format_label() {
    case "$1" in
        68021) echo "68021 (64-bit)" ;;
        6521) echo "6521 (32-bit)" ;;
        6505) echo "6505 (32-bit, before Spur)" ;;
        '') echo "unknown" ;;
        *) echo "$1" ;;
    esac
}
