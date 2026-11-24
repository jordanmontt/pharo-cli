#!/usr/bin/env bats
# Completion: the candidates from 'pharo __complete', and the Bash and zsh
# completion functions that use them.

load helpers/common

setup() {
    sandbox_setup
    create_image image
    create_image other
    create_image "with space"
}

# Prints the candidates for completing the last word of the arguments.
complete_line() {
    run_pharo __complete "$#" pharo "$@"
}

@test "command names, with an empty or partial word" {
    complete_line ""
    assert_success
    assert_line open
    assert_line self-update
    refute_line o
    complete_line re
    assert_output "remove
rename"
}

@test "global options" {
    complete_line --
    assert_output "--help
--version"
}

@test "image names after open, also through its alias" {
    complete_line open i
    assert_output image
    complete_line o ""
    assert_line image
    assert_line other
    assert_line "with space"
}

@test "image names for every command taking an image" {
    local command
    for command in open info path rename duplicate remove run; do
        complete_line "$command" ot
        assert_output other
    done
}

@test "a typed backslash-escaped space still matches" {
    complete_line open 'with\ s'
    assert_output "with space"
}

@test "only the first argument of rename is an image" {
    complete_line rename image ""
    assert_output ""
}

@test "options of a command" {
    complete_line open --
    assert_output "--background
--foreground
--vm-arg
--help"
    complete_line new --no
    assert_output "--no-open"
}

@test "VM options after --vm-arg" {
    complete_line open image --vm-arg --log
    assert_output "--logLevel="
    complete_line run image --vm-arg --head
    assert_output "--headless"
}

@test "an option value does not count as a positional argument" {
    complete_line open --vm-arg --headless i
    assert_output image
}

@test "templates for new: keywords plus the cached ids, without downloading" {
    complete_line new ""
    assert_output "stable
latest"
    run curl_requests
    assert_output ""
    serve_catalogue
    run_pharo templates
    complete_line new pharo-14
    assert_output "pharo-14.0-64bit-stable"
    complete_line new --template lat
    assert_output "latest"
}

@test "help completes command names" {
    complete_line help ren
    assert_output rename
}

@test "config completes actions, keys and values" {
    complete_line config ""
    assert_output "list
get
set
unset
reset"
    complete_line config set image
    assert_output imagesDir
    complete_line config get vm
    assert_output "vmStatus
vmArgs"
    complete_line config set openMode ""
    assert_output "foreground
background"
    complete_line config set autoOpenOnNew t
    assert_output true
    complete_line config list ""
    assert_output ""
}

@test "files for import and run scripts" {
    complete_line import ""
    assert_output "__files__"
    complete_line run image ""
    assert_output "__files__"
}

@test "nothing for an unknown command" {
    complete_line frobnicate ""
    assert_success
    assert_output ""
}

# Runs the Bash completion function for the command line $1 (the cursor at
# its end) and prints COMPREPLY, one entry per line.
bash_complete() {
    mkdir -p "$SANDBOX/bin"
    ln -sf "$PHARO_BIN" "$SANDBOX/bin/pharo"
    run env PATH="$SANDBOX/bin:$SANDBOX_PATH" /bin/bash -c '
        . "$1"
        read -r -a COMP_WORDS <<<"$2"
        case "$2" in *" ") COMP_WORDS[${#COMP_WORDS[@]}]="" ;; esac
        COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
        _pharo_cli_complete
        printf "%s\n" "${COMPREPLY[@]}"' _ "$PROJECT_ROOT/completions/pharo.bash" "$1"
}

@test "bash: pharo o i<TAB> completes the image name" {
    bash_complete "pharo o i"
    assert_success
    assert_output image
}

@test "bash: names with spaces are escaped" {
    bash_complete "pharo open wi"
    assert_output 'with\ space'
}

@test "bash: file names for import" {
    mkdir -p "$SANDBOX/zips"
    touch "$SANDBOX/zips/one.zip"
    bash_complete "pharo import $SANDBOX/zips/o"
    assert_output "$SANDBOX/zips/one.zip"
}

@test "bash: the completion is registered for pharo" {
    run /bin/bash -c '. "$1"; complete -p pharo' _ "$PROJECT_ROOT/completions/pharo.bash"
    assert_output "complete -F _pharo_cli_complete pharo"
}

@test "zsh: the Bash completion works through bashcompinit" {
    command -v zsh >/dev/null || skip "zsh is not installed"
    mkdir -p "$SANDBOX/bin"
    ln -sf "$PHARO_BIN" "$SANDBOX/bin/pharo"
    run env PATH="$SANDBOX/bin:$SANDBOX_PATH" "$(command -v zsh)" -f -c '
        autoload -U compinit && compinit -u -D
        autoload -U +X bashcompinit && bashcompinit
        source "$1"
        COMP_WORDS=(pharo open "")
        COMP_CWORD=2
        _pharo_cli_complete
        print -rl -- "${COMPREPLY[@]}"' _ "$PROJECT_ROOT/completions/pharo.bash"
    assert_success
    assert_line image
    assert_line other
    assert_line 'with\ space'
}
