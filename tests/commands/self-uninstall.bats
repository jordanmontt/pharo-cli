#!/usr/bin/env bats
# pharo self-uninstall, on copies installed with install.sh from a local
# origin. It never runs on the project itself.

load ../helpers/common

setup() {
    sandbox_setup
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    ORIGIN="$SANDBOX/origin"
    mkdir -p "$ORIGIN"
    cp -R "$PROJECT_ROOT/bin" "$PROJECT_ROOT/src" "$PROJECT_ROOT/completions" "$PROJECT_ROOT/docs" "$PROJECT_ROOT/VERSION" "$PROJECT_ROOT/.gitignore" "$ORIGIN/"
    git -C "$ORIGIN" init -q -b main
    git -C "$ORIGIN" add -A
    git -C "$ORIGIN" commit -q -m release
    printf '%s\n' "# mine" "alias ll='ls -l'" >"$HOME/.zshrc"
}

install_pharo_cli() {
    run_in_sandbox SHELL=/bin/zsh PHARO_CLI_GIT_URL="$ORIGIN" "$@" /bin/bash "$PROJECT_ROOT/install.sh"
    assert_success
}

# Runs the installed pharo with the text $1 on stdin.
run_installed_with_input() {
    local input="$1"
    shift
    run_in_sandbox /bin/bash -c 'printf "%s" "$1" | "$2" "${@:3}"' _ "$input" "$HOME/.local/bin/pharo" "$@"
}

@test "removes the folder, the links, the startup block and the cache, and keeps images and settings" {
    install_pharo_cli
    create_image Img
    write_config "openMode=background"
    mkdir -p "$HOME/.cache/pharo-cli" && echo x >"$HOME/.cache/pharo-cli/sources.list"
    run_in_sandbox "$HOME/.local/bin/pharo" self-uninstall --yes
    assert_success
    assert_output "Removed the pharo-cli block from $HOME/.zshrc.
Removed pharo-cli. Your images are still in $IMAGES_DIR.
Your settings are still in $HOME/.config/pharo-cli/config.
Open a new terminal to update your PATH."
    [ ! -e "$HOME/.pharo-cli" ]
    [ ! -L "$HOME/.local/bin/pharo" ]
    [ ! -L "$HOME/.local/share/man/man1/pharo.1" ]
    [ ! -e "$HOME/.cache/pharo-cli" ]
    [ -d "$IMAGES_DIR/Img" ]
    [ -f "$HOME/.config/pharo-cli/config" ]
    run cat "$HOME/.zshrc"
    assert_output "# mine
alias ll='ls -l'"
}

@test "it asks first, and any answer but yes keeps everything" {
    install_pharo_cli
    run_installed_with_input "n
" self-uninstall
    assert_failure 1
    assert_output --partial "This removes pharo-cli from $(cd "$HOME/.pharo-cli" && pwd -P), the pharo command and its man page."
    assert_output --partial "Your images in $IMAGES_DIR and your settings are kept."
    assert_output --partial "Cancelled. pharo-cli was not removed."
    [ -f "$HOME/.pharo-cli/bin/pharo" ]
    [ -L "$HOME/.local/bin/pharo" ]
    grep -qxF "# >>> pharo-cli >>>" "$HOME/.zshrc"
}

@test "-y skips the question, and yes removes it" {
    install_pharo_cli
    run_installed_with_input "y
" self-uninstall
    assert_success
    [ ! -e "$HOME/.pharo-cli" ]
    install_pharo_cli
    run_in_sandbox "$HOME/.local/bin/pharo" self-uninstall -y
    assert_success
    refute_output --partial "Remove pharo-cli?"
    [ ! -e "$HOME/.pharo-cli" ]
}

@test "custom locations from the installer are cleaned" {
    install_pharo_cli PHARO_CLI_BIN_DIR="$SANDBOX/bin" PHARO_CLI_MAN_DIR="$SANDBOX/man" PHARO_CLI_RC_FILE="$SANDBOX/rc"
    run_in_sandbox "$SANDBOX/bin/pharo" self-uninstall -y
    assert_success
    [ ! -e "$HOME/.pharo-cli" ]
    [ ! -L "$SANDBOX/bin/pharo" ]
    [ ! -L "$SANDBOX/man/pharo.1" ]
    run grep -c pharo-cli "$SANDBOX/rc"
    assert_output 0
}

@test "a 2.0 install, without .installed, is cleaned at the default locations" {
    install_pharo_cli
    rm "$HOME/.pharo-cli/.installed"
    run_in_sandbox "$HOME/.local/bin/pharo" self-uninstall -y
    assert_success
    [ ! -e "$HOME/.pharo-cli" ]
    [ ! -L "$HOME/.local/bin/pharo" ]
    run cat "$HOME/.zshrc"
    assert_output "# mine
alias ll='ls -l'"
}

@test "links that point somewhere else are left alone" {
    install_pharo_cli
    rm "$HOME/.local/bin/pharo"
    ln -s /bin/echo "$HOME/.local/bin/pharo"
    run_in_sandbox "$HOME/.pharo-cli/bin/pharo" self-uninstall -y
    assert_success
    [ "$(readlink "$HOME/.local/bin/pharo")" = /bin/echo ]
}

@test "a copy not installed by install.sh is refused and left alone" {
    cp -R "$ORIGIN" "$SANDBOX/dev-clone"
    run_in_sandbox "$SANDBOX/dev-clone/bin/pharo" self-uninstall -y
    assert_failure 1
    assert_output --partial "pharo-cli in $(cd "$SANDBOX/dev-clone" && pwd -P) was not installed by install.sh; remove it by hand"
    [ -f "$SANDBOX/dev-clone/bin/pharo" ]
}

@test "arguments are a usage error" {
    cp -R "$ORIGIN" "$SANDBOX/dev-clone"
    run_in_sandbox "$SANDBOX/dev-clone/bin/pharo" self-uninstall now
    assert_failure 2
    [ -f "$SANDBOX/dev-clone/bin/pharo" ]
}
