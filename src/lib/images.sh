#!/usr/bin/env bash
# Images. An image is a folder in imagesDir that contains a .image file; its
# name is the folder name. Besides the image files and pharo-vm/, the folder
# holds a .pharo-cli file with metadata (key=value lines: template,
# templateUrl, created, lastOpened, all times in seconds since the epoch).

readonly IMAGE_METADATA_FILE=".pharo-cli"

images_dir() {
    config_get imagesDir
}

# The folder of the image named $1.
image_path() {
    printf '%s/%s\n' "$(images_dir)" "$1"
}

# Succeeds when the folder $1 holds an image.
image_dir_valid() {
    local file
    [ -d "$1" ] || return 1
    for file in "$1"/*.image; do
        [ -f "$file" ] && return 0
    done
    return 1
}

# Succeeds when an image named $1 exists.
image_exists() {
    [ -n "$1" ] && image_dir_valid "$(image_path "$1")"
}

# Checks that $1 can be used as an image name, and dies otherwise.
image_check_name() {
    case "$1" in
        '') die "the image name cannot be empty" ;;
        . | ..) die "'$1' cannot be used as an image name" ;;
        */*) die "image names cannot contain '/': $1" ;;
        -*) die "image names cannot start with '-': $1" ;;
        .*) die "image names cannot start with '.': $1" ;;
    esac
    case "$1" in
        *"
"*) die "image names cannot contain line breaks" ;;
    esac
}

# Dies unless the image named $1 exists.
image_require() {
    image_exists "$1" || die "no image named '$1' in $(images_dir)"
}

# Dies when the folder for the image named $1 is already taken.
image_require_free() {
    image_check_name "$1"
    [ -e "$(image_path "$1")" ] && die "an image named '$1' already exists"
    return 0
}

# The .image file of the image folder $1: the one named like the folder when
# there is one, otherwise the first one.
image_file() {
    local dir="$1" file
    if [ -f "$dir/$(basename "$dir").image" ]; then
        printf '%s\n' "$dir/$(basename "$dir").image"
        return 0
    fi
    for file in "$dir"/*.image; do
        [ -f "$file" ] && { printf '%s\n' "$file"; return 0; }
    done
    return 1
}

# The Pharo version (e.g. 140) of the image folder $1, from pharo.version.
image_pharo_version() {
    local version
    [ -f "$1/pharo.version" ] || return 1
    version=$(tr -d '[:space:]' <"$1/pharo.version")
    is_number "$version" || return 1
    printf '%s\n' "$version"
}

# The image format number stored in the first 4 bytes of the image file $1
# (68021 is 64-bit Spur, 6521 32-bit Spur). Every supported CPU is little
# endian, which is what od reads.
image_format() {
    od -An -tu4 -N4 "$1" 2>/dev/null | tr -d '[:space:]'
}

# Prints the metadata value for the key $2 of the image folder $1.
image_meta_get() {
    [ -f "$1/$IMAGE_METADATA_FILE" ] || return 1
    awk -v key="$2" '
        index($0, "=") > 0 && substr($0, 1, index($0, "=") - 1) == key { value = substr($0, index($0, "=") + 1); found = 1 }
        END { if (found) print value; else exit 1 }
    ' "$1/$IMAGE_METADATA_FILE"
}

# Removes the metadata key $2 of the image folder $1.
image_meta_unset() {
    local file="$1/$IMAGE_METADATA_FILE" tmp
    [ -f "$file" ] || return 0
    tmp="$file.tmp.$$"
    awk -v key="$2" 'index($0, "=") == 0 || substr($0, 1, index($0, "=") - 1) != key' "$file" >"$tmp" &&
        mv "$tmp" "$file"
}

# Stores the metadata value $3 for the key $2 of the image folder $1.
image_meta_set() {
    image_meta_unset "$1" "$2" || return 1
    printf '%s=%s\n' "$2" "$3" >>"$1/$IMAGE_METADATA_FILE"
}

# When the image folder $1 was last used: last opened, else created, else 0.
image_last_used() {
    image_meta_get "$1" lastOpened || image_meta_get "$1" created || echo 0
}

# Lists image names, most recently used first. Images that pharo-cli never
# opened follow, newest folder first.
images_list() {
    local dir name index=0
    dir=$(images_dir)
    [ -d "$dir" ] || return 0
    # ls -t orders by modification time on every system, unlike stat.
    # shellcheck disable=SC2012
    ls -t "$dir" | while IFS= read -r name; do
        image_dir_valid "$dir/$name" || continue
        index=$((index + 1))
        printf '%s\t%s\t%s\n' "$(image_last_used "$dir/$name")" "$index" "$name"
    done | sort -t "$(printf '\t')" -k1,1nr -k2,2n | cut -f 3-
}

# Renames the image files of the folder $1 from the base name $2 to $3. Only
# files named exactly <$2>.image and <$2>.changes are renamed.
image_rename_files() {
    local dir="$1" from="$2" to="$3" extension
    for extension in image changes; do
        if [ -f "$dir/$from.$extension" ]; then
            mv "$dir/$from.$extension" "$dir/$to.$extension" || return 1
        fi
    done
}

# A readable Pharo version for the pharo.version value $1: 140 -> 14,
# 90 -> 9.0, 61 -> 6.1.
image_version_label() {
    local version="$1"
    if [ "$version" -ge 100 ] && [ $((version % 10)) -eq 0 ]; then
        printf '%s\n' $((version / 10))
    else
        printf '%s.%s\n' $((version / 10)) $((version % 10))
    fi
}
