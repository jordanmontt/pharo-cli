#!/usr/bin/env bash
# Creating an image folder from a zip (a template download or an import).
# The zip is unpacked into a staging folder inside imagesDir, so the final
# move is a rename on the same disk, and the staging folder is removed on exit
# whatever happens.

CREATE_STAGING=""

create_cleanup() {
    [ -n "$CREATE_STAGING" ] && rm -rf "$CREATE_STAGING"
    CREATE_STAGING=""
}

# Makes a fresh staging folder in CREATE_STAGING. Call it directly, not in a
# command substitution, so the variable and the cleanup trap stay set.
create_staging() {
    local dir
    dir=$(images_dir)
    mkdir -p "$dir" || die "cannot create the images folder $dir"
    CREATE_STAGING="$dir/.pharo-cli-staging.$$"
    rm -rf "$CREATE_STAGING"
    mkdir "$CREATE_STAGING" || die "cannot create $CREATE_STAGING"
    trap create_cleanup EXIT
}

# Prints the folder holding the .image file inside the unpacked folder $1
# (zips may have the files at the top or inside one folder).
create_image_folder() {
    local file
    file=$(find "$1" -maxdepth 2 -name '*.image' -type f | sort | sed -n 1p)
    [ -n "$file" ] || return 1
    dirname "$file"
}

# Unzips the zip file $1 into a staging folder and prints the folder that
# holds the image. Dies when the zip has no image.
create_unpack() {
    local staging folder
    staging="$CREATE_STAGING"
    unzip -q "$1" -d "$staging/content" || die "could not unzip $1"
    folder=$(create_image_folder "$staging/content") || die "no .image file in $1"
    printf '%s\n' "$folder"
}

# Moves the unpacked folder $1 into imagesDir as the image named $2 and
# records its origin $3 in the metadata.
create_install() {
    local folder="$1" name="$2" origin="$3" target
    image_require_free "$name"
    target=$(image_path "$name")
    mv "$folder" "$target" || die "could not create $target"
    image_meta_set "$target" origin "$origin"
    image_meta_set "$target" created "$(date +%s)"
}
