#!/usr/bin/env bats
# Choosing an image interactively: fzf or a numbered menu.

load helpers/common

setup() {
    sandbox_setup
    create_image First
    set_image_metadata First "lastOpened=2000"
    create_image Second
    set_image_metadata Second "lastOpened=1000"
}

@test "auto uses fzf when it is installed and passes the images most recent first" {
    export FAKE_FZF_CHOICE=Second
    run_lib 'pick_image Open'
    assert_success
    assert_output Second
    run cat "$FAKE_LOG/fzf.input"
    assert_output "First
Second"
    run cat "$FAKE_LOG/fzf.log"
    assert_output --partial "--prompt Open > "
}

@test "auto uses a numbered menu without fzf" {
    uninstall_fake fzf
    run env PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; os_load; printf "2\n" | pick_image Open 2>"$FAKE_LOG/menu"'
    assert_success
    assert_output Second
    run cat "$FAKE_LOG/menu"
    assert_line --index 0 "1) First"
    assert_line --index 1 "2) Second"
    assert_line --index 2 --partial "Open (number):"
}

@test "picker=select uses the menu even with fzf installed" {
    write_config "picker=select"
    run env PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; os_load; printf "1\n" | pick_image Open 2>/dev/null'
    assert_output First
    [ ! -e "$FAKE_LOG/fzf.log" ]
}

@test "the menu asks again after an invalid choice" {
    write_config "picker=select"
    run env PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; os_load; printf "9\n1\n" | pick_image Open 2>"$FAKE_LOG/menu"'
    assert_success
    assert_output First
    run cat "$FAKE_LOG/menu"
    assert_output --partial "Please enter a number between 1 and 2."
}

@test "the menu is cancelled when the input ends" {
    write_config "picker=select"
    run env PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; os_load; pick_image Open </dev/null'
    assert_failure 1
    assert_output --partial "Operation cancelled."
}

@test "the menu handles names with spaces and glob characters" {
    write_config "picker=select"
    create_image "My *"
    set_image_metadata "My *" "lastOpened=3000"
    run env PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; os_load; printf "1\n" | pick_image Open 2>/dev/null'
    assert_output "My *"
}

@test "cancelling fzf exits 1" {
    run_lib 'pick_image Open'
    assert_failure 1
    assert_output --partial "Operation cancelled."
}

@test "picker=fzf without fzf installed is an error" {
    uninstall_fake fzf
    write_config "picker=fzf"
    run_lib 'pick_image Open'
    assert_failure
    assert_output --partial "picker is set to fzf, but fzf is not installed"
}

@test "with no images there is nothing to choose" {
    rm -rf "$IMAGES_DIR"
    run_lib 'pick_image Open'
    assert_failure
    assert_output --partial "no images in $IMAGES_DIR. Create one with 'pharo new'"
}
