#!/usr/bin/env bash
# @command path
# @alias p
# @summary Print the folder of an image, or the images folder.
# @arg [image:image] The image. Without it, the folder that holds all images is printed.
# @example cd "$(pharo path MyImage)" | Go to the folder of MyImage.

cmd_path() {
    local name="" count=0
    while [ $# -gt 0 ]; do
        common_option path "$1" || {
            count=$((count + 1))
            name="$1"
        }
        shift
    done
    check_argument_count path 1 "$count"
    if [ -z "$name" ]; then
        images_dir
        return "$EXIT_OK"
    fi
    image_require "$name"
    image_path "$name"
}
