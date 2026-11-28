#!/usr/bin/env bats
# pharo duplicate

load ../helpers/common

setup() { sandbox_setup; }

@test "copies the image with its VM under the new name" {
    create_image Src
    set_image_metadata Src "origin=stable" "created=1" "lastOpened=2"
    echo "log" >"$IMAGES_DIR/Src/pharo-cli.log"
    run_pharo duplicate Src Copy
    assert_success
    assert_output "Duplicated 'Src' as 'Copy'."
    [ -f "$IMAGES_DIR/Copy/Copy.image" ]
    [ -f "$IMAGES_DIR/Copy/Copy.changes" ]
    [ -x "$IMAGES_DIR/Copy/pharo-vm/Pharo.app/Contents/MacOS/Pharo" ]
    [ ! -e "$IMAGES_DIR/Copy/pharo-cli.log" ]
    [ -f "$IMAGES_DIR/Src/Src.image" ]
    run cat "$IMAGES_DIR/Copy/.pharo-cli"
    assert_line "origin=duplicate of Src"
    refute_line "created=1"
    refute_line --partial "lastOpened"
}

@test "without a new name it appends -1, -2..." {
    create_image Src
    run_pharo duplicate Src
    assert_output "Duplicated 'Src' as 'Src-1'."
    run_pharo duplicate Src
    assert_output "Duplicated 'Src' as 'Src-2'."
}

@test "refuses a name that is taken instead of nesting the copy" {
    create_image Src
    create_image Taken
    run_pharo duplicate Src Taken
    assert_failure 1
    assert_output --partial "an image named 'Taken' already exists"
    [ ! -e "$IMAGES_DIR/Taken/Src" ]
}

@test "names with spaces work" {
    create_image "My Src"
    run_pharo duplicate "My Src" "My Copy"
    assert_success
    [ -f "$IMAGES_DIR/My Copy/My Copy.image" ]
}

@test "without arguments it uses the picker" {
    create_image Src
    export FAKE_FZF_CHOICE=Src
    run_pharo duplicate
    assert_output "Duplicated 'Src' as 'Src-1'."
}

@test "an unknown image is an error" {
    run_pharo duplicate Nope
    assert_failure 3
}

@test "without a name and without a terminal it fails at once instead of waiting" {
    run_pharo_without_terminal duplicate
    assert_failure 2
    assert_output "pharo: no image given, and no terminal to choose one"
}
