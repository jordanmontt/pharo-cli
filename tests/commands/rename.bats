#!/usr/bin/env bats
# pharo rename

load ../helpers/common

setup() { sandbox_setup; }

@test "renames the folder and the image files carrying the old name" {
    create_image Old
    run_pharo rename Old New
    assert_success
    assert_output "Renamed 'Old' to 'New'."
    [ ! -e "$IMAGES_DIR/Old" ]
    [ -f "$IMAGES_DIR/New/New.image" ]
    [ -f "$IMAGES_DIR/New/New.changes" ]
}

@test "image files with another name keep it" {
    create_image Old --file Pharo14.0-SNAPSHOT
    run_pharo rename Old New
    assert_success
    [ -f "$IMAGES_DIR/New/Pharo14.0-SNAPSHOT.image" ]
}

@test "names with spaces work" {
    create_image "Old one"
    run_pharo rename "Old one" "New one"
    assert_success
    [ -f "$IMAGES_DIR/New one/New one.image" ]
}

@test "refuses a name that is taken" {
    create_image A
    create_image B
    run_pharo rename A B
    assert_failure 1
    assert_output --partial "an image named 'B' already exists"
    [ -f "$IMAGES_DIR/A/A.image" ]
    [ -f "$IMAGES_DIR/B/B.image" ]
}

@test "refuses an invalid name" {
    create_image A
    run_pharo rename A ../escape
    assert_failure 1
    [ -d "$IMAGES_DIR/A" ]
}

@test "asks for the new name when it is not given" {
    create_image Old
    run_pharo_with_input "Asked
" rename Old
    assert_success
    assert_output --partial "New name for 'Old':"
    [ -f "$IMAGES_DIR/Asked/Asked.image" ]
}

@test "an empty answer cancels" {
    create_image Old
    run_pharo_with_input "
" rename Old
    assert_failure 1
    assert_output --partial "Operation cancelled."
    [ -d "$IMAGES_DIR/Old" ]
}

@test "without arguments it uses the picker then asks" {
    create_image Old
    export FAKE_FZF_CHOICE=Old
    run_pharo_with_input "Picked
" rename
    assert_success
    [ -d "$IMAGES_DIR/Picked" ]
}

@test "an unknown image is an error" {
    run_pharo rename Nope New
    assert_failure 3
}

@test "without a terminal, a missing name fails at once instead of waiting" {
    create_image Old
    run_pharo_without_terminal rename Old
    assert_failure 2
    assert_output "pharo: no new name given, and no terminal to ask for one"
    run_pharo_without_terminal rename
    assert_failure 2
    assert_output "pharo: no image given, and no terminal to choose one"
    [ -d "$IMAGES_DIR/Old" ]
}
