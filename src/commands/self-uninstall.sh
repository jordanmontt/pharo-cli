#!/usr/bin/env bash
# @command self-uninstall
# @summary Remove pharo-cli from this computer.
# @description Removes the pharo-cli folder, the pharo command and its man page, the block the installer added to your shell startup file, and the template cache. Your images and settings are kept.
# @option -y --yes Do not ask first.
# @example pharo self-uninstall | Remove pharo-cli, after you confirm.

cmd_self_uninstall() {
    local yes=false root="$PHARO_CLI_ROOT" manifest bin_link man_link rc_files file
    while [ $# -gt 0 ]; do
        case "$1" in
            -y | --yes) yes=true ;;
            *) common_option self-uninstall "$1" || check_argument_count self-uninstall 0 1 ;;
        esac
        shift
    done
    manifest="$root/.installed"
    if [ -f "$manifest" ]; then
        bin_link=$(sed -n 's/^binLink=//p' "$manifest")
        man_link=$(sed -n 's/^manLink=//p' "$manifest")
        rc_files=$(sed -n 's/^rcFile=//p' "$manifest")
    elif [ "$root" = "$(physical_path "$HOME/.pharo-cli")" ]; then
        # Installed by a 2.0 installer, which did not write .installed: the
        # installer's default locations.
        bin_link="$HOME/.local/bin/pharo"
        man_link="$HOME/.local/share/man/man1/pharo.1"
        rc_files=$(printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" | sort -u)
    else
        die "pharo-cli in $root was not installed by install.sh; remove it by hand"
    fi
    [ -f "$root/bin/pharo" ] && [ -f "$root/VERSION" ] ||
        die "$root does not look like a pharo-cli installation"

    if [ "$yes" != true ]; then
        info "This removes pharo-cli from $root, the pharo command and its man page."
        info "Your images in $(images_dir) and your settings are kept."
        confirm "Remove pharo-cli?" || {
            info "Cancelled. pharo-cli was not removed."
            exit "$EXIT_ERROR"
        }
    fi

    self_uninstall_link "$bin_link" "$root/bin/pharo"
    self_uninstall_link "$man_link" "$root/docs/pharo.1"
    while IFS= read -r file; do
        [ -n "$file" ] && self_uninstall_rc_block "$file"
    done <<EOF
$rc_files
EOF
    rm -rf "$(templates_cache_dir)"
    rm -rf "$root" || die "could not remove $root"
    info "Removed pharo-cli. Your images are still in $(images_dir)."
    [ -f "$(config_file)" ] && info "Your settings are still in $(config_file)."
    info "Open a new terminal to update your PATH."
    return "$EXIT_OK"
}

# Removes the link $1 when it points to $2, and leaves anything else alone.
self_uninstall_link() {
    local target
    [ -n "$1" ] && [ -L "$1" ] || return 0
    target=$(physical_path "$(readlink "$1")" "$(dirname "$1")") || return 0
    [ "$target" = "$(physical_path "$2")" ] || return 0
    rm -f "$1" || warn "could not remove $1"
}

# Removes the block the installer added to the startup file $1. The markers
# must match the ones in install.sh.
self_uninstall_rc_block() {
    local file="$1" tmp
    [ -f "$file" ] && grep -xF "# >>> pharo-cli >>>" "$file" >/dev/null || return 0
    tmp="$file.pharo-cli.$$"
    awk '
        $0 == "# >>> pharo-cli >>>" { skip = 1; next }
        $0 == "# <<< pharo-cli <<<" { skip = 0; next }
        !skip { print }
    ' "$file" >"$tmp" && cat "$tmp" >"$file"
    rm -f "$tmp"
    info "Removed the pharo-cli block from $file."
}
