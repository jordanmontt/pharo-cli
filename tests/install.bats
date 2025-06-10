#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../src/config.sh"

    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR"
    export PHARO_IMAGES_DIR="$TEST_DIR/PharoCliImages"
    export INSTALL_DIR="$TEST_DIR/.pharo-cli"
    export ZSHRC="$TEST_DIR/.zshrc"
    export BASH_PROFILE="$TEST_DIR/.bash_profile"

    # Mock Homebrew install logic to avoid password prompts
    bash() {
        echo "Mock bash: $*"
    }
    export -f bash
    curl() {
        echo "Mock curl"
    }
    export -f curl

    # Mock external commands
    brew() { echo "Mock brew install $1"; }
    export -f brew
    git() { mkdir -p "$INSTALL_DIR/pharo-cli/bin"; echo "Mock git $1"; }
    export -f git
    command() {
        case "$1" in
            -v)
            case "$2" in
                fzf|trash|brew) return 1 ;;  # Simulate these commands missing
                *) /usr/bin/command "$@" ;;  # Defer everything else to the real `command`
            esac
            ;;
            *) /usr/bin/command "$@" ;;
        esac
    }
    export -f command
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "install.sh: installs dependencies" {
  run source "$BATS_TEST_DIRNAME/../install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "fzf not found, installing..." ]]
  [[ "$output" =~ "trash not found, installing..." ]]
}

@test "install.sh: clones repository" {
  run source "$BATS_TEST_DIRNAME/../install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Cloning pharo-cli to $INSTALL_DIR..." ]]
  [ -d "$INSTALL_DIR/pharo-cli/bin" ]
}

@test "install.sh: creates PharoImages directory" {
  run source "$BATS_TEST_DIRNAME/../install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Creating PharoImages directory" ]]
  [ -d "$PHARO_IMAGES_DIR" ]
}

@test "install.sh: updates PATH in zshrc" {
  touch "$ZSHRC"
  run source "$BATS_TEST_DIRNAME/../install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Adding pharo-cli to PATH variable in $ZSHRC" ]]
  grep "export PATH=\"\$PATH:$INSTALL_DIR/bin\"" "$ZSHRC"
}