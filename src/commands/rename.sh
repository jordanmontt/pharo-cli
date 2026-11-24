#!/usr/bin/env bash
# @command rename
# @alias re
# @summary Rename an image.
# @description The image folder is renamed, and so are its .image and .changes files when they carry the old name.
# @arg [image:image] The image to rename. Without it, you choose one from a list.
# @arg [new-name:none] The new name. Without it, you are asked for one.
# @example pharo rename MyImage Experiments | Rename MyImage to Experiments.
# @example pharo rename | Choose an image from a list and type its new name.

cmd_rename() {
    local name="" new_name="" count=0
    while [ $# -gt 0 ]; do
        common_option rename "$1" || {
            count=$((count + 1))
            case "$count" in
                1) name="$1" ;;
                2) new_name="$1" ;;
            esac
        }
        shift
    done
    check_argument_count rename 2 "$count"
    [ -n "$name" ] || name=$(pick_image "Rename") || exit "$EXIT_ERROR"
    image_require "$name"
    if [ "$count" -lt 2 ]; then
        prompt "New name for '$name':" new_name || new_name=""
        [ -n "$new_name" ] || {
            info "Operation cancelled." >&2
            exit "$EXIT_ERROR"
        }
    fi
    image_require_free "$new_name"
    mv "$(image_path "$name")" "$(image_path "$new_name")" || die "could not rename '$name'"
    image_rename_files "$(image_path "$new_name")" "$name" "$new_name" || die "could not rename the image files of '$new_name'"
    info "Renamed '$name' to '$new_name'."
}
