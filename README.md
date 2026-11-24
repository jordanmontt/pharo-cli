# pharo-cli

`pharo-cli` is a command-line manager for [Pharo](https://pharo.org) images, written in Bash. It creates images from the official templates, opens them with the right VM, and lets you list, rename, duplicate and remove them. Each image lives in its own folder, with its own VM.

pharo-cli is a small personal project for people who like to work in the terminal. It is not meant to replace [Pharo Launcher](https://github.com/pharo-project/pharo-launcher), the official tool for managing Pharo images, which does much more. pharo-cli builds on Pharo Launcher's work instead: it reads the same template list and chooses VMs the same way.

## Install

pharo-cli runs on macOS and Linux. It needs only `bash` (the 3.2 that ships with macOS is enough), `curl` and `unzip`.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jordanmontt/pharo-cli/main/install.sh)"
```

The installer:

- puts pharo-cli in `~/.pharo-cli`;
- links the `pharo` command into `~/.local/bin` and the man page into `~/.local/share/man/man1`;
- adds a short block for the `PATH` and Tab completion to your shell startup file: `.zshrc` (in `$ZDOTDIR` if you set it), `~/.bashrc`, or `~/.bash_profile` on macOS.

Running it again updates pharo-cli, and so does `pharo self-update`.

Optional: install [fzf](https://github.com/junegunn/fzf) to choose images with fuzzy search. Without it, pharo-cli shows a numbered list.

## Quick start

```bash
pharo new MyImage          # create an image from the current stable Pharo, and open it
pharo new 13 Old --no-open # create a Pharo 13 image without opening it
pharo o My<TAB>            # complete the name and open it
pharo list                 # see your images, most recently opened first
pharo run MyImage --eval '3 + 4'
pharo help                 # every command, setting and example
man pharo
```

Every command is described in the [command reference](docs/commands.md), in `pharo help <command>` and in `man pharo`.

## Settings

Every default can be changed without touching the code:

```bash
pharo config                                 # list the settings and where each value comes from
pharo config set imagesDir ~/Pharo/images    # store a value
pharo config unset imagesDir                 # back to the default
pharo config reset                           # every setting back to its default
```

Values are stored in `~/.config/pharo-cli/config` (`$XDG_CONFIG_HOME` is respected). An environment variable `PHARO_CLI_<KEY>` overrides the file for one shell or one command, for example `PHARO_CLI_OPEN_MODE=background pharo open MyImage`.

<!-- BEGIN GENERATED SETTINGS: run scripts/gen-docs.sh -->
Change them with `pharo config set <key> <value>`, or with an environment variable `PHARO_CLI_<KEY>` (for example `PHARO_CLI_IMAGES_DIR`).

| Key | Default | Description |
|---|---|---|
| `imagesDir` | `~/Documents/PharoCliImages` | Folder that holds one sub-folder per image. |
| `defaultTemplate` | `stable` | Template used by 'pharo new' when none is given: stable, latest, a Pharo version such as 14, or a template id. |
| `vmStatus` | `stable` | Which VM build to download: the released one (stable) or the newest nightly build (latest). |
| `openMode` | `foreground` | Whether 'pharo open' runs the VM in this terminal or in the background. |
| `autoOpenOnNew` | `true` | Whether 'pharo new' opens the image once it is created. |
| `vmArgs` | (empty) | Arguments always passed to the VM, separated by spaces. |
| `picker` | `auto` | How to choose an image when none is named: fzf, a numbered menu (select), or fzf when installed (auto). |
| `templatesUrl` | `https://files.pharo.org/pharo-launcher/sources.list` | Template list in Pharo Launcher's sources.list format. |
| `templatesCacheTtl` | `86400` | Seconds before the template list is downloaded again. |
| `filesServer` | `https://files.pharo.org` | Server for Pharo images and VMs (set it to use a mirror). |
<!-- END GENERATED SETTINGS -->

## How images, templates and VMs work

- **Images.** An image is a folder in `imagesDir` that contains a `.image` file. The folder name is the image name. The folder also holds the VM (`pharo-vm/`) and a small `.pharo-cli` file with the image's origin and when it was created and last opened.
- **Templates.** `pharo new` reads the same template list as Pharo Launcher, `https://files.pharo.org/pharo-launcher/sources.list`, and caches it for a day. `stable` is the current Pharo release, `latest` the newest Pharo version, and a number such as `14` the newest build of that version. `pharo templates` lists the others (Moose, courses, older versions).
- **VMs.** Like Pharo Launcher, pharo-cli reads the image's `pharo.version` file and downloads the VM built for that version, OS and CPU from `files.pharo.org/get-files/`. The `vmStatus` setting chooses the released build (`stable`) or the newest nightly one (`latest`). When there is no stable build for your platform (Linux on ARM), the latest build is used.
- **Removing.** `pharo remove` moves the image folder to the trash (the `trash` command or the Finder on macOS; `gio` or trash-cli on Linux). Only on a system without a trash does it delete for good, after asking.

## FAQ

**Should I use pharo-cli or Pharo Launcher?**
Use Pharo Launcher if you prefer a graphical tool or need its features. pharo-cli is for people who live in the terminal and want short commands, Tab completion and scripting. Both get their images and VMs from the same place, `files.pharo.org`.

**Can I use my Pharo Launcher images?**
Yes: `pharo import <folder>` copies an image folder into pharo-cli's images folder and downloads its VM. The original stays where it is, untouched.

**Where are my images, and can I keep them somewhere else?**
`pharo path` prints the folder. `pharo config set imagesDir <folder>` changes it; move existing image folders there yourself.

**Why does every image have its own VM?**
So that each image keeps the VM it was created with. Updating one image's VM, or creating an image of a newer Pharo, never breaks the others. The cost is some disk space per image.

**Why does `pharo list` show `?` for the Pharo version of some images?**
These images have no `pharo.version` file, usually because an older pharo-cli made them with zeroconf. They still open with their own VM.

**How do I pass options to the VM?**
Use `--vm-arg` once per option, for example `pharo open MyImage --vm-arg --logLevel=4`. For options you always want, use `pharo config set vmArgs '<options>'`.

**Does it work offline?**
`open`, `run`, `list` and the other commands on existing images work offline. `new` needs the network to download the image, and its VM when needed. The template list is cached; when it can't be downloaded, an older copy is used, with a warning.

## Upgrading from 1.x

Run the install command again. It updates `~/.pharo-cli`, links `pharo` into `~/.local/bin`, and replaces the `PATH` line the old installer added. Your images stay where they are. Then:

- If you added a `PATH` line for `pharo-cli/bin` by hand, remove it.
- `src/config.sh` is no longer read: set your values again with `pharo config set`. `PHARO_IMAGES_DIR` is now `PHARO_CLI_IMAGES_DIR`.

Commands changed too. See the breaking changes in the [changelog](CHANGELOG.md).

## Uninstall

```bash
pharo self-uninstall
```

It removes pharo-cli, the `pharo` command and its man page, and the block in your shell startup file, after asking. Your images and settings are kept. Delete them yourself if you don't need them: `pharo path` shows the images folder, and the settings are in `~/.config/pharo-cli`.

## Development

The code is plain Bash, compatible with Bash 3.2:

- `bin/pharo` is the entry point. `src/main.sh` loads `src/lib/` and the commands, and dispatches.
- Each command is one file in `src/commands/`, starting with a header (`# @command`, `# @alias`, `# @arg`, `# @option`, `# @example`...). Dispatch, help, completion, the man page and the [command reference](docs/commands.md) are all generated from these headers. To add a command, add a file and its tests; nothing else needs to change.
- OS-specific code lives in `src/os/darwin.sh` and `src/os/linux.sh`.
- Defaults live in one table in `src/lib/config.sh`.

Tests use [bats](https://github.com/bats-core/bats-core), included as git submodules:

```bash
git submodule update --init
make test        # the whole suite, offline, in a sandbox
make lint        # ShellCheck
make docs        # regenerate docs/pharo.1, docs/commands.md and the settings table above
make check       # what CI runs: lint, tests, and docs and tests in sync with the code
make test-live   # really downloads Pharo and its VM, and runs it (needs the network)
```

Tests never touch your images, settings or the network: each runs with a temporary `HOME`, fake `curl`, `uname`, `fzf` and trash tools on `PATH`, and a local folder standing in for files.pharo.org.

## License

MIT. See [LICENSE](LICENSE).
