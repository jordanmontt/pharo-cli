#!/usr/bin/env bats
# Dispatch: global options, unknown commands, aliases and exit codes.

load helpers/common

setup() { sandbox_setup; }

@test "no arguments shows the full help" {
    run_pharo
    assert_success
    assert_output --partial "Usage: pharo <command> [arguments] [options]"
    assert_output --partial "Commands:"
}

@test "--help and -h show the full help" {
    run_pharo --help
    assert_success
    assert_output --partial "Commands:"
    run_pharo -h
    assert_success
    assert_output --partial "Commands:"
}

@test "--version and -v print the version from the VERSION file" {
    run_pharo --version
    assert_success
    assert_output "pharo-cli $(cat "$PROJECT_ROOT/VERSION")"
    run_pharo -v
    assert_output "pharo-cli $(cat "$PROJECT_ROOT/VERSION")"
}

@test "an unknown command is a usage error (exit 2)" {
    run_pharo frobnicate
    assert_failure 2
    assert_output --partial "unknown command: frobnicate"
    assert_output --partial "Run 'pharo help' for usage."
}

@test "an unknown global option is a usage error (exit 2)" {
    run_pharo --frobnicate
    assert_failure 2
    assert_output --partial "unknown option: --frobnicate"
}

@test "an unknown option of a command is a usage error that points to its help" {
    run_pharo list --frobnicate
    assert_failure 2
    assert_output --partial "unknown option for 'list': --frobnicate"
    assert_output --partial "Run 'pharo help list' for usage."
}

@test "too many arguments is a usage error" {
    run_pharo path a b
    assert_failure 2
    assert_output --partial "too many arguments for 'path'"
}

@test "every alias runs its command" {
    local pair alias command
    for pair in o:open n:new l:list ls:list i:info p:path re:rename d:duplicate rm:remove r:run im:import t:templates c:config up:self-update h:help v:version; do
        alias="${pair%%:*}"
        command="${pair#*:}"
        run_pharo "$alias" --help
        assert_success
        assert_line --index 0 --partial "Usage: pharo $command"
    done
}

@test "works when called through a symlink, like the installed one" {
    mkdir -p "$SANDBOX/bin"
    ln -s "$PHARO_BIN" "$SANDBOX/bin/pharo"
    run_in_sandbox "$SANDBOX/bin/pharo" version
    assert_success
    assert_output "pharo-cli $(cat "$PROJECT_ROOT/VERSION")"
}

@test "works through a relative symlink" {
    mkdir -p "$SANDBOX/a/b"
    ln -s "$PHARO_BIN" "$SANDBOX/a/pharo-target"
    ln -s ../pharo-target "$SANDBOX/a/b/pharo"
    run_in_sandbox "$SANDBOX/a/b/pharo" version
    assert_success
}

@test "an unsupported operating system is reported" {
    export FAKE_OS=MINGW64_NT
    run_pharo list
    assert_failure 1
    assert_output --partial "unsupported operating system: MINGW64_NT"
}

@test "with SIGPIPE ignored, as on some CI machines, nothing reports a broken pipe" {
    # Ignored signals stay ignored across exec, so pharo runs like on such a
    # machine. Repeated because a broken pipe depends on timing.
    local i
    for i in 1 2 3 4 5; do
        run_in_sandbox /bin/bash -c 'trap "" PIPE
            "$1" __complete 2 pharo help r && "$1" __complete 2 pharo open --vm-arg && "$1" help rename >/dev/null && "$1" config get vmStatus' _ "$PHARO_BIN"
        assert_success
        refute_output --partial "Broken pipe"
        refute_output --partial "write error"
    done
}

@test "physical_path resolves symlinked folders and relative paths" {
    mkdir -p "$SANDBOX/real/dir" && touch "$SANDBOX/real/dir/file"
    ln -s "$SANDBOX/real" "$SANDBOX/link"
    real=$(cd "$SANDBOX/real" && pwd -P)
    run_lib 'physical_path "'"$SANDBOX"'/link/dir/file"; physical_path ../dir/file "'"$SANDBOX"'/link/dir"; physical_path /missing/folder/file || echo missing'
    assert_output "$real/dir/file
$real/dir/file
missing"
}
