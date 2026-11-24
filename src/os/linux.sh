#!/usr/bin/env bash
# Linux implementation of the OS interface (see src/lib/os.sh).

os_vm_platform() {
    echo Linux
}

os_vm_arch() {
    local machine
    machine=$(uname -m)
    case "$machine" in
        x86_64) echo x86_64 ;;
        aarch64 | arm64) echo aarch64 ;;
        *) die "unsupported CPU architecture: $machine" ;;
    esac
}

os_legacy_vm_platform() {
    echo linux
}

os_vm_binary() {
    echo "pharo"
}

# Linux has a trash when a desktop tool for it is installed: gio (GNOME and
# most desktops) or trash-cli.
os_has_trash() {
    has_command gio || has_command trash-put
}

os_trash() {
    if has_command gio; then
        gio trash -- "$1"
    else
        trash-put -- "$1"
    fi
}

os_format_date() {
    date -d "@$1" '+%Y-%m-%d %H:%M'
}
