#!/usr/bin/env bash
# @command run
# @alias r
# @summary Run a script or an expression in an image, without its UI.
# @description The VM runs headless in this terminal and its exit status is passed on. The image is not saved unless --save is given.
# @description With --temporary, a fresh image is created from a template for this run only, and removed when the run ends, however it ends.
# @arg [image:image] The image to run. Not given with --temporary.
# @arg [script:file] A .st file to run. It is given to the image's st command-line handler.
# @option -e --eval <expression:none> Evaluate an expression and print its result, instead of running a script.
# @option --save Save the image after the script or expression has run.
# @option --timeout <seconds:none> Stop the VM after this many seconds and exit with status 124.
# @option --temporary <template:template> Run in a fresh image made from this template, removed afterwards.
# @option --refresh Download the template and the VM again, even when the cached copies are up to date.
# @option --vm-arg <arg:vm-arg> Pass one argument to the VM. Repeat it to pass several.
# @option -q --quiet Print nothing but errors, warnings and what the image prints.
# @example pharo run MyImage --eval '3 + 4' | Print 7.
# @example pharo run MyImage build.st | Run the script build.st in MyImage, then quit.
# @example pharo run MyImage setup.st --save | Run setup.st and keep what it changed in the image.
# @example pharo run --temporary 14 check.st --timeout 300 | Run check.st in a fresh Pharo 14 image, for at most 5 minutes.

cmd_run() {
    local name="" script="" expression="" has_expression=false count=0 first="" second=""
    local save=false timeout="" temporary="" dir
    local -a vm_args handler_options
    vm_args=()
    handler_options=()
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
            --save) save=true ;;
            --timeout)
                [ $# -ge 2 ] || usage_error "--timeout needs a value" run
                timeout="$2"
                shift
                ;;
            --timeout=*) timeout="${1#--timeout=}" ;;
            --temporary)
                [ $# -ge 2 ] || usage_error "--temporary needs a template" run
                temporary="$2"
                shift
                ;;
            --temporary=*) temporary="${1#--temporary=}" ;;
            --refresh) http_refresh_downloads ;;
            -q | --quiet) info_be_quiet ;;
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
                        1) first="$1" ;;
                        2) second="$1" ;;
                    esac
                }
                ;;
        esac
        shift
    done
    if [ -n "$temporary" ]; then
        check_argument_count run 1 "$count"
        script="$first"
        if [ "$save" = true ]; then
            usage_error "--save cannot be used with --temporary: the image is removed after the run" run
        fi
    else
        check_argument_count run 2 "$count"
        name="$first"
        script="$second"
        [ -n "$name" ] || usage_error "'run' needs an image, or --temporary <template>" run
    fi
    if [ -n "$timeout" ] && { ! is_number "$timeout" || [ "$timeout" -eq 0 ]; }; then
        usage_error "--timeout needs a whole number of seconds, more than 0" run
    fi
    if [ "$has_expression" = true ] && [ -n "$script" ]; then
        usage_error "give either a script or --eval, not both" run
    fi
    if [ "$has_expression" = false ] && [ -z "$script" ]; then
        usage_error "'run' needs a script or --eval <expression>" run
    fi
    if [ -n "$script" ]; then
        [ -f "$script" ] || die_with "$EXIT_NOT_FOUND" "no such script: $script"
        script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
    fi
    if [ -n "$temporary" ]; then
        run_create_temporary "$temporary"
        dir="$RUN_TEMPORARY_DIR"
        # No exec: the exit trap must run to remove the image.
        [ -n "$timeout" ] || timeout=0
    else
        image_require "$name"
        dir=$(image_path "$name")
    fi
    [ "$save" = true ] && handler_options=(--save)
    if [ "$has_expression" = true ]; then
        launch_headless "$dir" "$timeout" "${#vm_args[@]}" ${vm_args[@]+"${vm_args[@]}"} \
            eval ${handler_options[@]+"${handler_options[@]}"} "$expression"
    fi
    launch_headless "$dir" "$timeout" "${#vm_args[@]}" ${vm_args[@]+"${vm_args[@]}"} \
        st ${handler_options[@]+"${handler_options[@]}"} --quit "$script"
}

# The folder of the temporary image made by run_create_temporary.
RUN_TEMPORARY_DIR=""

# Creates a temporary image from the template $1, with its VM, in a folder
# under $TMPDIR that is removed when pharo-cli exits, and sets
# RUN_TEMPORARY_DIR to it. Not in a command substitution: the exit trap must
# be set in this shell.
run_create_temporary() {
    local resolved label url
    resolved=$(templates_resolve "$1") ||
        die "unknown template '$1'. Run '$PHARO_CLI_COMMAND_NAME templates' to see them"
    label="${resolved%%"$PHARO_CLI_SEP"*}"
    url="${resolved#*"$PHARO_CLI_SEP"}"
    create_temporary_staging
    info "Downloading $label: $url"
    RUN_TEMPORARY_DIR=$(create_from_template "$url") || exit
    vm_install "$RUN_TEMPORARY_DIR"
}
