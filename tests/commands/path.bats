#!/usr/bin/env bats
# pharo path

load ../helpers/common

setup() { sandbox_setup; }

@test "without a name prints the images folder" {
    run_pharo path
    assert_success
    assert_output "$IMAGES_DIR"
}

@test "with a name prints the image folder" {
    create_image "My Image"
    run_pharo path "My Image"
    assert_success
    assert_output "$IMAGES_DIR/My Image"
}

@test "an unknown image is an error" {
    run_pharo path Nope
    assert_failure 1
    assert_output --partial "no image named 'Nope'"
}
