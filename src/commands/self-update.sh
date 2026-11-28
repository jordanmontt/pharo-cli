#!/usr/bin/env bash
# @command self-update
# @alias up
# @summary Update pharo-cli to its newest release.
# @option --main Update to the newest development version (the main branch) instead.
# @option -q --quiet Print nothing but errors and warnings.
# @example pharo self-update --main | Try the development version (the main branch).

cmd_self_update() {
    local channel=release before after
    while [ $# -gt 0 ]; do
        case "$1" in
            --main) channel=main ;;
            -q | --quiet) info_be_quiet ;;
            *) common_option self-update "$1" || check_argument_count self-update 0 1 ;;
        esac
        shift
    done
    before=$(pharo_cli_version)
    if [ -d "$PHARO_CLI_ROOT/.git" ]; then
        self_update_git "$channel"
    else
        self_update_archive "$channel"
    fi
    after=$(pharo_cli_version)
    if [ "$before" = "$after" ]; then
        info "pharo-cli $after is up to date."
    else
        info "Updated pharo-cli from $before to $after."
    fi
}

# Updates a git clone to the newest v* tag, or to the main branch.
self_update_git() {
    local root="$PHARO_CLI_ROOT" tag
    has_command git || die "pharo-cli is a git clone, but git is not installed"
    [ -z "$(git -C "$root" status --porcelain --untracked-files=no)" ] ||
        die "$root has local changes; commit or discard them first"
    git -C "$root" fetch --quiet --tags origin || die "could not fetch updates"
    if [ "$1" = main ]; then
        git -C "$root" checkout --quiet main || die "could not switch to the main branch"
        git -C "$root" merge --quiet --ff-only origin/main || die "could not update the main branch"
        return 0
    fi
    tag=$(git -C "$root" tag --list 'v*' --sort=-v:refname | sed -n 1p)
    [ -n "$tag" ] || die "no release found"
    git -C "$root" checkout --quiet "$tag" || die "could not switch to $tag"
}

# Updates an installation made from an archive: downloads the newest release
# (or main) and copies it over the installation.
self_update_archive() {
    local root="$PHARO_CLI_ROOT" url tag tmp
    if [ "$1" = main ]; then
        url="https://github.com/$PHARO_CLI_REPOSITORY/archive/refs/heads/main.tar.gz"
    else
        tag=$(http_get "https://api.github.com/repos/$PHARO_CLI_REPOSITORY/releases/latest" |
            sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n 1p)
        [ -n "$tag" ] || die_with "$EXIT_DOWNLOAD" "could not find the newest release"
        url="https://github.com/$PHARO_CLI_REPOSITORY/archive/refs/tags/$tag.tar.gz"
    fi
    tmp=$(mktemp -d) || die "cannot create a temporary folder"
    if ! http_get "$url" >"$tmp/pharo-cli.tar.gz" ||
        ! mkdir "$tmp/pharo-cli" ||
        ! tar -xzf "$tmp/pharo-cli.tar.gz" -C "$tmp/pharo-cli" --strip-components 1 ||
        [ ! -f "$tmp/pharo-cli/bin/pharo" ]; then
        rm -rf "$tmp"
        die_with "$EXIT_DOWNLOAD" "could not download $url"
    fi
    cp -R "$tmp/pharo-cli/." "$root/" || {
        rm -rf "$tmp"
        die "could not update $root"
    }
    rm -rf "$tmp"
}
