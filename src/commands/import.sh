#!/usr/bin/env bash
# @command import
# @alias im
# @summary Add an existing image from a folder, a zip file or a zip URL.
# @description A folder is copied, not moved. The image keeps its file names. When the image has no VM and has a pharo.version file, its VM is downloaded.
# @arg <source:file> A folder or .zip file containing a .image file, or the http(s) URL of such a zip.
# @arg [name:none] The name of the image. Without it, the folder or zip name is used.
# @example pharo import ~/Downloads/MyProject | Copy the image in ~/Downloads/MyProject into the images folder.
# @example pharo import ~/Downloads/moose.zip Moose | Add the image in moose.zip as Moose.
# @example pharo import https://example.org/image.zip | Download and add the image in a zip.

cmd_import() {
    local source="" name="" count=0 folder target
    while [ $# -gt 0 ]; do
        common_option import "$1" || {
            count=$((count + 1))
            case "$count" in
                1) source="$1" ;;
                2) name="$1" ;;
            esac
        }
        shift
    done
    check_argument_count import 2 "$count"
    [ -n "$source" ] || usage_error "'import' needs a folder, zip file or URL" import
    if [ -z "$name" ]; then
        name=$(basename "${source%/}")
        name="${name%.zip}"
    fi
    image_require_free "$name"
    create_staging
    case "$source" in
        http://* | https://*)
            info "Downloading $source"
            http_download "$source" "$CREATE_STAGING/import.zip" || die "could not download $source"
            folder=$(create_unpack "$CREATE_STAGING/import.zip") || exit "$EXIT_ERROR"
            ;;
        *.zip)
            [ -f "$source" ] || die "no such file: $source"
            folder=$(create_unpack "$source") || exit "$EXIT_ERROR"
            ;;
        *)
            [ -d "$source" ] || die "no such folder or zip file: $source"
            image_dir_valid "$source" || die "no .image file in $source"
            cp -Rp "$source" "$CREATE_STAGING/content" || die "could not copy $source"
            folder="$CREATE_STAGING/content"
            ;;
    esac
    create_install "$folder" "$name" "import of $source"
    create_cleanup
    target=$(image_path "$name")
    info "Imported '$name' into $target"
    vm_present "$target" && return "$EXIT_OK"
    if image_pharo_version "$target" >/dev/null; then
        vm_install "$target"
    else
        warn "'$name' has no VM and no pharo.version file, so no VM can be chosen for it. Add a pharo.version file (e.g. containing 140) and open it."
    fi
}
