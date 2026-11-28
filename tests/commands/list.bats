#!/usr/bin/env bats
# pharo list

load ../helpers/common

setup() { sandbox_setup; }

@test "with no images it says how to create one" {
    run_pharo list
    assert_success
    assert_output "No images in $IMAGES_DIR. Create one with 'pharo new'."
    run_pharo list --quiet
    assert_success
    assert_output ""
}

@test "lists images in columns, most recently opened or created first" {
    create_image Old --version 130
    set_image_metadata Old "lastOpened=1000"
    create_image New
    set_image_metadata New "lastOpened=2000"
    create_image Unknown --no-version
    run_pharo list
    assert_success
    assert_line --index 0 --regexp '^NAME +PHARO +LAST OPENED$'
    assert_line --index 1 --regexp '^New +14 +[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$'
    assert_line --index 2 --regexp '^Old +13 +[0-9]{4}-'
    assert_line --index 3 --regexp '^Unknown +\? +never opened$'
}

@test "--quiet and -q print only names" {
    create_image "With Space"
    create_image Plain
    set_image_metadata Plain "lastOpened=1"
    run_pharo list -q
    assert_output "Plain
With Space"
    run_pharo list --quiet
    assert_output "Plain
With Space"
}

@test "list takes no arguments" {
    run_pharo list extra
    assert_failure 2
}

@test "--json prints a JSON array, most recent first, without sizes" {
    run_pharo list --json
    assert_success
    assert_output "[]"
    create_image Old
    set_image_metadata Old "lastOpened=1000"
    create_image "New one"
    set_image_metadata "New one" "lastOpened=2000"
    run_in_sandbox /bin/bash -c '"$1" list --json 2>/dev/null' _ "$PHARO_BIN"
    assert_success
    assert_json '[.[] | [.name, .last_opened, has("size_bytes")]]' '[["New one","1970-01-01T00:33:20Z",false],["Old","1970-01-01T00:16:40Z",false]]'
}

@test "--quiet and --json together are a usage error" {
    run_pharo list -q --json
    assert_failure 2
    assert_output --partial "give either --quiet or --json, not both"
}
