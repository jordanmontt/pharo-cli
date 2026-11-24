#!/usr/bin/env bash
# Generates docs/pharo.1 and the command reference in README.md from the
# command headers. With --check, fails instead when they are out of date.

set -u
set -o pipefail

PHARO_CLI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=src/main.sh
. "$PHARO_CLI_ROOT/src/main.sh"
registry_load

BEGIN_MARKER="<!-- BEGIN GENERATED COMMAND REFERENCE: run scripts/gen-docs.sh -->"
END_MARKER="<!-- END GENERATED COMMAND REFERENCE -->"

man_page() {
    help_man
}

readme() {
    local readme="$PHARO_CLI_ROOT/README.md"
    if ! grep -qxF "$BEGIN_MARKER" "$readme" || ! grep -qxF "$END_MARKER" "$readme"; then
        echo "README.md has no generated reference markers" >&2
        return 1
    fi
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v reference="$1" '
        $0 == begin { print; while ((getline line < reference) > 0) print line; skip = 1; next }
        $0 == end { skip = 0 }
        !skip { print }
    ' "$readme"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
man_page >"$tmp/pharo.1"
help_markdown >"$tmp/reference.md"
readme "$tmp/reference.md" >"$tmp/README.md" || exit 1

if [ "${1:-}" = --check ]; then
    status=0
    cmp -s "$tmp/pharo.1" "$PHARO_CLI_ROOT/docs/pharo.1" || {
        echo "docs/pharo.1 is out of date: run scripts/gen-docs.sh" >&2
        status=1
    }
    cmp -s "$tmp/README.md" "$PHARO_CLI_ROOT/README.md" || {
        echo "README.md is out of date: run scripts/gen-docs.sh" >&2
        status=1
    }
    exit "$status"
fi
mkdir -p "$PHARO_CLI_ROOT/docs"
cp "$tmp/pharo.1" "$PHARO_CLI_ROOT/docs/pharo.1"
cp "$tmp/README.md" "$PHARO_CLI_ROOT/README.md"
echo "Updated docs/pharo.1 and README.md"
