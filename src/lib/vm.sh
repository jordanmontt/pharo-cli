#!/usr/bin/env bash
# VMs. Each image folder has its own VM in pharo-vm/. The VM is chosen the
# way Pharo Launcher chooses it: from the Pharo version in the image's
# pharo.version file (e.g. 140), for this OS and CPU, with the build status
# set by vmStatus. When no stable build exists for this platform (Linux on
# ARM, for example), the latest build is used instead.

# The VM executable of the image folder $1.
vm_binary() {
    printf '%s/pharo-vm/%s\n' "$1" "$(os_vm_binary)"
}

# Succeeds when the image folder $1 has a VM.
vm_present() {
    [ -x "$(vm_binary "$1")" ]
}

# The VM download URL for the Pharo version $1 (e.g. 140), build status $2
# (stable or latest) and image format $3 (68021 for 64-bit images).
vm_url() {
    local version="$1" status="$2" format="${3:-68021}" server bits
    server=$(config_get filesServer)
    if [ "$version" -ge 90 ]; then
        printf '%s/get-files/%s/pharo-vm-%s-%s-%s.zip\n' "$server" "$version" "$(os_vm_platform)" "$(os_vm_arch)" "$status"
    else
        bits=64
        [ "$format" = 6521 ] && bits=32
        printf '%s/get-files/%s/pharo%s-%s-%s.zip\n' "$server" "$version" "$bits" "$(os_legacy_vm_platform)" "$status"
    fi
}

# Downloads the URL $1 (through the download cache) and unzips it into the
# directory $2.
vm_fetch() {
    local url="$1" target="$2" zip
    zip=$(http_fetch_zip "$url" "$target.zip") || { rm -f "$target.zip"; return 1; }
    mkdir -p "$target" && unzip -q -o "$zip" -d "$target"
    local status=$?
    rm -f "$target.zip"
    return $status
}

# Downloads the VM for the image folder $1 into its pharo-vm/ folder.
vm_install() {
    local dir="$1" version status format url image
    version=$(image_pharo_version "$dir") ||
        die "cannot choose a VM for '$(basename "$dir")': it has no pharo.version file"
    status=$(config_get vmStatus)
    image=$(image_file "$dir")
    format=$(image_format "$image")
    url=$(vm_url "$version" "$status" "$format")
    info "Downloading the $status VM for Pharo $(image_version_label "$version"): $url"
    if vm_fetch "$url" "$dir/pharo-vm"; then
        return 0
    fi
    if [ "$status" = stable ]; then
        url=$(vm_url "$version" latest "$format")
        warn "no stable VM for this platform; trying the latest build: $url"
        vm_fetch "$url" "$dir/pharo-vm" && return 0
    fi
    rm -rf "$dir/pharo-vm"
    die_with "$EXIT_DOWNLOAD" "could not download a VM for Pharo $version"
}
