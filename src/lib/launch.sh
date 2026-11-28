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

# Opens the image named $1. $2 is foreground or background; $3 is ui, or
# headless to run it without its UI (a server, for example): the VM gets
# --headless. The image always gets --interactive, which keeps it running
# after startup; without it, an image started with no command prints its
# command-line help and quits. The remaining arguments go to the VM, after
# the vmArgs setting. In the background, the process id is printed on stdout.
launch_open() {
    local name="$1" mode="$2" display="$3" dir vm image
    shift 3
    dir=$(image_path "$name")
    launch_ensure_vm "$dir"
    vm=$(vm_binary "$dir")
    launch_require_vm "$vm"
    image=$(basename "$(image_file "$dir")")
    LAUNCH_VM_ARGS=()
    [ "$display" = headless ] && LAUNCH_VM_ARGS=(--headless)
    launch_configured_vm_args
    image_meta_set "$dir" lastOpened "$(date +%s)"
    cd "$dir" || die "cannot enter $dir"
    if [ "$mode" = background ]; then
        nohup "$vm" ${LAUNCH_VM_ARGS[@]+"${LAUNCH_VM_ARGS[@]}"} "$@" "$image" --interactive >pharo-cli.log 2>&1 </dev/null &
        info "Opened '$name' in the background (process $!). VM output goes to $dir/pharo-cli.log"
        printf '%s\n' "$!"
    else
        info "Opening '$name'..."
        shopt -s execfail
        exec "$vm" ${LAUNCH_VM_ARGS[@]+"${LAUNCH_VM_ARGS[@]}"} "$@" "$image" --interactive
        die_with "$EXIT_VM" "could not start the VM $vm"
    fi
}

# Runs the image in the folder $1 headless with the image arguments in
# $4... (a command-line handler such as eval or st). $3 is the number of VM
# arguments that come first in $4... The exit status is the VM's.
# $2 is a time limit in seconds, 0 for none; with "" the VM replaces this
# process (exec), otherwise pharo-cli waits for it, so that the caller's exit
# trap still runs (to remove a temporary image) and the limit can be applied.
launch_headless() {
    local dir="$1" timeout="$2" vm_count="$3" vm image
    shift 3
    launch_ensure_vm "$dir"
    vm=$(vm_binary "$dir")
    launch_require_vm "$vm"
    image=$(basename "$(image_file "$dir")")
    LAUNCH_VM_ARGS=(--headless)
    launch_configured_vm_args
    while [ "$vm_count" -gt 0 ]; do
        LAUNCH_VM_ARGS[${#LAUNCH_VM_ARGS[@]}]="$1"
        shift
        vm_count=$((vm_count - 1))
    done
    cd "$dir" || die "cannot enter $dir"
    if [ -z "$timeout" ]; then
        shopt -s execfail
        exec "$vm" "${LAUNCH_VM_ARGS[@]}" "$image" "$@"
        die_with "$EXIT_VM" "could not start the VM $vm"
    fi
    launch_supervised "$timeout" "$vm" "${LAUNCH_VM_ARGS[@]}" "$image" "$@"
}

# Exits with EXIT_VM unless the VM $1 can be run.
launch_require_vm() {
    [ -x "$1" ] || die_with "$EXIT_VM" "the VM $1 is missing or cannot be run"
}

# Runs the command $2... and exits with its status. When it is still running
# after $1 seconds (0: no limit), it gets TERM, then KILL 5 seconds later,
# and pharo-cli exits with EXIT_TIMEOUT. An interrupt (Ctrl-C) or TERM sent
# to pharo-cli is passed on to the command as TERM: background commands of a
# script ignore Ctrl-C.
launch_supervised() {
    local timeout="$1" marker watchdog="" status
    shift
    marker=$(mktemp "${TMPDIR:-/tmp}/pharo-cli-timeout.XXXXXX") || die "cannot create a temporary file"
    rm -f "$marker"
    "$@" &
    LAUNCH_PID=$!
    trap 'kill -TERM "$LAUNCH_PID" 2>/dev/null' INT TERM
    if [ "$timeout" -gt 0 ]; then
        launch_watchdog "$timeout" "$LAUNCH_PID" "$marker" &
        watchdog=$!
    fi
    # wait returns early when a trap runs; wait again until the VM is gone.
    while :; do
        wait "$LAUNCH_PID"
        status=$?
        kill -0 "$LAUNCH_PID" 2>/dev/null || break
    done
    trap - INT TERM
    if [ -n "$watchdog" ]; then
        kill -TERM "$watchdog" 2>/dev/null
        wait "$watchdog" 2>/dev/null
    fi
    if [ -e "$marker" ]; then
        rm -f "$marker"
        die_with "$EXIT_TIMEOUT" "timed out after ${timeout}s"
    fi
    case "$status" in
        126 | 127) die_with "$EXIT_VM" "could not start the VM $1" ;;
    esac
    exit "$status"
}

# Waits $1 seconds, then, if the process $2 is still running, creates the
# file $3 and stops the process: TERM, then KILL 5 seconds later. Stopping
# the watchdog (TERM) stops its sleep too, so nothing is left running.
launch_watchdog() {
    local sleeper=""
    trap 'kill "$sleeper" 2>/dev/null; exit 0' TERM
    sleep "$1" &
    sleeper=$!
    wait "$sleeper"
    kill -0 "$2" 2>/dev/null || exit 0
    : >"$3"
    kill -TERM "$2" 2>/dev/null
    sleep 5 &
    sleeper=$!
    wait "$sleeper"
    kill -KILL "$2" 2>/dev/null
    exit 0
}
