#!/usr/bin/env bats
# pharo version

load ../helpers/common

setup() { sandbox_setup; }

@test "prints the name and the version from the VERSION file" {
    run_pharo version
    assert_success
    assert_output "pharo-cli $(cat "$PROJECT_ROOT/VERSION")"
    run_pharo v
    assert_output "pharo-cli $(cat "$PROJECT_ROOT/VERSION")"
}

@test "takes no arguments" {
    run_pharo version extra
    assert_failure 2
}
