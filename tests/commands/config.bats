#!/usr/bin/env bats
# pharo config: list, get, set, unset, reset.

load ../helpers/common

setup() { sandbox_setup; }

@test "config with no action lists every setting with its origin" {
    write_config "picker=select"
    run_in_sandbox PHARO_CLI_OPEN_MODE=background "$PHARO_BIN" config
    assert_success
    assert_line --regexp '^imagesDir +~/Documents/PharoCliImages +\(default\)$'
    assert_line --regexp '^picker +select +\(set\)$'
    assert_line --regexp '^openMode +background +\(from PHARO_CLI_OPEN_MODE\)$'
    assert_line "Config file: $HOME/.config/pharo-cli/config"
}

@test "config list is the same as config" {
    run_pharo config list
    assert_success
    assert_line --regexp '^vmStatus +stable +\(default\)$'
}

@test "config get prints the effective value" {
    run_pharo config get imagesDir
    assert_success
    assert_output "$HOME/Documents/PharoCliImages"
}

@test "config set stores a value that later commands use" {
    run_pharo config set imagesDir "~/Pharo images"
    assert_success
    assert_output "imagesDir = ~/Pharo images"
    run_pharo path
    assert_output "$HOME/Pharo images"
}

@test "config set takes a value starting with a dash as the value" {
    run_pharo config set vmArgs --logLevel=4
    assert_success
    assert_output "vmArgs = --logLevel=4"
    run_pharo config set vmArgs -y
    assert_success
    run_pharo config get vmArgs
    assert_output -- "-y"
}

@test "config set rejects invalid values and leaves the file alone" {
    run_pharo config set openMode sideways
    assert_failure 1
    assert_output --partial "invalid value: 'openMode' must be one of: foreground, background"
    [ ! -e "$HOME/.config/pharo-cli/config" ]
}

@test "config set warns when an environment variable overrides the value" {
    run_in_sandbox PHARO_CLI_PICKER=fzf "$PHARO_BIN" config set picker select
    assert_success
    assert_output --partial "PHARO_CLI_PICKER is set in the environment and overrides this value"
}

@test "config set needs a key and a value" {
    run_pharo config set picker
    assert_failure 2
    assert_output --partial "'config set' needs a key and a value"
}

@test "an unknown key is a usage error" {
    run_pharo config get vmDirectory
    assert_failure 2
    assert_output --partial "unknown setting: vmDirectory"
    run_pharo config set vmDirectory /tmp
    assert_failure 2
}

@test "a missing key is a usage error" {
    run_pharo config get
    assert_failure 2
    assert_output --partial "a setting key is needed"
}

@test "an unknown action is a usage error" {
    run_pharo config change picker fzf
    assert_failure 2
    assert_output --partial "unknown config action: change"
}

@test "config unset goes back to the default" {
    write_config "picker=select"
    run_pharo config unset picker
    assert_success
    assert_output "picker = auto (default)"
    run_pharo config get picker
    assert_output auto
}

@test "config reset asks first and keeps the settings when refused" {
    write_config "picker=select"
    run_pharo_with_input "n
" config reset
    assert_failure 1
    assert_output --partial "Reset every setting to its default? [y/N]"
    assert_output --partial "Cancelled. Settings were not changed."
    run_pharo config get picker
    assert_output select
}

@test "config reset with no answer (stdin closed) keeps the settings" {
    write_config "picker=select"
    run_pharo_with_input "" config reset
    assert_failure 1
    run_pharo config get picker
    assert_output select
}

@test "config reset resets after a yes" {
    write_config "picker=select" "openMode=background"
    run_pharo_with_input "y
" config reset
    assert_success
    assert_output --partial "Every setting is back to its default."
    run_pharo config get openMode
    assert_output foreground
}

@test "config reset --yes and -y do not ask" {
    write_config "picker=select"
    run_pharo config reset --yes
    assert_success
    refute_output --partial "[y/N]"
    write_config "picker=select"
    run_pharo config reset -y
    assert_success
    run_pharo config get picker
    assert_output auto
}

@test "too many arguments for an action is a usage error" {
    run_pharo config get picker extra
    assert_failure 2
    run_pharo config list extra
    assert_failure 2
}
