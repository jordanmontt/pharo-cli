#!/usr/bin/env bash
# Live smoke test: runs pharo-cli against the real files.pharo.org, with real
# downloads and real VMs, in a temporary HOME. Nothing outside that folder is
# touched, except that 'pharo remove' moves a small test image to the system
# trash. Prints each step and fails on the first error.

set -u
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHARO="$ROOT/bin/pharo"
WORK=$(mktemp -d)
export HOME="$WORK/home"
export TMPDIR="$WORK/tmp"
mkdir -p "$HOME" "$TMPDIR"
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME
for variable in $(env | sed -n 's/^\(PHARO_CLI_[A-Z_]*\)=.*/\1/p'); do unset "$variable"; done

step() {
    printf '\n=== %s\n' "$*"
}

check() {
    printf '$ %s\n' "$*"
    "$@" || { echo "FAILED: $*" >&2; exit 1; }
}

expect_output() {
    local expected="$1" actual
    shift
    printf '$ %s\n' "$*"
    actual=$("$@") || { echo "FAILED: $*" >&2; exit 1; }
    printf '%s\n' "$actual"
    case "$actual" in
        *"$expected"*) ;;
        *) echo "FAILED: expected output containing '$expected'" >&2; exit 1 ;;
    esac
}

# Waits up to $2 seconds for the process $1 to exist, then stops it.
stop_after() {
    sleep "$2"
    kill -0 "$1" 2>/dev/null || { echo "FAILED: the VM (process $1) is not running" >&2; exit 1; }
    kill "$1"
    echo "The VM was running; stopped it."
}

echo "pharo-cli live test on $(uname -s) $(uname -m), $("$PHARO" --version), bash $BASH_VERSION"
echo "Temporary HOME: $HOME"

step "Templates"
check "$PHARO" templates --refresh
expect_output "pharo-14.0-64bit-stable" "$PHARO" templates pharo-14

step "pharo new: a Pharo version, stable and latest"
check "$PHARO" new 14 Live14 --no-open
check "$PHARO" new stable LiveStable --no-open
check "$PHARO" new latest LiveLatest --no-open
check "$PHARO" list
check "$PHARO" info Live14

step "pharo run: expressions and scripts"
expect_output "7" "$PHARO" run Live14 --eval '3 + 4'
expect_output "Pharo" "$PHARO" run LiveLatest --eval 'SystemVersion current asString'
printf "Stdio stdout nextPutAll: 'from a script'; lf; flush.\n" >"$WORK/script.st"
expect_output "from a script" "$PHARO" run Live14 "$WORK/script.st"
if "$PHARO" run Live14 --eval '1/0' >/dev/null 2>&1; then
    echo "FAILED: an error in the image should give a non-zero exit status" >&2
    exit 1
fi
echo "An error in the image gives a non-zero exit status."

step "The download cache: files.pharo.org sends Last-Modified, so a cached zip is checked, not downloaded again"
curl -fsSI https://files.pharo.org/image/140/latest-64.zip | grep -i '^last-modified:' ||
    { echo "FAILED: files.pharo.org sends no Last-Modified header" >&2; exit 1; }
output=$("$PHARO" new 14 LiveCached --no-open 2>&1) || { printf '%s\n' "$output"; echo "FAILED: new 14 LiveCached" >&2; exit 1; }
printf '%s\n' "$output"
case "$output" in
    *"Unchanged since the last download; using the cached copy."*) ;;
    *) echo "FAILED: the second image of Pharo 14 was downloaded again" >&2; exit 1 ;;
esac

step "pharo run --save, --timeout and --temporary"
check "$PHARO" run Live14 --eval 'Smalltalk globals at: #PharoCliLiveTest put: 42' --save
expect_output "42" "$PHARO" run Live14 --eval 'Smalltalk globals at: #PharoCliLiveTest ifAbsent: [ 0 ]'
printf "Smalltalk globals at: #PharoCliLiveScript put: 7.\n" >"$WORK/save.st"
check "$PHARO" run Live14 "$WORK/save.st" --save
expect_output "7" "$PHARO" run Live14 --eval 'Smalltalk globals at: #PharoCliLiveScript ifAbsent: [ 0 ]'
check "$PHARO" run Live14 --eval 'Smalltalk globals at: #PharoCliUnsaved put: 1'
expect_output "0" "$PHARO" run Live14 --eval 'Smalltalk globals at: #PharoCliUnsaved ifAbsent: [ 0 ]'
"$PHARO" run Live14 --eval '(Delay forSeconds: 120) wait' --timeout 10
status=$?
[ "$status" -eq 124 ] || { echo "FAILED: a hanging run exited $status, not 124" >&2; exit 1; }
echo "A hanging run was stopped with status 124."
expect_output "from a script" "$PHARO" run --temporary 14 "$WORK/script.st"
[ -z "$(ls -A "$TMPDIR")" ] || { echo "FAILED: the temporary image was left in $TMPDIR" >&2; exit 1; }
echo "The temporary image was removed."

step "pharo open --headless --background"
pid=$("$PHARO" open LiveStable --headless --background) || { echo "FAILED: open --headless --background" >&2; exit 1; }
echo "Process $pid"
stop_after "$pid" 5

step "pharo open: foreground and background, with VM arguments (headless, so no window opens)"
"$PHARO" open Live14 --vm-arg --headless --vm-arg --logLevel=2 &
stop_after $! 8
check "$PHARO" open LiveStable --background --vm-arg --headless
pid=$(pgrep -f "LiveStable/pharo-vm" | head -n 1)
[ -n "$pid" ] || { echo "FAILED: no background VM found" >&2; exit 1; }
stop_after "$pid" 3
check cat "$HOME/Documents/PharoCliImages/LiveStable/pharo-cli.log"
check "$PHARO" info LiveStable

step "duplicate, rename, path"
check "$PHARO" duplicate Live14
expect_output "7" "$PHARO" run Live14-1 --eval '3 + 4'
check "$PHARO" rename Live14-1 Renamed
expect_output "$HOME/Documents/PharoCliImages/Renamed" "$PHARO" path Renamed

step "import: a folder, a zip and a URL"
check curl -fsSL -o "$WORK/p13.zip" https://files.pharo.org/image/130/latest-64.zip
check "$PHARO" import "$WORK/p13.zip" FromZip
expect_output "7" "$PHARO" run FromZip --eval '3 + 4'
check "$PHARO" import https://files.pharo.org/image/130/latest-64.zip FromUrl
check cp -R "$HOME/Documents/PharoCliImages/FromZip" "$WORK/folder-image"
check "$PHARO" import "$WORK/folder-image" FromFolder

step "remove (to the system trash: a small fake image, not a real one)"
mkdir -p "$WORK/tiny"
printf 'tiny' >"$WORK/tiny/tiny.image"
check "$PHARO" import "$WORK/tiny" pharo-cli-live-test-tiny
check "$PHARO" remove pharo-cli-live-test-tiny
check "$PHARO" list

step "config"
check "$PHARO" config set vmArgs --logLevel=1
check "$PHARO" config
check "$PHARO" config reset --yes

step "Cleaning up"
rm -rf "$WORK"
echo "Live test passed."
