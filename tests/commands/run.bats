#!/usr/bin/env bats
# pharo run: headless scripts and expressions.

load ../helpers/common

setup() {
    sandbox_setup
    create_image Img
}

@test "--eval runs the eval handler headless and passes the exit status on" {
    run_pharo run Img --eval '3 + 4'
    assert_success
    assert_output "fake vm ran"
    run vm_last_arguments
    assert_output "--headless
Img.image
eval
3 + 4"
    export FAKE_VM_EXIT=1
    run_pharo run Img -e '1/0'
    assert_failure 1
    run_pharo run Img --eval=42
    run vm_last_arguments
    assert_line --index 3 42
}

@test "a script runs with st --quit, with its absolute path" {
    mkdir -p "$SANDBOX/work"
    echo "Transcript show: 'hi'" >"$SANDBOX/work/my script.st"
    cd "$SANDBOX/work"
    run_pharo run Img "my script.st"
    assert_success
    run vm_last_arguments
    assert_output "--headless
Img.image
st
--quit
$(cd "$SANDBOX/work" && pwd -P)/my script.st"
}

@test "VM arguments come after --headless and the vmArgs setting" {
    write_config "vmArgs=--logLevel=1"
    run_pharo run Img --vm-arg --maxFramesToLog=5 --eval 1
    run vm_last_arguments
    assert_output "--headless
--logLevel=1
--maxFramesToLog=5
Img.image
eval
1"
}

@test "the image's lastOpened is not changed" {
    run_pharo run Img --eval 1
    [ ! -e "$IMAGES_DIR/Img/.pharo-cli" ]
}

@test "a missing script is an error" {
    run_pharo run Img nope.st
    assert_failure 1
    assert_output --partial "no such script: nope.st"
}

@test "usage errors" {
    run_pharo run
    assert_failure 2
    assert_output --partial "'run' needs an image"
    run_pharo run Img
    assert_failure 2
    assert_output --partial "'run' needs a script or --eval <expression>"
    echo x >"$SANDBOX/s.st"
    run_pharo run Img "$SANDBOX/s.st" --eval 1
    assert_failure 2
    assert_output --partial "give either a script or --eval, not both"
    run_pharo run Img --eval
    assert_failure 2
}

@test "an image without a VM gets one first, with messages on stderr" {
    serve_pharo 140
    create_image NoVm --no-vm
    run_in_sandbox /bin/bash -c '"$1" run NoVm --eval 1 2>/dev/null' _ "$PHARO_BIN"
    assert_success
    assert_output "fake vm ran"
}
