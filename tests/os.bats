#!/usr/bin/env bats
# The OS dispatcher: platform names, VM paths, trash and dates on macOS and
# Linux.

load helpers/common

setup() { sandbox_setup; }

@test "macOS: platform, CPU, legacy name and VM path" {
    export FAKE_OS=Darwin FAKE_ARCH=arm64
    run_lib 'os_vm_platform; os_vm_arch; os_legacy_vm_platform; os_vm_binary'
    assert_output "Darwin
arm64
mac
Pharo.app/Contents/MacOS/Pharo"
    export FAKE_ARCH=x86_64
    run_lib 'os_vm_arch'
    assert_output x86_64
}

@test "Linux: platform, CPU, legacy name and VM path" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    run_lib 'os_vm_platform; os_vm_arch; os_legacy_vm_platform; os_vm_binary'
    assert_output "Linux
x86_64
linux
pharo"
}

@test "Linux on ARM is called aarch64 in VM URLs, whatever uname says" {
    export FAKE_OS=Linux FAKE_ARCH=aarch64
    run_lib 'os_vm_arch'
    assert_output aarch64
    export FAKE_ARCH=arm64
    run_lib 'os_vm_arch'
    assert_output aarch64
}

@test "an unsupported CPU is reported" {
    export FAKE_OS=Darwin FAKE_ARCH=ppc
    run_lib 'os_vm_arch'
    assert_failure
    assert_output --partial "unsupported CPU architecture: ppc"
    export FAKE_OS=Linux FAKE_ARCH=riscv64
    run_lib 'os_vm_arch'
    assert_output --partial "unsupported CPU architecture: riscv64"
}

@test "macOS uses the trash command when there is one" {
    mkdir -p "$SANDBOX/doomed folder"
    run_lib "os_has_trash && os_trash '$SANDBOX/doomed folder'"
    assert_success
    [ -d "$FAKE_TRASH/doomed folder" ]
    [ ! -e "$SANDBOX/doomed folder" ]
}

@test "macOS falls back to the Finder without the trash command" {
    uninstall_fake trash
    mkdir -p "$SANDBOX/a \"quoted\" folder"
    run_lib "os_has_trash && os_trash '$SANDBOX/a \"quoted\" folder'"
    assert_success
    run cat "$FAKE_LOG/osascript.log"
    assert_output "-e tell application \"Finder\" to delete POSIX file \"$SANDBOX/a \\\"quoted\\\" folder\""
}

@test "Linux uses gio first" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    mkdir -p "$SANDBOX/doomed"
    run_lib "os_has_trash && os_trash '$SANDBOX/doomed'"
    assert_success
    run cat "$FAKE_LOG/trash.log"
    assert_output "gio trash -- $SANDBOX/doomed"
}

@test "Linux uses trash-put without gio" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    uninstall_fake gio
    mkdir -p "$SANDBOX/doomed"
    run_lib "os_has_trash && os_trash '$SANDBOX/doomed'"
    assert_success
    run cat "$FAKE_LOG/trash.log"
    assert_output "trash-put -- $SANDBOX/doomed"
}

@test "Linux without gio and trash-cli has no trash" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    uninstall_fake gio trash-put
    run_lib 'os_has_trash'
    assert_failure
}

@test "dates are formatted on both systems" {
    # GNU and BSD date differ; only the one matching this machine can run.
    if date -r 0 >/dev/null 2>&1; then
        export FAKE_OS=Darwin
    else
        export FAKE_OS=Linux FAKE_ARCH=x86_64
    fi
    run env TZ=UTC PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; os_load; os_format_date 1764000000'
    assert_success
    assert_output "2025-11-24 16:00"
}
