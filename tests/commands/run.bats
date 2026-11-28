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
    assert_failure 3
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

@test "an unknown image is an error" {
    run_pharo run Nope --eval 1
    assert_failure 3
    assert_output --partial "no image named 'Nope'"
}

@test "--save makes the st and eval handlers save the image" {
    echo x >"$SANDBOX/setup.st"
    run_pharo run Img "$SANDBOX/setup.st" --save
    assert_success
    run vm_last_arguments
    assert_output "--headless
Img.image
st
--save
--quit
$SANDBOX/setup.st"
    run_pharo run Img --save --eval 1
    run vm_last_arguments
    assert_output "--headless
Img.image
eval
--save
1"
}

@test "--timeout passes the VM's status on when it ends in time" {
    export FAKE_VM_EXIT=7
    run_pharo run Img --eval 1 --timeout 10
    assert_failure 7
    assert_output "fake vm ran"
    run_pharo run Img --eval 1 --timeout=10
    assert_failure 7
}

@test "--timeout stops a VM that hangs and exits 124" {
    export FAKE_VM_SLEEP=30
    local start=$SECONDS
    run_pharo run Img --eval 1 --timeout 1
    assert_failure 124
    assert_output "fake vm ran
pharo: timed out after 1s"
    [ $((SECONDS - start)) -lt 10 ]
}

@test "--timeout kills a VM that ignores TERM, 5 seconds later" {
    export FAKE_VM_SLEEP=30 FAKE_VM_IGNORE_TERM=1
    local start=$SECONDS
    run_pharo run Img --eval 1 --timeout 1
    assert_failure 124
    assert_output --partial "pharo: timed out after 1s"
    [ $((SECONDS - start)) -ge 5 ]
    [ $((SECONDS - start)) -lt 15 ]
}

@test "--timeout must be a whole number of seconds, more than 0" {
    run_pharo run Img --eval 1 --timeout 0
    assert_failure 2
    assert_output --partial "--timeout needs a whole number of seconds, more than 0"
    run_pharo run Img --eval 1 --timeout 1.5
    assert_failure 2
    run_pharo run Img --eval 1 --timeout
    assert_failure 2
    assert_output --partial "--timeout needs a value"
}

@test "a VM that cannot start exits 5" {
    printf '\177ELF\000\000\000\000' >"$IMAGES_DIR/Img/pharo-vm/Pharo.app/Contents/MacOS/Pharo"
    run_pharo run Img --eval 1
    assert_failure 5
    assert_output --partial "pharo: could not start the VM"
    run_pharo run Img --eval 1 --timeout 10
    assert_failure 5
    assert_output --partial "pharo: could not start the VM"
}

@test "--temporary runs in a fresh image from the template and removes it" {
    serve_pharo 140
    echo x >"$SANDBOX/check.st"
    run_pharo run --temporary 14 "$SANDBOX/check.st"
    assert_success
    assert_output --partial "Downloading Pharo 14: https://files.pharo.org/image/140/latest-64.zip"
    assert_output --partial "fake vm ran"
    run vm_last_arguments
    assert_line --index 0 "--headless"
    assert_line --index 1 --regexp '^Pharo14\.0-SNAPSHOT-64bit-abc123\.image$'
    assert_line --index 2 st
    case "$(vm_last_folder)" in
        "$TMPDIR"/pharo-cli-run.*) ;;
        *) fail "the temporary image was in $(vm_last_folder)" ;;
    esac
    run ls -A "$TMPDIR"
    assert_output ""
    [ ! -e "$IMAGES_DIR/Pharo14.0-SNAPSHOT-64bit-abc123" ]
    run_pharo list -q
    assert_output "Img"
}

@test "--temporary removes the image when the script fails or times out" {
    serve_pharo 140
    export FAKE_VM_EXIT=1
    run_pharo run --temporary=14 --eval '1/0'
    assert_failure 1
    run ls -A "$TMPDIR"
    assert_output ""
    unset FAKE_VM_EXIT
    export FAKE_VM_SLEEP=30
    run_pharo run --temporary 14 --eval 1 --timeout 1
    assert_failure 124
    run ls -A "$TMPDIR"
    assert_output ""
}

@test "--temporary removes the image when pharo is stopped, and stops the VM" {
    serve_pharo 140
    export FAKE_VM_SLEEP=30
    run_in_sandbox /bin/bash -c '
        "$1" run --temporary 14 --eval 1 &
        pid=$!
        for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
            [ -s "$FAKE_LOG/vm.log" ] && break
            sleep 0.2
        done
        sleep 0.5
        kill -TERM "$pid"
        wait "$pid"
        echo "status $?"' _ "$PHARO_BIN"
    assert_line "status 143"
    run ls -A "$TMPDIR"
    assert_output ""
}

@test "--temporary uses the cached template and VM, and --refresh downloads them again" {
    serve_pharo 140
    run_pharo run --temporary 14 --eval 1
    : >"$FAKE_LOG/curl.log"
    run_pharo run --temporary 14 --eval 1
    assert_success
    run grep -c '^304 ' "$FAKE_LOG/curl.log"
    assert_output 2
    : >"$FAKE_LOG/curl.log"
    run_pharo run --temporary 14 --eval 1 --refresh
    run grep -c '^304 ' "$FAKE_LOG/curl.log"
    assert_output 0
}

@test "--temporary usage errors" {
    echo x >"$SANDBOX/s.st"
    run_pharo run --temporary 14 "$SANDBOX/s.st" --save
    assert_failure 2
    assert_output --partial "--save cannot be used with --temporary"
    run_pharo run --temporary 14 Img "$SANDBOX/s.st"
    assert_failure 2
    assert_output --partial "too many arguments for 'run'"
    run_pharo run --temporary
    assert_failure 2
    run_pharo run --temporary nope --eval 1
    assert_failure 1
    assert_output --partial "unknown template 'nope'"
}

@test "-q and --quiet leave only what the image prints" {
    serve_pharo 140
    run_pharo run --temporary 14 --eval 1 -q
    assert_success
    assert_output "fake vm ran"
    run_pharo run Img --eval 1 --quiet
    assert_output "fake vm ran"
}

@test "--timeout leaves nothing running: not the VM, not the watchdog's sleep" {
    # pharo's output goes to a file: a leftover process holding bats' output
    # pipe would make run wait for it, and hide it. The durations are used by
    # no other test, to recognise the processes.
    run_timed() {
        run_in_sandbox /bin/bash -c '"$@" >"$FAKE_LOG/out" 2>&1' _ "$PHARO_BIN" "$@"
    }
    run_timed run Img --eval 1 --timeout 47
    assert_success
    assert_no_process "sleep 47"
    export FAKE_VM_SLEEP=31
    run_timed run Img --eval 1 --timeout 1
    assert_failure 124
    assert_no_process "sleep 31"
    export FAKE_VM_SLEEP=33 FAKE_VM_IGNORE_TERM=1
    run_timed run Img --eval 1 --timeout 1
    assert_failure 124
    assert_no_process "sleep 33"
    assert_no_process "sleep 5"
}
