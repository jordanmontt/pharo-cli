# pharo-cli

`pharo-cli` is a command-line manager for [Pharo](https://pharo.org) images, written in Bash. It creates images from the official templates, opens them with the right VM, and lets you list, rename, duplicate and remove them. Each image lives in its own folder, with its own VM.

It is for people who prefer the terminal. It is not a replacement for [Pharo Launcher](https://github.com/pharo-project/pharo-launcher), but it uses the same template list and picks VMs the same way.

![demo](https://user-images.githubusercontent.com/33934979/226468018-d9387b97-4c0c-4997-a1e0-e0b417715c14.gif)

## Install

pharo-cli runs on macOS and Linux. It needs only `bash` (the 3.2 that ships with macOS is enough), `curl` and `unzip`.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jordanmontt/pharo-cli/main/install.sh)"
```

The installer puts pharo-cli in `~/.pharo-cli`, links the `pharo` command into `~/.local/bin` and the man page into `~/.local/share/man/man1`, and adds a short block to your `~/.zshrc` or `~/.bashrc` (`~/.bash_profile` on macOS) for the `PATH` and Tab completion. Running it again updates pharo-cli; so does `pharo self-update`.

Optional: install [fzf](https://github.com/junegunn/fzf) to choose images with fuzzy search. Without it, pharo-cli shows a numbered list.

## Quick start

```bash
pharo new MyImage          # create an image from the current stable Pharo, and open it
pharo new 13 Old --no-open # create a Pharo 13 image without opening it
pharo o My<TAB>            # complete the name and open it
pharo list                 # see your images, most recently used first
pharo run MyImage --eval '3 + 4'
pharo help                 # every command, setting and example
man pharo
```

## Tab completion

The installer sets it up for Bash and zsh. It completes command names, image names, templates, settings, options, and VM options after `--vm-arg`. To set it up by hand, add this to your shell startup file:

```bash
# Bash
source ~/.pharo-cli/completions/pharo.bash
```

```zsh
# zsh
autoload -U +X bashcompinit && bashcompinit
source ~/.pharo-cli/completions/pharo.bash
```

## Settings

Every default can be changed without touching the code:

```bash
pharo config                                 # list the settings and where each value comes from
pharo config set imagesDir ~/Pharo/images    # store a value
pharo config unset imagesDir                 # back to the default
pharo config reset                           # every setting back to its default
```

Values are stored in `~/.config/pharo-cli/config` (`$XDG_CONFIG_HOME` is respected). An environment variable `PHARO_CLI_<KEY>` overrides the file for one shell or one command, for example `PHARO_CLI_OPEN_MODE=background pharo open MyImage`. The settings are listed at the end of the command reference below.

## How images, templates and VMs work

- **Images.** An image is a folder in `imagesDir` that contains a `.image` file. The folder name is the image name. The folder also holds the VM (`pharo-vm/`) and a small `.pharo-cli` file with the image's origin and when it was created and last opened.
- **Templates.** `pharo new` reads the same template list as Pharo Launcher, `https://files.pharo.org/pharo-launcher/sources.list`, and caches it for a day. `stable` is the current Pharo release, `latest` the newest Pharo version, and a number such as `14` the newest build of that version. `pharo templates` lists the others (Moose, courses, older versions).
- **VMs.** Like Pharo Launcher, pharo-cli reads the image's `pharo.version` file and downloads the VM built for that version, OS and CPU from `files.pharo.org/get-files/`. The `vmStatus` setting chooses the released build (`stable`) or the newest nightly one (`latest`). When there is no stable build for your platform (Linux on ARM), the latest build is used.
- **Removing.** `pharo remove` moves the image folder to the trash (the `trash` command or the Finder on macOS; `gio` or trash-cli on Linux). Only on a system without a trash does it delete for good, after asking.

Images created by older versions of pharo-cli (with zeroconf) keep working: they already have their VM in `pharo-vm/`.

## Command reference

<!-- BEGIN GENERATED COMMAND REFERENCE: run scripts/gen-docs.sh -->
### `config`

```
pharo config [<action>] [<key>] [<value>] [options]
```

Show and change settings.

Actions: list (the default) shows every setting and where its value comes from; get prints one value; set stores a value in the config file; unset removes it so the default applies again; reset removes every stored value, after you confirm.

Aliases: `c`

| Argument or option | Description |
|---|---|
| `<action>` | list, get, set, unset or reset. |
| `<key>` | The setting, for get, set and unset. |
| `<value>` | The new value, for set. |
| `-y, --yes` | Do not ask before reset. |

Examples:

- `pharo config`: Show every setting.
- `pharo config set imagesDir ~/Pharo/images`: Keep images in ~/Pharo/images.
- `pharo config get imagesDir`: Print the images folder setting.
- `pharo config set vmArgs --logLevel=4`: Pass --logLevel=4 to the VM every time.
- `pharo config unset imagesDir`: Go back to the default images folder.
- `pharo config reset`: Go back to the defaults for every setting.

### `duplicate`

```
pharo duplicate [<image>] [<new-name>]
```

Copy an image, with its VM, under a new name.

Aliases: `d`

| Argument or option | Description |
|---|---|
| `<image>` | The image to copy. Without it, you choose one from a list. |
| `<new-name>` | The name of the copy. Without it, the copy is called &lt;image&gt;-1 (or -2, -3... when taken). |

Examples:

- `pharo duplicate MyImage Backup`: Copy MyImage as Backup.
- `pharo duplicate MyImage`: Copy MyImage as MyImage-1.

### `help`

```
pharo help [<command>]
```

Show the help, for every command or for one.

Aliases: `h`

| Argument or option | Description |
|---|---|
| `<command>` | The command to explain. |

Examples:

- `pharo help`: Show every command, setting and example.
- `pharo help new`: Show the arguments and options of new.

### `import`

```
pharo import <source> [<name>]
```

Add an existing image from a folder, a zip file or a zip URL.

A folder is copied, not moved. The image keeps its file names. When the image has no VM and has a pharo.version file, its VM is downloaded.

Aliases: `im`

| Argument or option | Description |
|---|---|
| `<source>` | A folder or .zip file containing a .image file, or the http(s) URL of such a zip. |
| `<name>` | The name of the image. Without it, the folder or zip name is used. |

Examples:

- `pharo import ~/Downloads/MyProject`: Copy the image in ~/Downloads/MyProject into the images folder.
- `pharo import ~/Downloads/moose.zip Moose`: Add the image in moose.zip as Moose.
- `pharo import https://example.org/image.zip`: Download and add the image in a zip.

### `info`

```
pharo info [<image>]
```

Show details about an image.

Aliases: `i`

| Argument or option | Description |
|---|---|
| `<image>` | The image. Without it, you choose one from a list. |

Examples:

- `pharo info MyImage`: Show the Pharo version, image format, VM, size and dates of MyImage.

### `list`

```
pharo list [options]
```

List the images, most recently opened or created first.

Aliases: `l`, `ls`

| Argument or option | Description |
|---|---|
| `-q, --quiet` | Print only the image names, one per line. |

Examples:

- `pharo list`: List the images with their Pharo version and when they were last opened.
- `pharo list --quiet`: Print only the image names.

### `new`

```
pharo new [<template>] [<name>] [options]
```

Create an image from a template.

The template is stable (the current Pharo release), latest (the newest Pharo version), a Pharo version such as 14 (its newest build), or a template id from 'pharo templates'. Without a template, the defaultTemplate setting is used.

With one argument, it is read as a template when it is a version, stable, latest or a template id, and as an image name otherwise. Use --template or --name when a name looks like a template.

Without a name, the image is called Pharo&lt;version&gt;-&lt;date and time&gt;. The VM for the image is downloaded with it.

Aliases: `n`

| Argument or option | Description |
|---|---|
| `<template>` | The template to create the image from. |
| `<name>` | The name of the new image. |
| `-t, --template <template>` | The template to create the image from. |
| `-n, --name <name>` | The name of the new image. |
| `--open` | Open the image once it is created (the default, see the autoOpenOnNew setting). |
| `--no-open` | Do not open the image once it is created. |

Examples:

- `pharo new`: Create an image from the default template (the stable Pharo release).
- `pharo new 14`: Create an image from the newest Pharo 14 build.
- `pharo new 14 MyImage`: Create a Pharo 14 image named MyImage.
- `pharo new MyImage`: Create an image named MyImage from the default template.
- `pharo new latest MyImage --no-open`: Create MyImage from the newest Pharo version without opening it.
- `pharo new --name 14 --template stable`: Create an image named 14 from the stable template.

### `open`

```
pharo open [<image>] [options]
```

Open an image with its VM.

The VM runs in this terminal unless --background is given or the openMode setting is background. An image without a VM gets one downloaded first.

Aliases: `o`

| Argument or option | Description |
|---|---|
| `<image>` | The image to open. Without it, you choose one from a list. |
| `-b, --background` | Run the VM in the background; its output goes to &lt;image&gt;/pharo-cli.log. |
| `-f, --foreground` | Run the VM in this terminal (the default, see the openMode setting). |
| `--vm-arg <arg>` | Pass one argument to the VM. Repeat it to pass several. |

Examples:

- `pharo open MyImage`: Open the image MyImage.
- `pharo open`: Choose an image from a list and open it.
- `pharo open MyImage --background`: Open MyImage and get the terminal back.
- `pharo open MyImage --vm-arg --logLevel=4`: Open MyImage with a VM argument.

### `path`

```
pharo path [<image>]
```

Print the folder of an image, or the images folder.

Aliases: `p`

| Argument or option | Description |
|---|---|
| `<image>` | The image. Without it, the folder that holds all images is printed. |

Examples:

- `cd "$(pharo path MyImage)"`: Go to the folder of MyImage.
- `pharo path`: Print the images folder.

### `remove`

```
pharo remove [<image>] [options]
```

Move an image to the trash.

When the system has no trash (Linux without gio or trash-cli), the image is deleted for good, after you confirm.

Aliases: `rm`

| Argument or option | Description |
|---|---|
| `<image>` | The image to remove. Without it, you choose one from a list. |
| `-y, --yes` | Do not ask before deleting for good. |

Examples:

- `pharo remove MyImage`: Move MyImage to the trash.
- `pharo rm`: Choose an image from a list and move it to the trash.

### `rename`

```
pharo rename [<image>] [<new-name>]
```

Rename an image.

The image folder is renamed, and so are its .image and .changes files when they carry the old name.

Aliases: `re`

| Argument or option | Description |
|---|---|
| `<image>` | The image to rename. Without it, you choose one from a list. |
| `<new-name>` | The new name. Without it, you are asked for one. |

Examples:

- `pharo rename MyImage Experiments`: Rename MyImage to Experiments.
- `pharo rename`: Choose an image from a list and type its new name.

### `run`

```
pharo run <image> [<script>] [options]
```

Run a Smalltalk script or expression in an image, without its UI.

The VM runs headless in this terminal and its exit status is passed on. The image is not saved.

Aliases: `r`

| Argument or option | Description |
|---|---|
| `<image>` | The image to run. |
| `<script>` | A .st file to run. It is given to the image's st command-line handler. |
| `-e, --eval <expression>` | Evaluate an expression and print its result, instead of running a script. |
| `--vm-arg <arg>` | Pass one argument to the VM. Repeat it to pass several. |

Examples:

- `pharo run MyImage --eval '3 + 4'`: Print 7.
- `pharo run MyImage build.st`: Run the script build.st in MyImage.

### `self-update`

```
pharo self-update [options]
```

Update pharo-cli to its newest release.

Aliases: `up`

| Argument or option | Description |
|---|---|
| `--main` | Update to the newest development version (the main branch) instead. |

Examples:

- `pharo self-update`: Update to the newest release.

### `templates`

```
pharo templates [<filter>] [options]
```

List the templates that 'pharo new' can create images from.

Besides these ids, 'pharo new' accepts stable, latest, and a Pharo version such as 14. The list comes from Pharo Launcher's template list and is cached (see the templatesUrl and templatesCacheTtl settings).

Aliases: `t`

| Argument or option | Description |
|---|---|
| `<filter>` | Show only the templates whose id or name contains this text (case does not matter). |
| `--refresh` | Download the template list again instead of using the cached copy. |

Examples:

- `pharo templates`: List all templates.
- `pharo templates moose`: List the templates whose id or name contains moose.

### `version`

```
pharo version
```

Show the version of pharo-cli.

Aliases: `v`

Examples:

- `pharo version`: Print the version.

### Settings

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
| `filesServer` | `https://files.pharo.org` | Server for Pharo images and VMs (change it to use a mirror). |
<!-- END GENERATED COMMAND REFERENCE -->

## Development

The code is plain Bash, compatible with Bash 3.2:

- `bin/pharo` is the entry point. `src/main.sh` loads `src/lib/` and the commands, and dispatches.
- Each command is one file in `src/commands/`, starting with a header (`# @command`, `# @alias`, `# @arg`, `# @option`, `# @example`...). Dispatch, help, completion, the man page and the reference above are all generated from these headers. To add a command, add a file and its tests; nothing else needs to change.
- OS-specific code lives in `src/os/darwin.sh` and `src/os/linux.sh`.
- Defaults live in one table in `src/lib/config.sh`.

Tests use [bats](https://github.com/bats-core/bats-core), included as git submodules:

```bash
git submodule update --init
make test        # the whole suite, offline, in a sandbox
make lint        # ShellCheck
make docs        # regenerate docs/pharo.1 and the reference above
make check       # what CI runs: lint, tests, and docs and tests in sync with the code
make test-live   # really downloads Pharo and its VM, and runs it (needs the network)
```

Tests never touch your images, settings or the network: each runs with a temporary `HOME`, fake `curl`, `uname`, `fzf` and trash tools on `PATH`, and a local folder standing in for files.pharo.org.

## License

MIT. See [LICENSE](LICENSE).
