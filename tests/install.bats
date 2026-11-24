#!/usr/bin/env bats
# install.sh, against a local git "origin" or a fake GitHub.

load helpers/common

setup() {
    sandbox_setup
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    ORIGIN="$SANDBOX/origin"
    mkdir -p "$ORIGIN"
    cp -R "$PROJECT_ROOT/bin" "$PROJECT_ROOT/src" "$PROJECT_ROOT/completions" "$PROJECT_ROOT/docs" "$ORIGIN/"
    echo 1.0.0 >"$ORIGIN/VERSION"
    git -C "$ORIGIN" init -q -b main
    git -C "$ORIGIN" add -A
    git -C "$ORIGIN" commit -q -m "1.0.0"
}

run_installer() {
    run_in_sandbox SHELL="${TEST_SHELL:-/bin/zsh}" PHARO_CLI_GIT_URL="$ORIGIN" "$@" /bin/bash "$PROJECT_ROOT/install.sh"
}

@test "installs with git at the newest tag, links the command and man page, and sets up zsh" {
    git -C "$ORIGIN" tag v1.0.0
    echo 1.1.0-dev >"$ORIGIN/VERSION" && git -C "$ORIGIN" commit -q -am dev
    run_installer
    assert_success
    assert_output --partial "Installed pharo-cli 1.0.0."
    assert_output --partial "Set up the PATH and Tab completion in $HOME/.zshrc"
    [ "$(readlink "$HOME/.local/bin/pharo")" = "$HOME/.pharo-cli/bin/pharo" ]
    [ "$(readlink "$HOME/.local/share/man/man1/pharo.1")" = "$HOME/.pharo-cli/docs/pharo.1" ]
    run_in_sandbox "$HOME/.local/bin/pharo" version
    assert_output "pharo-cli 1.0.0"
    run cat "$HOME/.zshrc"
    assert_output "# >>> pharo-cli >>>
case \":\$PATH:\" in *\":$HOME/.local/bin:\"*) ;; *) export PATH=\"$HOME/.local/bin:\$PATH\" ;; esac
(( \${+functions[compdef]} )) || { autoload -Uz compinit && compinit; }
autoload -U +X bashcompinit && bashcompinit
source \"$HOME/.pharo-cli/completions/pharo.bash\"
# <<< pharo-cli <<<"
}

@test "installs main when there is no release" {
    run_installer
    assert_success
    assert_output --partial "Installed pharo-cli 1.0.0."
    run git -C "$HOME/.pharo-cli" rev-parse --abbrev-ref HEAD
    assert_output main
}

@test "PHARO_CLI_REF picks a version" {
    git -C "$ORIGIN" tag v1.0.0
    echo 2.0.0 >"$ORIGIN/VERSION" && git -C "$ORIGIN" commit -q -am two && git -C "$ORIGIN" tag v2.0.0
    run_installer PHARO_CLI_REF=v1.0.0
    assert_output --partial "Installed pharo-cli 1.0.0."
}

@test "running it again updates and keeps one block, removing the pre-1.0 PATH line" {
    git -C "$ORIGIN" tag v1.0.0
    printf '%s\n' "# mine" "export PATH=\"\$PATH:$HOME/.pharo-cli/bin\"" "alias ll='ls -l'" >"$HOME/.zshrc"
    run_installer
    echo 1.1.0 >"$ORIGIN/VERSION" && git -C "$ORIGIN" commit -q -am up && git -C "$ORIGIN" tag v1.1.0
    run_installer
    assert_success
    assert_output --partial "Updating pharo-cli in $HOME/.pharo-cli"
    assert_output --partial "Installed pharo-cli 1.1.0."
    [ "$(grep -c '# >>> pharo-cli >>>' "$HOME/.zshrc")" -eq 1 ]
    run grep -c "pharo-cli/bin\"\$" "$HOME/.zshrc"
    assert_output 0
    run head -n 2 "$HOME/.zshrc"
    assert_output "# mine
alias ll='ls -l'"
}

@test "updating a pre-1.0 clone on main moves it to the newest release" {
    git clone -q "$ORIGIN" "$HOME/.pharo-cli"
    echo 1.0.1 >"$ORIGIN/VERSION" && git -C "$ORIGIN" commit -q -am fix && git -C "$ORIGIN" tag v1.0.1
    run_installer
    assert_success
    assert_output --partial "Installed pharo-cli 1.0.1."
}

@test "a clone with local changes is not touched" {
    git clone -q "$ORIGIN" "$HOME/.pharo-cli"
    echo "edit" >>"$HOME/.pharo-cli/VERSION"
    run_installer
    assert_failure
    assert_output --partial "has local changes"
}

@test "a folder in the way is not overwritten" {
    mkdir -p "$HOME/.pharo-cli" && touch "$HOME/.pharo-cli/mine"
    run_installer
    assert_failure
    assert_output --partial "exists but is not a pharo-cli git clone"
}

@test "Bash on macOS uses .bash_profile, on Linux .bashrc, without the zsh lines" {
    TEST_SHELL=/bin/bash run_installer
    assert_success
    run cat "$HOME/.bash_profile"
    assert_line "source \"$HOME/.pharo-cli/completions/pharo.bash\""
    refute_output --partial bashcompinit
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    TEST_SHELL=/usr/bin/bash run_installer
    run cat "$HOME/.bashrc"
    assert_line "source \"$HOME/.pharo-cli/completions/pharo.bash\""
}

@test "another shell gets instructions instead" {
    TEST_SHELL=/usr/bin/fish run_installer
    assert_success
    assert_output --partial "Add $HOME/.local/bin to your PATH, and source $HOME/.pharo-cli/completions/pharo.bash"
}

@test "the install folders can be changed" {
    run_installer PHARO_CLI_INSTALL_DIR="$SANDBOX/opt/pharo-cli" PHARO_CLI_BIN_DIR="$SANDBOX/opt/bin" PHARO_CLI_MAN_DIR="$SANDBOX/opt/man1" PHARO_CLI_RC_FILE="$SANDBOX/rc"
    assert_success
    [ -L "$SANDBOX/opt/bin/pharo" ]
    [ -L "$SANDBOX/opt/man1/pharo.1" ]
    grep -q "source \"$SANDBOX/opt/pharo-cli/completions/pharo.bash\"" "$SANDBOX/rc"
}

@test "suggests fzf only when it is missing" {
    run_installer
    refute_output --partial "Tip: install fzf"
    uninstall_fake fzf
    run_installer
    assert_output --partial "Tip: install fzf (https://github.com/junegunn/fzf) to pick images with fuzzy search."
}

@test "missing curl or unzip is reported before anything is done" {
    uninstall_fake curl
    rm "$REAL_BIN/unzip"
    run_installer
    assert_failure
    assert_output --partial "please install: curl unzip"
    [ ! -e "$HOME/.pharo-cli" ]
}

@test "without git it installs the newest release archive" {
    rm "$REAL_BIN/git"
    mkdir -p "$SANDBOX/release/pharo-cli-1.2.0" "$FAKE_HTTP_ROOT/api.github.com/repos/jordanmontt/pharo-cli/releases" "$FAKE_HTTP_ROOT/github.com/jordanmontt/pharo-cli/archive/refs/tags"
    cp -R "$ORIGIN/." "$SANDBOX/release/pharo-cli-1.2.0/"
    rm -rf "$SANDBOX/release/pharo-cli-1.2.0/.git"
    echo 1.2.0 >"$SANDBOX/release/pharo-cli-1.2.0/VERSION"
    tar -czf "$FAKE_HTTP_ROOT/github.com/jordanmontt/pharo-cli/archive/refs/tags/v1.2.0.tar.gz" -C "$SANDBOX/release" pharo-cli-1.2.0
    echo '{ "tag_name": "v1.2.0" }' >"$FAKE_HTTP_ROOT/api.github.com/repos/jordanmontt/pharo-cli/releases/latest"
    run_installer
    assert_success
    assert_output --partial "Downloading pharo-cli (v1.2.0) into $HOME/.pharo-cli"
    assert_output --partial "Installed pharo-cli 1.2.0."
    [ ! -d "$HOME/.pharo-cli/.git" ]
}

@test "without git and without a release it installs main" {
    rm "$REAL_BIN/git"
    mkdir -p "$SANDBOX/release/pharo-cli-main" "$FAKE_HTTP_ROOT/github.com/jordanmontt/pharo-cli/archive/refs/heads"
    cp -R "$ORIGIN/." "$SANDBOX/release/pharo-cli-main/"
    tar -czf "$FAKE_HTTP_ROOT/github.com/jordanmontt/pharo-cli/archive/refs/heads/main.tar.gz" -C "$SANDBOX/release" pharo-cli-main
    run_installer
    assert_success
    assert_output --partial "Downloading pharo-cli (main)"
}

@test "without git, a failed download is reported" {
    rm "$REAL_BIN/git"
    run_installer
    assert_failure
    assert_output --partial "could not download https://github.com/jordanmontt/pharo-cli/archive/refs/heads/main.tar.gz"
}

@test "zsh: the installed block puts pharo on the PATH and registers completion" {
    command -v zsh >/dev/null || skip "zsh is not installed"
    run_installer
    run_in_sandbox "$(command -v zsh)" -f -c 'source "$HOME/.zshrc"; whence -p pharo; complete -p pharo'
    assert_success
    assert_line "$HOME/.local/bin/pharo"
    assert_line "complete -F _pharo_cli_complete pharo"
}
