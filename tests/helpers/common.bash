# Shared test setup. Every test runs pharo-cli in a sandbox:
#   - HOME, XDG folders and the images folder are inside $BATS_TEST_TMPDIR;
#   - PATH holds only the fakes in tests/fakes (curl, uname, fzf, trash, ...)
#     and links to the few real tools pharo-cli needs, so nothing on the
#     developer's machine (a real fzf, gio or trash) can leak in;
#   - the network is a folder served by the fake curl ($FAKE_HTTP_ROOT);
#   - the OS and CPU come from $FAKE_OS and $FAKE_ARCH (macOS on arm64 unless
#     a test changes them).

PROJECT_ROOT="$BATS_TEST_DIRNAME"
while [ ! -f "$PROJECT_ROOT/VERSION" ]; do
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done
load "$PROJECT_ROOT/tests/libs/bats-support/load"
load "$PROJECT_ROOT/tests/libs/bats-assert/load"
load "$PROJECT_ROOT/tests/helpers/fixtures"

PHARO_BIN="$PROJECT_ROOT/bin/pharo"

# Real tools that pharo-cli (or the fakes) use. A tool missing here makes the
# tests fail, which is how new dependencies get noticed.
SANDBOX_REAL_TOOLS="bash env cat sed awk grep mkdir mv cp rm ls date find head tail sort tr od du unzip basename dirname readlink wc cut touch mktemp chmod ln tar gzip nohup sleep git"

sandbox_setup() {
    SANDBOX="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SANDBOX"
    export HOME="$SANDBOX/home"
    mkdir -p "$HOME"
    unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME
    local variable
    for variable in $(env | sed -n 's/^\(PHARO_CLI_[A-Z_]*\)=.*/\1/p'); do
        unset "$variable"
    done

    export FAKE_OS=Darwin FAKE_ARCH=arm64
    export FAKE_HTTP_ROOT="$SANDBOX/http"
    export FAKE_LOG="$SANDBOX/log"
    export FAKE_TRASH="$SANDBOX/trash"
    mkdir -p "$FAKE_HTTP_ROOT" "$FAKE_LOG"
    : >"$FAKE_LOG/curl.log"

    FAKE_BIN="$SANDBOX/fakebin"
    mkdir -p "$FAKE_BIN"
    cp "$PROJECT_ROOT"/tests/fakes/* "$FAKE_BIN/"
    rm -f "$FAKE_BIN/vm"

    REAL_BIN="$SANDBOX/realbin"
    mkdir -p "$REAL_BIN"
    local tool path
    for tool in $SANDBOX_REAL_TOOLS; do
        if [ "$tool" = bash ]; then
            path=/bin/bash # the system Bash: 3.2 on macOS, the version users have
        else
            path=$(command -v "$tool") || {
                echo "missing tool for the tests: $tool" >&2
                return 1
            }
        fi
        ln -s "$path" "$REAL_BIN/$tool"
    done
    SANDBOX_PATH="$FAKE_BIN:$REAL_BIN"
    IMAGES_DIR="$HOME/Documents/PharoCliImages"
}

# Removes a fake tool from PATH, as if it was not installed.
uninstall_fake() {
    local tool
    for tool in "$@"; do
        rm -f "$FAKE_BIN/$tool"
    done
}

# Runs pharo in the sandbox, through bats' run.
run_pharo() {
    run env PATH="$SANDBOX_PATH" "$PHARO_BIN" "$@"
}

# Runs pharo in the sandbox with the text $1 on stdin.
run_pharo_with_input() {
    local input="$1"
    shift
    run bash -c 'printf "%s" "$1" | env PATH="$2" "$3" "${@:4}"' _ "$input" "$SANDBOX_PATH" "$PHARO_BIN" "$@"
}

# Runs Bash code with pharo-cli's functions loaded, in the sandbox.
run_lib() {
    run env PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '
        set -u
        . "$PHARO_CLI_ROOT/src/main.sh"
        registry_load
        os_load
        eval "$1"' _ "$1"
}

# The URLs the fake curl was asked for.
curl_requests() {
    cat "$FAKE_LOG/curl.log"
}

# The arguments of the last fake VM run, one per line.
vm_last_arguments() {
    awk '/^--- / { delete lines; n = 0; next } { lines[++n] = $0 } END { for (i = 1; i <= n; i++) print lines[i] }' "$FAKE_LOG/vm.log"
}

# The working folder of the last fake VM run.
vm_last_folder() {
    sed -n 's/^--- //p' "$FAKE_LOG/vm.log" | tail -n 1
}

# Writes a config file with the given key=value lines.
write_config() {
    mkdir -p "$HOME/.config/pharo-cli"
    printf '%s\n' "$@" >"$HOME/.config/pharo-cli/config"
}
