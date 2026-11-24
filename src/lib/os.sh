#!/usr/bin/env bash
# OS dispatcher. Loads src/os/<os>.sh, which implements the same small
# interface for each supported system:
#
#   os_vm_platform        OS name in VM download URLs (Darwin, Linux)
#   os_vm_arch            CPU name in VM download URLs (arm64, x86_64, aarch64)
#   os_legacy_vm_platform OS name in VM URLs for Pharo 8 and older (mac, linux)
#   os_vm_binary          path of the VM executable inside an image's pharo-vm/
#   os_has_trash          succeeds when files can be moved to a trash
#   os_trash <path>       moves <path> to the trash

# Loads the implementation for the running OS.
os_load() {
    local system
    system=$(uname -s)
    case "$system" in
        Darwin) . "$PHARO_CLI_ROOT/src/os/darwin.sh" ;;
        Linux) . "$PHARO_CLI_ROOT/src/os/linux.sh" ;;
        *) die "unsupported operating system: $system (pharo-cli supports macOS and Linux)" ;;
    esac
}
