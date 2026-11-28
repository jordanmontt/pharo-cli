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
    assert_failure 3
}

@test "without a name and without a terminal it fails at once instead of waiting" {
    run_pharo_without_terminal info
    assert_failure 2
    assert_output "pharo: no image given, and no terminal to choose one"
}

@test "--json prints the details as one JSON object" {
    create_image Json
    set_image_metadata Json "origin=14" "templateUrl=https://files.pharo.org/image/140/latest-64.zip" "created=0"
    run_in_sandbox /bin/bash -c '"$1" info Json --json 2>/dev/null' _ "$PHARO_BIN"
    assert_success
    assert_output --regexp '^\{"name":"Json",.*\}$'
    assert_json '[.name, .folder, .image_file, .pharo_version, .image_format, .vm_path, .template, .template_url, .created, .last_opened, (.size_bytes > 0)]' \
        "[\"Json\",\"$IMAGES_DIR/Json\",\"Json.image\",\"14\",68021,\"$IMAGES_DIR/Json/pharo-vm/Pharo.app/Contents/MacOS/Pharo\",\"14\",\"https://files.pharo.org/image/140/latest-64.zip\",\"1970-01-01T00:00:00Z\",null,true]"
}

@test "--json gives null for what is not known" {
    create_image Bare --no-vm --no-version
    run_pharo info Bare --json
    assert_success
    assert_json '[.pharo_version, .vm_path, .template, .created, .last_opened]' '[null,null,null,null,null]'
}
