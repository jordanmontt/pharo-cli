#!/usr/bin/env bash
# Generates docs/pharo.1, docs/commands.md and the settings table in
# README.md from the code. With --check, fails instead when one is out of
# date.

set -u
set -o pipefail

PHARO_CLI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=src/main.sh
. "$PHARO_CLI_ROOT/src/main.sh"
registry_load

BEGIN_MARKER="<!-- BEGIN GENERATED SETTINGS: run scripts/gen-docs.sh -->"
END_MARKER="<!-- END GENERATED SETTINGS -->"

man_page() {
    help_man
}

readme() {
    local readme="$PHARO_CLI_ROOT/README.md"
    if ! grep -qxF "$BEGIN_MARKER" "$readme" || ! grep -qxF "$END_MARKER" "$readme"; then
        echo "README.md has no generated settings markers" >&2
        return 1
    fi
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v generated="$1" '
        $0 == begin { print; while ((getline line < generated) > 0) print line; skip = 1; next }
        $0 == end { skip = 0 }
        !skip { print }
    ' "$readme"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
man_page >"$tmp/pharo.1"
help_markdown >"$tmp/commands.md"
help_markdown_settings >"$tmp/settings.md"
readme "$tmp/settings.md" >"$tmp/README.md" || exit 1

if [ "${1:-}" = --check ]; then
    status=0
    cmp -s "$tmp/pharo.1" "$PHARO_CLI_ROOT/docs/pharo.1" || {
        echo "docs/pharo.1 is out of date: run scripts/gen-docs.sh" >&2
        status=1
    }
    cmp -s "$tmp/commands.md" "$PHARO_CLI_ROOT/docs/commands.md" || {
        echo "docs/commands.md is out of date: run scripts/gen-docs.sh" >&2
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
cp "$tmp/commands.md" "$PHARO_CLI_ROOT/docs/commands.md"
cp "$tmp/README.md" "$PHARO_CLI_ROOT/README.md"
echo "Updated docs/pharo.1, docs/commands.md and README.md"
