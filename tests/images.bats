#!/usr/bin/env bats
# Images: what counts as one, names, ordering, files and metadata.

load helpers/common

setup() { sandbox_setup; }

@test "only folders with a .image file are images" {
    create_image Real
    mkdir -p "$IMAGES_DIR/EmptyFolder"
    touch "$IMAGES_DIR/stray-file.txt"
    mkdir -p "$IMAGES_DIR/OnlyChanges" && touch "$IMAGES_DIR/OnlyChanges/x.changes"
    run_lib 'images_list'
    assert_output Real
}

@test "no images folder means no images" {
    run_lib 'images_list'
    assert_success
    assert_output ""
}

@test "images are ordered by last use, then created, then folder age" {
    create_image NeverUsedOld
    touch -t 202001010000 "$IMAGES_DIR/NeverUsedOld"
    create_image NeverUsedNew
    create_image OpenedLongAgo
    set_image_metadata OpenedLongAgo "lastOpened=1000"
    create_image OpenedRecently
    set_image_metadata OpenedRecently "lastOpened=3000"
    create_image CreatedOnly
    set_image_metadata CreatedOnly "created=2000"
    run_lib 'images_list'
    assert_output "OpenedRecently
CreatedOnly
OpenedLongAgo
NeverUsedNew
NeverUsedOld"
}

@test "names with spaces and glob characters are listed as they are" {
    create_image "My Image"
    create_image "star*"
    run_lib 'images_list | sort'
    assert_output "My Image
star*"
}

@test "image names are checked" {
    local bad
    for bad in "" "." ".." "a/b" "-x" ".hidden"; do
        run_lib "image_check_name '$bad'"
        assert_failure
    done
    run_lib "image_check_name 'Fine name-1.2' && echo ok"
    assert_output ok
}

@test "image_require_free refuses a taken name" {
    create_image Taken
    run_lib 'image_require_free Taken'
    assert_failure
    assert_output --partial "an image named 'Taken' already exists"
}

@test "the .image named like the folder is preferred, otherwise the first one" {
    create_image Img
    fake_image_file "$IMAGES_DIR/Img/AAA.image"
    run_lib "basename \"\$(image_file '$IMAGES_DIR/Img')\""
    assert_output Img.image
    create_image Other --file Pharo14.0-SNAPSHOT
    run_lib "basename \"\$(image_file '$IMAGES_DIR/Other')\""
    assert_output Pharo14.0-SNAPSHOT.image
}

@test "the Pharo version comes from pharo.version" {
    create_image Img --version 130
    run_lib "image_pharo_version '$IMAGES_DIR/Img'"
    assert_output 130
    create_image NoVersion --no-version
    run_lib "image_pharo_version '$IMAGES_DIR/NoVersion'"
    assert_failure
    create_image Garbage
    echo "garbage" >"$IMAGES_DIR/Garbage/pharo.version"
    run_lib "image_pharo_version '$IMAGES_DIR/Garbage'"
    assert_failure
}

@test "readable version labels" {
    run_lib 'image_version_label 140; image_version_label 90; image_version_label 61; image_version_label 100'
    assert_output "14
9.0
6.1
10"
}

@test "the image format is read from the first 4 bytes" {
    create_image Img
    run_lib "image_format '$IMAGES_DIR/Img/Img.image'"
    assert_output 68021
}

@test "metadata can be set, replaced, read and removed" {
    create_image Img
    run_lib "d='$IMAGES_DIR/Img'; image_meta_set \"\$d\" a 1; image_meta_set \"\$d\" b 2; image_meta_set \"\$d\" a 3; image_meta_get \"\$d\" a; image_meta_get \"\$d\" b; image_meta_unset \"\$d\" a; image_meta_get \"\$d\" a || echo gone"
    assert_output "3
2
gone"
}

@test "renaming image files touches only files carrying the old name" {
    create_image Img
    fake_image_file "$IMAGES_DIR/Img/Other.image"
    run_lib "image_rename_files '$IMAGES_DIR/Img' Img New"
    run ls "$IMAGES_DIR/Img"
    assert_output "New.changes
New.image
Other.image
pharo-vm
pharo.version"
}
