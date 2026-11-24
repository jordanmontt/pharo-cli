#!/usr/bin/env bash
# macOS implementation of the OS interface (see src/lib/os.sh).

os_vm_platform() {
    echo Darwin
}

os_vm_arch() {
    local machine
    machine=$(uname -m)
    case "$machine" in
        arm64 | x86_64) echo "$machine" ;;
        *) die "unsupported CPU architecture: $machine" ;;
    esac
}

os_legacy_vm_platform() {
    echo mac
}

os_vm_binary() {
    echo "Pharo.app/Contents/MacOS/Pharo"
}

# macOS always has a trash: the trash command (built in since macOS 15) or,
# on older systems, the Finder.
os_has_trash() {
    return 0
}

os_trash() {
    if has_command trash; then
        trash "$1"
    else
        local escaped
        escaped=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
        osascript -e "tell application \"Finder\" to delete POSIX file \"$escaped\"" >/dev/null
    fi
}
