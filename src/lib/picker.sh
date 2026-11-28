#!/usr/bin/env bash
# Choosing an image interactively when a command is given no image name. The
# picker setting chooses between fzf (fuzzy search) and a numbered menu
# (Bash's select); auto uses fzf when it is installed.

# The picker to use: fzf or select.
picker_kind() {
    local kind
    kind=$(config_get picker)
    case "$kind" in
        fzf)
            has_command fzf || die "picker is set to fzf, but fzf is not installed"
            echo fzf
            ;;
        select) echo select ;;
        *)
            if has_command fzf; then echo fzf; else echo select; fi
            ;;
    esac
}

# Lets the user choose one of the images and prints its name. The question
# $1 is shown as the prompt. Exits with EXIT_ERROR when cancelled, and with
# EXIT_USAGE when there is no terminal to choose in.
pick_image() {
    local names choice
    require_terminal "no image given, and no terminal to choose one"
    names=$(images_list)
    [ -n "$names" ] || die "no images in $(images_dir). Create one with '$PHARO_CLI_COMMAND_NAME new'"
    case "$(picker_kind)" in
        fzf)
            choice=$(printf '%s\n' "$names" | fzf --prompt "$1 > " --height 40% --reverse) || choice=""
            ;;
        select)
            choice=$(pick_from_menu "$1" "$names")
            ;;
    esac
    if [ -z "$choice" ]; then
        info "Operation cancelled." >&2
        exit "$EXIT_ERROR"
    fi
    printf '%s\n' "$choice"
}

# Shows the lines of $2 as a numbered menu on stderr and prints the chosen
# one. Prints nothing when the input ends first.
pick_from_menu() {
    local PS3 choice old_ifs="$IFS"
    PS3="$1 (number): "
    IFS='
'
    set -f # this runs in a subshell, so this only stops globbing here
    # shellcheck disable=SC2086 # split the names on line breaks only
    set -- $2
    IFS="$old_ifs"
    select choice in "$@"; do
        if [ -n "$choice" ]; then
            printf '%s\n' "$choice"
            return 0
        fi
        echo "Please enter a number between 1 and $#." >&2
    done
}
