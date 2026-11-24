# Development tasks. Run 'git submodule update --init' once for bats.

BATS := tests/libs/bats-core/bin/bats
SHELL_FILES := bin/pharo install.sh scripts/*.sh src/*.sh src/lib/*.sh src/os/*.sh src/commands/*.sh completions/pharo.bash

.PHONY: test lint docs check test-live

# The offline test suite (sandboxed: no network, no real images or settings).
test:
	$(BATS) --print-output-on-failure tests tests/commands

# ShellCheck on every script.
lint:
	shellcheck -x -s bash $(SHELL_FILES)

# Regenerates docs/pharo.1, docs/commands.md and the README settings table.
docs:
	scripts/gen-docs.sh

# What CI runs. The tests also check that the docs and tests are in sync.
check: lint test

# Downloads real Pharo images and VMs and runs them (needs the network).
test-live:
	scripts/live-test.sh
