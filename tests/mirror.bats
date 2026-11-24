#!/usr/bin/env bats
# scripts/mirror.sh, which the Codeberg workflow runs: it copies GitHub's
# branches and tags to another repository.

load helpers/common

setup() {
    sandbox_setup
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    local git_env
    git_env="env -i PATH=$SANDBOX_PATH HOME=$HOME GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1"
    GIT="$git_env git"

    # GitHub: main, a feature branch and a tag.
    GITHUB="$SANDBOX/github"
    $GIT init -q -b main "$GITHUB"
    echo one >"$GITHUB/file" && $GIT -C "$GITHUB" add file && $GIT -C "$GITHUB" commit -q -m one
    $GIT -C "$GITHUB" tag v1.0.0
    echo two >"$GITHUB/file" && $GIT -C "$GITHUB" commit -q -am two
    $GIT -C "$GITHUB" branch feature

    # Codeberg: an older main and a branch GitHub no longer has. Like
    # Codeberg, it refuses to delete its default branch.
    CODEBERG="$SANDBOX/codeberg.git"
    $GIT init -q --bare -b main "$CODEBERG"
    $GIT -C "$GITHUB" push -q "$CODEBERG" v1.0.0^{commit}:refs/heads/main v1.0.0^{commit}:refs/heads/stale
    printf '%s\n' '#!/bin/sh' \
        'while read old new ref; do' \
        '  if [ "$ref" = refs/heads/main ] && [ "$new" = 0000000000000000000000000000000000000000 ]; then' \
        '    echo "branch main is the default branch and cannot be deleted" >&2; exit 1' \
        '  fi' \
        'done' >"$CODEBERG/hooks/pre-receive"
    chmod +x "$CODEBERG/hooks/pre-receive"

    # The workflow's checkout: every GitHub branch as origin/*, but only the
    # pushed branch (here feature) as a local branch.
    CLONE="$SANDBOX/clone"
    $GIT init -q "$CLONE"
    $GIT -C "$CLONE" remote add origin "$GITHUB"
    $GIT -C "$CLONE" fetch -q --tags origin '+refs/heads/*:refs/remotes/origin/*'
    $GIT -C "$CLONE" checkout -q -b feature origin/feature
}

run_mirror() {
    run_in_sandbox /bin/bash -c 'cd "$1" && /bin/bash "$2" "$3"' _ "$CLONE" "$PROJECT_ROOT/scripts/mirror.sh" "$CODEBERG"
}

# The refs of the Codeberg repository, as "name commit" lines.
codeberg_refs() {
    $GIT -C "$CODEBERG" for-each-ref --format='%(refname) %(objectname)'
}

@test "copies every GitHub branch and tag, from a checkout of another branch" {
    run_mirror
    assert_success
    run codeberg_refs
    assert_output "refs/heads/feature $($GIT -C "$GITHUB" rev-parse feature)
refs/heads/main $($GIT -C "$GITHUB" rev-parse main)
refs/tags/v1.0.0 $($GIT -C "$GITHUB" rev-parse v1.0.0)"
}

@test "deletes branches and tags that GitHub no longer has, and pushes no remote-tracking refs" {
    $GIT -C "$CODEBERG" tag old main
    run_mirror
    assert_success
    run codeberg_refs
    refute_output --partial refs/heads/stale
    refute_output --partial refs/tags/old
    refute_output --partial refs/remotes/
}

@test "a branch deleted on GitHub is deleted on Codeberg at the next run" {
    run_mirror
    $GIT -C "$GITHUB" branch -D -q feature
    $GIT -C "$CLONE" checkout -q --detach
    $GIT -C "$CLONE" fetch -q --prune --tags origin '+refs/heads/*:refs/remotes/origin/*'
    run_mirror
    assert_success
    run codeberg_refs
    refute_output --partial refs/heads/feature
    assert_output --partial refs/heads/main
}

@test "a missing URL is a usage error" {
    run_in_sandbox /bin/bash "$PROJECT_ROOT/scripts/mirror.sh"
    assert_failure 2
    assert_output --partial "usage: scripts/mirror.sh <url>"
}
