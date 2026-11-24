#!/usr/bin/env bash
# @command remove
# @alias rm
# @summary Move an image to the trash.
# @description When the system has no trash (Linux without gio or trash-cli), the image is deleted for good, after you confirm.
# @arg [image:image] The image to remove. Without it, you choose one from a list.
# @option -y --yes Do not ask before deleting for good.
# @example pharo remove MyImage | Move MyImage to the trash.
# @example pharo rm | Choose an image from a list and move it to the trash.

cmd_remove() {
    local name="" yes=false count=0 dir
    while [ $# -gt 0 ]; do
        case "$1" in
            -y | --yes) yes=true ;;
            *)
                common_option remove "$1" || {
                    count=$((count + 1))
                    name="$1"
                }
                ;;
        esac
        shift
    done
    check_argument_count remove 1 "$count"
    [ -n "$name" ] || name=$(pick_image "Remove") || exit "$EXIT_ERROR"
    image_require "$name"
    dir=$(image_path "$name")
    if os_has_trash; then
        os_trash "$dir" || die "could not move '$name' to the trash"
        info "Moved '$name' to the trash."
        return "$EXIT_OK"
    fi
    if [ "$yes" != true ]; then
        warn "this system has no trash"
        confirm "Permanently delete '$name'?" || {
            info "Cancelled. '$name' was not deleted."
            exit "$EXIT_ERROR"
        }
    fi
    rm -rf "$dir" || die "could not delete '$name'"
    info "Permanently deleted '$name'."
}
