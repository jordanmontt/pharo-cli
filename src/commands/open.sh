#!/usr/bin/env bash
# @command open
# @alias o
# @summary Open an image with its VM.
# @description The VM runs in this terminal unless --background is given or the openMode setting is background. An image without a VM gets one downloaded first.
# @description In the background, the VM's process id is printed on stdout.
# @arg [image:image] The image to open. Without it, you choose one from a list.
# @option -b --background Run the VM in the background; its output goes to <image>/pharo-cli.log.
# @option -f --foreground Run the VM in this terminal (the default, see the openMode setting).
# @option --headless Run the image without its UI, for example a server started by the image.
# @option -q --quiet Print nothing but errors, warnings and the process id.
# @option --vm-arg <arg:vm-arg> Pass one argument to the VM. Repeat it to pass several.
# @example pharo open | Choose an image from a list and open it.
# @example pharo open MyImage --background | Open MyImage and get the terminal back.
# @example pharo open MyImage --vm-arg --logLevel=4 | Pass an argument to the VM.
# @example pharo open MyServer --headless --background | Start an image without its UI and get the terminal back.

cmd_open() {
    local name="" mode display=ui count=0
    local -a vm_args
    vm_args=()
    mode=$(config_get openMode)
    while [ $# -gt 0 ]; do
        case "$1" in
            -b | --background) mode=background ;;
            -f | --foreground) mode=foreground ;;
            --headless) display=headless ;;
            -q | --quiet) info_be_quiet ;;
            --vm-arg)
                [ $# -ge 2 ] || usage_error "--vm-arg needs a value" open
                vm_args[${#vm_args[@]}]="$2"
                shift
                ;;
            --vm-arg=*) vm_args[${#vm_args[@]}]="${1#--vm-arg=}" ;;
            *)
                common_option open "$1" || {
                    count=$((count + 1))
                    name="$1"
                }
                ;;
        esac
        shift
    done
    check_argument_count open 1 "$count"
    [ -n "$name" ] || name=$(pick_image "Open") || exit
    image_require "$name"
    launch_open "$name" "$mode" "$display" ${vm_args[@]+"${vm_args[@]}"}
}
