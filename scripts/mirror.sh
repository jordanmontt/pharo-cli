#!/usr/bin/env bash
# Mirrors GitHub to another repository: every branch and tag, deleting the
# ones GitHub no longer has.
#   scripts/mirror.sh <url>
#
# Run it in a clone whose origin/* branches are up to date, such as the
# checkout of a GitHub workflow with fetch-depth: 0. It pushes origin/*, not
# the local branches: that checkout has only the branch that was pushed, and
# 'git push --mirror' would then delete every other branch, main included.

set -eu
set -o pipefail

if [ $# -ne 1 ]; then
    echo "usage: scripts/mirror.sh <url>" >&2
    exit 2
fi

# origin/HEAD is a pointer, not a branch.
git update-ref -d refs/remotes/origin/HEAD
git push --prune "$1" '+refs/remotes/origin/*:refs/heads/*' '+refs/tags/*:refs/tags/*'
