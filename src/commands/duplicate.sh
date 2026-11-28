#!/usr/bin/env bash
# @command duplicate
# @alias d
# @summary Copy an image, with its VM, under a new name.
# @arg [image:image] The image to copy. Without it, you choose one from a list.
# @arg [new-name:none] The name of the copy. Without it, the copy is called <image>-1 (or -2, -3... when taken).
# @example pharo duplicate MyImage | Copy MyImage as MyImage-1.

cmd_duplicate() {
    local name="" new_name="" count=0 counter=1 target
    while [ $# -gt 0 ]; do
        common_option duplicate "$1" || {
            count=$((count + 1))
            case "$count" in
                1) name="$1" ;;
                2) new_name="$1" ;;
            esac
        }
        shift
    done
    check_argument_count duplicate 2 "$count"
    [ -n "$name" ] || name=$(pick_image "Duplicate") || exit
    image_require "$name"
    if [ -z "$new_name" ]; then
        while [ -e "$(image_path "$name-$counter")" ]; do
            counter=$((counter + 1))
        done
        new_name="$name-$counter"
    fi
    image_require_free "$new_name"
    target=$(image_path "$new_name")
    cp -Rp "$(image_path "$name")" "$target" || die "could not copy '$name'"
    rm -f "$target/pharo-cli.log"
    image_rename_files "$target" "$name" "$new_name" || die "could not rename the image files of '$new_name'"
    image_meta_set "$target" origin "duplicate of $name"
    image_meta_set "$target" created "$(date +%s)"
    image_meta_unset "$target" lastOpened
    info "Duplicated '$name' as '$new_name'."
}
