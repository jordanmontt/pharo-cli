# Changelog

## 2.2.0

pharo-cli now works the same for a person at a terminal and for a script or an agent ([#5](https://github.com/jordanmontt/pharo-cli/issues/5)).

### Added

- `pharo run --save` saves the image after the script or expression.
- `pharo run --timeout <seconds>` stops a VM that is still running after that time (TERM, then KILL 5 seconds later) and exits with status 124.
- `pharo run --temporary <template> <script>` runs in a fresh image made from the template, in a temporary folder, and removes it when the run ends: on success, failure, timeout or when pharo is stopped.
- `pharo open --headless` runs an image without its UI, in the foreground or the background, for example a server.
- `--json` on `info`, `list`, `templates`, `config` and `path`. Unknown values are `null`; dates are ISO 8601 in UTC.
- `--quiet` on `new`, `import`, `run`, `open` and `self-update` prints nothing but errors and warnings.
- Template and VM zips are cached in `~/.cache/pharo-cli/downloads/` and downloaded again only when the server has a newer one (`curl -z`), or with `--refresh` on `new` and `run`. When the server can't be reached, the cached zip is used, with a warning. The `cacheDownloads` setting turns the cache off.
- A [Scripts and agents](docs/commands.md#scripts-and-agents) section and the exit codes in the command reference and the man page.

### Changed

- **Without a terminal, nothing waits for an answer.** When stdin or stderr is not a terminal, the image picker, `rename`'s question for a new name and the confirmations of `remove`, `config reset` and `self-uninstall` fail at once with status 2 instead of waiting. `pharo info < /dev/null` used to wait forever.
- **Exit codes say what failed**, and are documented as stable: 3 for a missing image, script or import source, 4 for a failed download, 5 for a VM that cannot start, 124 for a timeout. These were 1 before. For `pharo run`, 1 now always means that the script failed.
- **Status messages go to stderr**, so stdout carries only results. `pharo open --background` prints the process id alone on stdout.
- Without a terminal, a download prints one line when it is done instead of curl's progress bar, which filled logs with `#=#=#` fragments.

## 2.1.0

### Added

- `pharo self-uninstall` removes pharo-cli, the `pharo` command, its man page and the block in your shell startup file, after asking. Images and settings are kept. The installer now records what it created in `~/.pharo-cli/.installed`; installs made by 2.0.0 are cleaned at the default locations.

### Changed

- The command reference moved from the README to [docs/commands.md](docs/commands.md), still generated from the code. The README is shorter, with a FAQ and sections on upgrading from 1.x and uninstalling.
- `pharo help` shows each example as a comment above its command, with a blank line between examples. Only examples that teach something beyond the usage line remain (19 instead of 39), and a test runs every example to check it is a valid command line.
- The help wraps at 80 columns. Each setting shows its default on its own line, with a blank line between settings, and the three command summaries that wrapped were shortened.
- `self-update` and the installer only refuse to update when tracked files were changed; untracked files no longer block them.

## 2.0.0

A rewrite of pharo-cli: every command is a real command with arguments, the help and Tab completion are generated from the code, every default can be changed without editing the code, and images come from the same templates and VMs as Pharo Launcher instead of zeroconf. It runs on macOS and Linux with no dependency beyond `bash`, `curl` and `unzip`.

### Breaking changes

- **Commands take arguments instead of always asking.** `pharo open MyImage`, `pharo rename Old New`, `pharo duplicate Src Copy`, `pharo remove MyImage`. Without a name, they still show a list to choose from.
- **`pharo open` no longer forwards its other arguments to the VM.** Use `--vm-arg <arg>` once per VM argument (`pharo open MyImage --vm-arg --logLevel=4`), or the `vmArgs` setting.
- **`pharo new [template] [name]`**: the template is `stable`, `latest`, a Pharo version such as `14` (not `140`; `140` still works), or a template id from `pharo templates`. The default is the current stable release, not the development version (`alpha`). Without a name, the image is called `Pharo14-<date>` instead of asking for one.
- **`src/config.sh` is gone.** Settings are changed with `pharo config set <key> <value>` and stored in `~/.config/pharo-cli/config`. The `PHARO_IMAGES_DIR` variable is now `PHARO_CLI_IMAGES_DIR`.
- **Removed commands:** `examples` (the examples are in `pharo help`, `pharo help <command>` and `man pharo`) and `images-folder` (use `pharo path`).
- **Zeroconf is no longer used.** New images no longer contain the zeroconf `pharo` and `pharo-ui` scripts. Images created before keep working: they already have their VM in `pharo-vm/`.
- **`pharo remove` no longer asks** before moving an image to the trash; it only asks before deleting for good, on a system without a trash.
- **The installer no longer installs Homebrew, fzf or trash.** fzf is optional.

### New

- `pharo info`, `pharo path`, `pharo run` (headless `--eval` or `.st` scripts), `pharo import` (folder, zip or URL), `pharo templates`, `pharo config`, `pharo self-update`.
- Tab completion for Bash and zsh: commands, image names, templates, settings, options and VM options.
- `man pharo`.
- `pharo open --background` (or the `openMode` setting) gives the terminal back and logs the VM output to `<image>/pharo-cli.log`.
- `pharo list` shows the Pharo version and when each image was last opened, most recent first.
- Linux support, with the right VM per OS and CPU, including Linux on ARM.
- `pharo new` checks the image name before downloading, and stops on a failed download instead of piping an error page to `bash`.

### Fixed

- Image names with spaces work in every command.
- `rename` and `duplicate` refuse a name that is taken instead of overwriting or nesting folders.
- Cancelling exits with status 1 (it exited with 255), and a wrong command line with status 2.
- `pharo`, `pharo --help` and `pharo -h` show the help instead of "Unknow command".
- `pharo list` and the image picker show only image folders, not stray files.
