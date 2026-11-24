#!/usr/bin/env bats
# pharo self-update, against a local git "origin" or a fake GitHub.

load ../helpers/common

setup() {
    sandbox_setup
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
}

# Makes a git repository at $1 with pharo-cli at version $2 on main.
make_release_repo() {
    local repo="$1"
    mkdir -p "$repo"
    cp -R "$PROJECT_ROOT/bin" "$PROJECT_ROOT/src" "$repo/"
    echo "$2" >"$repo/VERSION"
    git -C "$repo" init -q -b main
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "release $2"
}

# Publishes version $1 on the origin, tagged when $2 is "tag".
publish() {
    echo "$1" >"$SANDBOX/origin/VERSION"
    git -C "$SANDBOX/origin" commit -q -am "version $1"
    [ "${2:-}" = tag ] && git -C "$SANDBOX/origin" tag "v$1"
    return 0
}

@test "a git install moves to the newest tag" {
    make_release_repo "$SANDBOX/origin" 1.0.0
    git -C "$SANDBOX/origin" tag v1.0.0
    git clone -q "$SANDBOX/origin" "$SANDBOX/install"
    git -C "$SANDBOX/install" checkout -q v1.0.0
    publish 1.1.0 tag
    publish 1.2.0-dev
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update
    assert_success
    assert_output "Updated pharo-cli from 1.0.0 to 1.1.0."
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update
    assert_output "pharo-cli 1.1.0 is up to date."
}

@test "tags are compared as versions (v1.10.0 is newer than v1.9.0)" {
    make_release_repo "$SANDBOX/origin" 1.9.0
    git -C "$SANDBOX/origin" tag v1.9.0
    git clone -q "$SANDBOX/origin" "$SANDBOX/install"
    publish 1.10.0 tag
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update
    assert_output "Updated pharo-cli from 1.9.0 to 1.10.0."
}

@test "--main follows the main branch" {
    make_release_repo "$SANDBOX/origin" 1.0.0
    git clone -q "$SANDBOX/origin" "$SANDBOX/install"
    publish 1.1.0-dev
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update --main
    assert_success
    assert_output "Updated pharo-cli from 1.0.0 to 1.1.0-dev."
}

@test "local changes stop the update" {
    make_release_repo "$SANDBOX/origin" 1.0.0
    git -C "$SANDBOX/origin" tag v1.0.0
    git clone -q "$SANDBOX/origin" "$SANDBOX/install"
    echo "edit" >>"$SANDBOX/install/VERSION"
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update
    assert_failure 1
    assert_output --partial "has local changes"
}

@test "an archive install downloads the newest GitHub release" {
    mkdir -p "$SANDBOX/install"
    cp -R "$PROJECT_ROOT/bin" "$PROJECT_ROOT/src" "$SANDBOX/install/"
    echo 1.0.0 >"$SANDBOX/install/VERSION"
    mkdir -p "$SANDBOX/release/pharo-cli-1.1.0" "$FAKE_HTTP_ROOT/api.github.com/repos/jordanmontt/pharo-cli/releases" "$FAKE_HTTP_ROOT/github.com/jordanmontt/pharo-cli/archive/refs/tags"
    cp -R "$PROJECT_ROOT/bin" "$PROJECT_ROOT/src" "$SANDBOX/release/pharo-cli-1.1.0/"
    echo 1.1.0 >"$SANDBOX/release/pharo-cli-1.1.0/VERSION"
    tar -czf "$FAKE_HTTP_ROOT/github.com/jordanmontt/pharo-cli/archive/refs/tags/v1.1.0.tar.gz" -C "$SANDBOX/release" pharo-cli-1.1.0
    printf '{\n  "url": "x",\n  "tag_name": "v1.1.0",\n  "name": "v1.1.0"\n}\n' >"$FAKE_HTTP_ROOT/api.github.com/repos/jordanmontt/pharo-cli/releases/latest"
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update
    assert_success
    assert_output "Updated pharo-cli from 1.0.0 to 1.1.0."
}

@test "an archive install reports a failed download and stays as it was" {
    mkdir -p "$SANDBOX/install"
    cp -R "$PROJECT_ROOT/bin" "$PROJECT_ROOT/src" "$SANDBOX/install/"
    echo 1.0.0 >"$SANDBOX/install/VERSION"
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update
    assert_failure 1
    assert_output --partial "could not find the newest release"
    run_in_sandbox "$SANDBOX/install/bin/pharo" self-update --main
    assert_failure 1
    assert_output --partial "could not download https://github.com/jordanmontt/pharo-cli/archive/refs/heads/main.tar.gz"
    run cat "$SANDBOX/install/VERSION"
    assert_output 1.0.0
}
