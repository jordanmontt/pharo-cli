# Changelog

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
