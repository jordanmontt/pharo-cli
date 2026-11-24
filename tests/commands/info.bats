#!/usr/bin/env bats
# pharo info

load ../helpers/common

setup() { sandbox_setup; }

@test "shows version, format, VM, origin, dates and size" {
    create_image Img
    set_image_metadata Img "origin=stable" "created=1764000000" "lastOpened=1764003600"
    run_pharo info Img
    assert_success
    assert_line "Name:          Img"
    assert_line "Folder:        $IMAGES_DIR/Img"
    assert_line "Image file:    Img.image"
    assert_line "Pharo version: 14"
    assert_line "Image format:  68021 (64-bit)"
    assert_line "VM:            $IMAGES_DIR/Img/pharo-vm/Pharo.app/Contents/MacOS/Pharo"
    assert_line "Template:      stable"
    assert_line --regexp '^Created:       2025-11-2[45] [0-9]{2}:[0-9]{2}$'
    assert_line --regexp '^Last opened:   2025-11-2[45] [0-9]{2}:[0-9]{2}$'
    assert_line --regexp '^Size: +[0-9.,]+[BKMG]?$'
}

@test "shows what is unknown or missing" {
    create_image Bare --no-vm --no-version
    run_pharo info Bare
    assert_success
    assert_line "Pharo version: unknown (no pharo.version file)"
    assert_line "VM:            none yet (downloaded when the image is opened)"
    assert_line "Template:      unknown"
    assert_line "Created:       unknown"
    assert_line "Last opened:   never"
}

@test "describes the known image formats" {
    run_lib '. "$PHARO_CLI_ROOT/src/commands/info.sh"; info_format_label 6521; info_format_label 6505; info_format_label 12345; info_format_label ""'
    assert_output "6521 (32-bit)
6505 (32-bit, before Spur)
12345
unknown"
}

@test "without a name it uses the picker" {
    create_image Img
    export FAKE_FZF_CHOICE=Img
    run_pharo info
    assert_success
    assert_line "Name:          Img"
}

@test "an unknown image is an error" {
    run_pharo info Nope
    assert_failure 1
}
