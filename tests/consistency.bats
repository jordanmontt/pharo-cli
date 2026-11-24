#!/usr/bin/env bats
# Keeps the code, its help, its documentation and its tests in sync. These
# checks fail when a command is added without help, examples or tests, when
# an option or setting is never tested, or when the generated docs are stale.

load helpers/common

setup() { sandbox_setup; }

commands() {
    env PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; registry_load; registry_commands'
}

@test "every command has a summary, at least one example and its function" {
    local command
    for command in $(commands); do
        run_in_sandbox PHARO_CLI_ROOT="$PROJECT_ROOT" /bin/bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; registry_load
            [ -n "$(registry_value "$1" summary)" ] || { echo "no @summary"; exit 1; }
            [ -n "$(registry_value "$1" example)" ] || { echo "no @example"; exit 1; }
            declare -F "$(registry_function "$1")" >/dev/null || { echo "no function $(registry_function "$1")"; exit 1; }' _ "$command"
        [ "$status" -eq 0 ] || fail "command $command: $output"
    done
}

@test "every command file declares the command it is named after" {
    local file
    for file in "$PROJECT_ROOT"/src/commands/*.sh; do
        grep -qx "# @command $(basename "$file" .sh)" "$file" || fail "$file does not declare '# @command $(basename "$file" .sh)'"
    done
}

@test "names and aliases are unique" {
    local duplicates
    duplicates=$(grep -h -E '^# @(command|alias) ' "$PROJECT_ROOT"/src/commands/*.sh | awk '{ print $3 }' | sort | uniq -d)
    [ -z "$duplicates" ] || fail "used more than once: $duplicates"
}

@test "every command has a test file" {
    local command
    for command in $(commands); do
        [ -f "$PROJECT_ROOT/tests/commands/$command.bats" ] || fail "missing tests/commands/$command.bats"
    done
}

@test "every option of every command is used in that command's tests" {
    local command flag
    for command in $(commands); do
        for flag in $(env PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; registry_load; registry_values "$1" option | awk "{ for (i = 1; i <= NF && substr(\$i, 1, 1) == \"-\"; i++) print \$i }"' _ "$command"); do
            grep -qe "[ \"']$flag\([ =\"']\|\$\)" "$PROJECT_ROOT/tests/commands/$command.bats" ||
                fail "option $flag of $command is not used in tests/commands/$command.bats"
        done
    done
}

@test "every alias is used in the tests" {
    local alias
    for alias in $(grep -h '^# @alias ' "$PROJECT_ROOT"/src/commands/*.sh | awk '{ print $3 }'); do
        grep -rqe "[ :]$alias:" -e "run_pharo $alias " "$PROJECT_ROOT/tests" || fail "alias $alias is not tested"
    done
}

@test "every setting is used in the tests" {
    local key
    for key in $(env PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; config_keys'); do
        grep -rqe "$key=" "$PROJECT_ROOT/tests" --include '*.bats' || fail "setting $key is never set in the tests"
    done
}

@test "the man page and the README reference are up to date" {
    run "$PROJECT_ROOT/scripts/gen-docs.sh" --check
    assert_success
}

@test "the installer and the code agree on the repository" {
    local repository
    repository=$(sed -n 's/^PHARO_CLI_REPOSITORY="\(.*\)"$/\1/p' "$PROJECT_ROOT/src/lib/core.sh")
    grep -q "PHARO_CLI_REPOSITORY=\"\${PHARO_CLI_REPOSITORY:-$repository}\"" "$PROJECT_ROOT/install.sh" ||
        fail "install.sh does not use $repository"
}

@test "the code does not use Bash 4 features" {
    run bash -c 'grep -HnE "declare -A|local -A|mapfile|readarray|\\$\\{[a-zA-Z_]+(,,|\\^\\^)\\}|&>>|\\|&|coproc" "$@" | grep -vE "^[^:]+:[0-9]+:[[:space:]]*#"' _ "$PROJECT_ROOT"/bin/pharo "$PROJECT_ROOT"/src/*.sh "$PROJECT_ROOT"/src/*/*.sh "$PROJECT_ROOT"/completions/pharo.bash "$PROJECT_ROOT"/install.sh
    assert_output ""
}

@test "no pipe ends with a reader that stops early" {
    # A reader that stops before the end of its input (head, grep -q, awk's
    # exit) breaks the pipe. Where SIGPIPE is ignored, as on some CI machines,
    # the writer then prints "Broken pipe" errors. Readers must consume all
    # their input: sed -n 1p, grep ... >/dev/null, awk with a found flag.
    run bash -c 'grep -HnE "\\| *head|grep -[a-zA-Z]*q|exit *\\}" "$@" | grep -vE "^[^:]+:[0-9]+:[[:space:]]*#"' _ "$PROJECT_ROOT"/bin/pharo "$PROJECT_ROOT"/src/*.sh "$PROJECT_ROOT"/src/*/*.sh "$PROJECT_ROOT"/completions/pharo.bash "$PROJECT_ROOT"/install.sh
    assert_output ""
}
