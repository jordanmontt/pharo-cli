#!/usr/bin/env bash
# @command info
# @alias i
# @summary Show details about an image.
# @arg [image:image] The image. Without it, you choose one from a list.
# @option --json Print the details as a JSON object: name, folder, image_file, pharo_version, image_format, vm_path, template, template_url, created, last_opened (ISO 8601, UTC) and size_bytes. Unknown values are null.
# @example pharo info MyImage --json | Print the details of MyImage for a program.

cmd_info() {
    local name="" count=0 json=false dir image version format value
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) json=true ;;
            *)
                common_option info "$1" || {
                    count=$((count + 1))
                    name="$1"
                }
                ;;
        esac
        shift
    done
    check_argument_count info 1 "$count"
    [ -n "$name" ] || name=$(pick_image "Show") || exit
    image_require "$name"
    dir=$(image_path "$name")
    if [ "$json" = true ]; then
        info_json "$name" true
        return "$EXIT_OK"
    fi
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

# Prints the details of the image named $1 as a JSON object, with its size
# when $2 is true (du takes a while on many images).
info_json() {
    local name="$1" dir image version="" format="" vm="" value
    dir=$(image_path "$name")
    image=$(image_file "$dir")
    version=$(image_pharo_version "$dir") && version=$(image_version_label "$version")
    format=$(image_format "$image")
    is_number "$format" || format=""
    vm_present "$dir" && vm=$(vm_binary "$dir")
    {
        json_field name string "$name"
        json_field folder string "$dir"
        json_field image_file string "$(basename "$image")"
        json_field pharo_version string "$version"
        json_field image_format number "$format"
        json_field vm_path string "$vm"
        json_field template string "$(image_meta_get "$dir" origin)"
        json_field template_url string "$(image_meta_get "$dir" templateUrl)"
        json_field created string "$(json_date "$(image_meta_get "$dir" created)")"
        json_field last_opened string "$(json_date "$(image_meta_get "$dir" lastOpened)")"
        if [ "$2" = true ]; then
            value=$(du -sk "$dir" | cut -f 1 | tr -d ' ')
            json_field size_bytes number "$((value * 1024))"
        fi
    } | json_object
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
