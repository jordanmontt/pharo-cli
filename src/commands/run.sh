#!/usr/bin/env bash
# @command run
# @alias r
# @summary Run a Smalltalk script or expression in an image, without its UI.
# @description The VM runs headless in this terminal and its exit status is passed on. The image is not saved.
# @arg <image:image> The image to run.
# @arg [script:file] A .st file to run. It is given to the image's st command-line handler.
# @option -e --eval <expression:none> Evaluate an expression and print its result, instead of running a script.
# @option --vm-arg <arg:vm-arg> Pass one argument to the VM. Repeat it to pass several.
# @example pharo run MyImage --eval '3 + 4' | Print 7.
# @example pharo run MyImage build.st | Run the script build.st in MyImage, then quit.

cmd_run() {
    local name="" script="" expression="" has_expression=false count=0
    local -a vm_args
    vm_args=()
    while [ $# -gt 0 ]; do
        case "$1" in
            -e | --eval)
                [ $# -ge 2 ] || usage_error "$1 needs a value" run
                expression="$2"
                has_expression=true
                shift
                ;;
            --eval=*)
                expression="${1#--eval=}"
                has_expression=true
                ;;
            --vm-arg)
                [ $# -ge 2 ] || usage_error "--vm-arg needs a value" run
                vm_args[${#vm_args[@]}]="$2"
                shift
                ;;
            --vm-arg=*) vm_args[${#vm_args[@]}]="${1#--vm-arg=}" ;;
            *)
                common_option run "$1" || {
                    count=$((count + 1))
                    case "$count" in
                        1) name="$1" ;;
                        2) script="$1" ;;
                    esac
                }
                ;;
        esac
        shift
    done
    check_argument_count run 2 "$count"
    [ -n "$name" ] || usage_error "'run' needs an image" run
    if [ "$has_expression" = true ] && [ -n "$script" ]; then
        usage_error "give either a script or --eval, not both" run
    fi
    if [ "$has_expression" = false ] && [ -z "$script" ]; then
        usage_error "'run' needs a script or --eval <expression>" run
    fi
    image_require "$name"
    if [ "$has_expression" = true ]; then
        launch_headless "$name" "${#vm_args[@]}" ${vm_args[@]+"${vm_args[@]}"} eval "$expression"
    fi
    [ -f "$script" ] || die "no such script: $script"
    script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
    launch_headless "$name" "${#vm_args[@]}" ${vm_args[@]+"${vm_args[@]}"} st --quit "$script"
}
