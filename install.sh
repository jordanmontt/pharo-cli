#!/usr/bin/env bash
# Installs or updates pharo-cli:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jordanmontt/pharo-cli/main/install.sh)"
#
# It puts pharo-cli in ~/.pharo-cli (with git when available, otherwise from
# a release archive), links the pharo command into ~/.local/bin and its man
# page into ~/.local/share/man/man1, and adds one block to your shell startup
# file for the PATH and Tab completion. Running it again updates everything
# and rewrites that block; it never adds it twice.
#
# Environment variables change where things go:
#   PHARO_CLI_INSTALL_DIR  default ~/.pharo-cli
#   PHARO_CLI_BIN_DIR      default ~/.local/bin
#   PHARO_CLI_MAN_DIR      default ~/.local/share/man/man1
#   PHARO_CLI_REF          a tag or branch to install (default: newest release)
#   PHARO_CLI_RC_FILE      the startup file to edit (default: from $SHELL)
#
# This file cannot share code with pharo-cli: it runs before pharo-cli is on
# disk.

set -u
set -o pipefail

PHARO_CLI_REPOSITORY="${PHARO_CLI_REPOSITORY:-jordanmontt/pharo-cli}"
PHARO_CLI_GIT_URL="${PHARO_CLI_GIT_URL:-https://github.com/$PHARO_CLI_REPOSITORY.git}"
INSTALL_DIR="${PHARO_CLI_INSTALL_DIR:-$HOME/.pharo-cli}"
BIN_DIR="${PHARO_CLI_BIN_DIR:-$HOME/.local/bin}"
MAN_DIR="${PHARO_CLI_MAN_DIR:-$HOME/.local/share/man/man1}"
REF="${PHARO_CLI_REF:-}"

BLOCK_BEGIN="# >>> pharo-cli >>>"
BLOCK_END="# <<< pharo-cli <<<"

say() {
    printf '%s\n' "$*"
}

fail() {
    printf 'pharo-cli installer: %s\n' "$*" >&2
    exit 1
}

check_requirements() {
    local tool missing=""
    for tool in curl unzip tar; do
        command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
    done
    [ -z "$missing" ] || fail "please install:$missing"
}

# The newest v* tag of the git clone in $1, or nothing.
newest_tag() {
    git -C "$1" tag --list 'v*' --sort=-v:refname | head -n 1
}

install_with_git() {
    if [ -d "$INSTALL_DIR/.git" ]; then
        say "Updating pharo-cli in $INSTALL_DIR"
        [ -z "$(git -C "$INSTALL_DIR" status --porcelain)" ] ||
            fail "$INSTALL_DIR has local changes; commit or discard them first"
        git -C "$INSTALL_DIR" fetch --quiet --tags origin || fail "could not fetch $PHARO_CLI_GIT_URL"
    else
        [ ! -e "$INSTALL_DIR" ] || fail "$INSTALL_DIR exists but is not a pharo-cli git clone; move it away first"
        say "Downloading pharo-cli into $INSTALL_DIR"
        git clone --quiet "$PHARO_CLI_GIT_URL" "$INSTALL_DIR" || fail "could not clone $PHARO_CLI_GIT_URL"
    fi
    local ref="$REF"
    [ -n "$ref" ] || ref=$(newest_tag "$INSTALL_DIR")
    [ -n "$ref" ] || ref=main
    if [ "$ref" = main ]; then
        git -C "$INSTALL_DIR" checkout --quiet main || fail "could not switch to main"
        git -C "$INSTALL_DIR" merge --quiet --ff-only origin/main || fail "could not update main"
    else
        git -C "$INSTALL_DIR" checkout --quiet "$ref" || fail "no version $ref"
    fi
}

install_from_archive() {
    local ref="$REF" url tmp
    if [ -z "$ref" ]; then
        ref=$(curl -fsSL "https://api.github.com/repos/$PHARO_CLI_REPOSITORY/releases/latest" 2>/dev/null |
            sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
        [ -n "$ref" ] || ref=main
    fi
    if [ "$ref" = main ]; then
        url="https://github.com/$PHARO_CLI_REPOSITORY/archive/refs/heads/main.tar.gz"
    else
        url="https://github.com/$PHARO_CLI_REPOSITORY/archive/refs/tags/$ref.tar.gz"
    fi
    [ ! -e "$INSTALL_DIR" ] || [ -f "$INSTALL_DIR/bin/pharo" ] ||
        fail "$INSTALL_DIR exists but is not a pharo-cli installation; move it away first"
    say "Downloading pharo-cli ($ref) into $INSTALL_DIR"
    tmp=$(mktemp -d) || fail "cannot create a temporary folder"
    mkdir "$tmp/pharo-cli" &&
        curl -fsSL "$url" -o "$tmp/pharo-cli.tar.gz" &&
        tar -xzf "$tmp/pharo-cli.tar.gz" -C "$tmp/pharo-cli" --strip-components 1 &&
        [ -f "$tmp/pharo-cli/bin/pharo" ] &&
        mkdir -p "$INSTALL_DIR" &&
        cp -R "$tmp/pharo-cli/." "$INSTALL_DIR/"
    local status=$?
    rm -rf "$tmp"
    [ "$status" -eq 0 ] || fail "could not download $url"
}

link_files() {
    mkdir -p "$BIN_DIR" "$MAN_DIR" || fail "cannot create $BIN_DIR or $MAN_DIR"
    ln -sf "$INSTALL_DIR/bin/pharo" "$BIN_DIR/pharo" || fail "cannot link $BIN_DIR/pharo"
    ln -sf "$INSTALL_DIR/docs/pharo.1" "$MAN_DIR/pharo.1" || fail "cannot link $MAN_DIR/pharo.1"
}

# The shell startup file to edit, from PHARO_CLI_RC_FILE or $SHELL.
rc_file() {
    if [ -n "${PHARO_CLI_RC_FILE:-}" ]; then
        printf '%s\n' "$PHARO_CLI_RC_FILE"
        return
    fi
    case "$(basename "${SHELL:-}")" in
        zsh) printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" ;;
        bash)
            if [ "$(uname -s)" = Darwin ]; then
                printf '%s\n' "$HOME/.bash_profile"
            else
                printf '%s\n' "$HOME/.bashrc"
            fi
            ;;
    esac
}

# The block added to the startup file $1.
rc_block() {
    say "$BLOCK_BEGIN"
    say "case \":\$PATH:\" in *\":$BIN_DIR:\"*) ;; *) export PATH=\"$BIN_DIR:\$PATH\" ;; esac"
    case "$1" in
        *zshrc)
            say "(( \${+functions[compdef]} )) || { autoload -Uz compinit && compinit; }"
            say "autoload -U +X bashcompinit && bashcompinit"
            ;;
    esac
    say "source \"$INSTALL_DIR/completions/pharo.bash\""
    say "$BLOCK_END"
}

# Writes the block into the startup file $1, replacing an older one, and
# removes the PATH line written by installers before 2.0.
update_rc_file() {
    local file="$1" tmp old_line
    old_line="export PATH=\"\$PATH:$INSTALL_DIR/bin\""
    tmp="$file.pharo-cli.$$"
    touch "$file" || fail "cannot write $file"
    awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" -v old="$old_line" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip && $0 != old { print }
    ' "$file" >"$tmp" || fail "cannot write $file"
    rc_block "$file" >>"$tmp"
    cat "$tmp" >"$file" && rm -f "$tmp"
}

main() {
    local file
    check_requirements
    if [ -d "$INSTALL_DIR/.git" ]; then
        command -v git >/dev/null 2>&1 || fail "$INSTALL_DIR is a git clone, but git is not installed"
        install_with_git
    elif command -v git >/dev/null 2>&1 && [ ! -f "$INSTALL_DIR/bin/pharo" ]; then
        install_with_git
    else
        install_from_archive
    fi
    link_files
    file=$(rc_file)
    if [ -n "$file" ]; then
        update_rc_file "$file"
        say "Set up the PATH and Tab completion in $file"
    else
        say "Add $BIN_DIR to your PATH, and source $INSTALL_DIR/completions/pharo.bash for Tab completion."
    fi
    say ""
    say "Installed $("$INSTALL_DIR/bin/pharo" --version)."
    [ -n "$file" ] && say "Open a new terminal (or run: source $file), then run 'pharo help'."
    if ! command -v fzf >/dev/null 2>&1; then
        say ""
        say "Tip: install fzf (https://github.com/junegunn/fzf) to pick images with fuzzy search."
        say "Without it, pharo-cli shows a numbered list."
    fi
    return 0
}

main "$@"
