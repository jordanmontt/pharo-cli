#!/usr/bin/env bats
# pharo remove: to the trash, or deleted for good after confirming.

load ../helpers/common

setup() {
    sandbox_setup
    create_image Doomed
}

@test "moves the image to the trash without asking" {
    run_pharo remove Doomed
    assert_success
    assert_output "Moved 'Doomed' to the trash."
    [ ! -e "$IMAGES_DIR/Doomed" ]
    [ -f "$FAKE_TRASH/Doomed/Doomed.image" ]
}

@test "rm is remove" {
    run_pharo rm Doomed
    assert_success
    assert_output "Moved 'Doomed' to the trash."
}

@test "macOS without the trash command uses the Finder" {
    uninstall_fake trash
    run_pharo remove Doomed
    assert_success
    assert_output "Moved 'Doomed' to the trash."
    run cat "$FAKE_LOG/osascript.log"
    assert_output --partial "delete POSIX file \"$IMAGES_DIR/Doomed\""
}

@test "Linux uses gio" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    run_pharo remove Doomed
    assert_success
    assert_output "Moved 'Doomed' to the trash."
    run cat "$FAKE_LOG/trash.log"
    assert_output "gio trash -- $IMAGES_DIR/Doomed"
}

@test "without a trash it asks, then deletes for good" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    uninstall_fake gio trash-put
    run_pharo_with_input "y
" remove Doomed
    assert_success
    assert_output --partial "this system has no trash"
    assert_output --partial "Permanently delete 'Doomed'? [y/N]"
    assert_output --partial "Permanently deleted 'Doomed'."
    [ ! -e "$IMAGES_DIR/Doomed" ]
}

@test "without a trash, any answer but yes keeps the image" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    uninstall_fake gio trash-put
    run_pharo_with_input "n
" remove Doomed
    assert_failure 1
    assert_output --partial "Cancelled. 'Doomed' was not deleted."
    [ -d "$IMAGES_DIR/Doomed" ]
    run_pharo_with_input "" remove Doomed
    assert_failure 1
    [ -d "$IMAGES_DIR/Doomed" ]
}

@test "--yes and -y skip the question" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    uninstall_fake gio trash-put
    run_pharo remove Doomed --yes
    assert_success
    assert_output --partial "Permanently deleted 'Doomed'."
    refute_output --partial "[y/N]"
    create_image Other
    run_pharo remove -y Other
    assert_success
}

@test "a failing trash is reported and the image is kept" {
    printf '#!/usr/bin/env bash\nexit 1\n' >"$FAKE_BIN/trash"
    run_pharo remove Doomed
    assert_failure 1
    assert_output --partial "could not move 'Doomed' to the trash"
    [ -d "$IMAGES_DIR/Doomed" ]
}

@test "without a name it uses the picker" {
    export FAKE_FZF_CHOICE=Doomed
    run_pharo remove
    assert_success
    assert_output --partial "Moved 'Doomed' to the trash."
}

@test "an unknown image is an error" {
    run_pharo remove Nope
    assert_failure 3
    assert_output --partial "no image named 'Nope'"
}

@test "without a name and without a terminal it fails at once instead of waiting" {
    run_pharo_without_terminal remove
    assert_failure 2
    assert_output "pharo: no image given, and no terminal to choose one"
}

@test "without a trash and without a terminal it needs --yes" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    uninstall_fake gio trash-put
    run_pharo_without_terminal remove Doomed
    assert_failure 2
    assert_output --partial "cannot ask \"Permanently delete 'Doomed'?\" without a terminal; pass --yes"
    [ -d "$IMAGES_DIR/Doomed" ]
}
