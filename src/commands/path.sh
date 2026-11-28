#!/usr/bin/env bash
# @command path
# @alias p
# @summary Print the folder of an image, or the images folder.
# @arg [image:image] The image. Without it, the folder that holds all images is printed.
# @option --json Print a JSON object with the folder as path.
# @example cd "$(pharo path MyImage)" | Go to the folder of MyImage.

cmd_path() {
    local name="" count=0 json=false path
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) json=true ;;
            *)
                common_option path "$1" || {
                    count=$((count + 1))
                    name="$1"
                }
                ;;
        esac
        shift
    done
    check_argument_count path 1 "$count"
    if [ -z "$name" ]; then
        path=$(images_dir)
    else
        image_require "$name"
        path=$(image_path "$name")
    fi
    if [ "$json" = true ]; then
        json_field path string "$path" | json_object
    else
        printf '%s\n' "$path"
    fi
}
