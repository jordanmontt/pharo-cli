#!/usr/bin/env bash
# Running an image's VM, in the foreground, in the background, or headless to
# run a script.

# Adds the vmArgs setting, split on spaces, to the array LAUNCH_VM_ARGS.
launch_configured_vm_args() {
    local configured word
    configured=$(config_get vmArgs)
    set -f
    for word in $configured; do
        LAUNCH_VM_ARGS[${#LAUNCH_VM_ARGS[@]}]="$word"
    done
    set +f
}

# Makes sure the image folder $1 has a VM, downloading it when needed.
launch_ensure_vm() {
    vm_present "$1" && return 0
    info "The image '$(basename "$1")' has no VM yet."
    vm_install "$1"
}

# Opens the image named $1 with its UI. $2 is foreground or background. The
# remaining arguments go to the VM, after the vmArgs setting.
launch_open() {
    local name="$1" mode="$2" dir vm image
    shift 2
    dir=$(image_path "$name")
    launch_ensure_vm "$dir"
    vm=$(vm_binary "$dir")
    image=$(basename "$(image_file "$dir")")
    LAUNCH_VM_ARGS=()
    launch_configured_vm_args
    image_meta_set "$dir" lastOpened "$(date +%s)"
    cd "$dir" || die "cannot enter $dir"
    if [ "$mode" = background ]; then
        nohup "$vm" ${LAUNCH_VM_ARGS[@]+"${LAUNCH_VM_ARGS[@]}"} "$@" "$image" --interactive >pharo-cli.log 2>&1 </dev/null &
        info "Opened '$name' in the background (process $!). VM output goes to $dir/pharo-cli.log"
    else
        info "Opening '$name'..."
        exec "$vm" ${LAUNCH_VM_ARGS[@]+"${LAUNCH_VM_ARGS[@]}"} "$@" "$image" --interactive
    fi
}

# Runs the image named $1 headless with the image arguments in $3...
# (a command-line handler such as eval or st). $2 is the number of VM
# arguments that come first in $3... The exit status is the VM's.
launch_headless() {
    local name="$1" vm_count="$2" dir vm image
    shift 2
    dir=$(image_path "$name")
    launch_ensure_vm "$dir" >&2
    vm=$(vm_binary "$dir")
    image=$(basename "$(image_file "$dir")")
    LAUNCH_VM_ARGS=(--headless)
    launch_configured_vm_args
    while [ "$vm_count" -gt 0 ]; do
        LAUNCH_VM_ARGS[${#LAUNCH_VM_ARGS[@]}]="$1"
        shift
        vm_count=$((vm_count - 1))
    done
    cd "$dir" || die "cannot enter $dir"
    exec "$vm" "${LAUNCH_VM_ARGS[@]}" "$image" "$@"
}
