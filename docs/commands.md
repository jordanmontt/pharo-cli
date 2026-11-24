# Command reference

Generated from the code by `scripts/gen-docs.sh`. The same help is in `pharo help <command>` and `man pharo`.

## `config`

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

- `pharo config set imagesDir ~/Pharo/images`: Keep new images in ~/Pharo/images.
- `pharo config set vmArgs --logLevel=4`: Pass --logLevel=4 to the VM every time.

## `duplicate`

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

- `pharo duplicate MyImage`: Copy MyImage as MyImage-1.

## `help`

```
pharo help [<command>]
```

Show the help, for every command or for one.

Aliases: `h`

| Argument or option | Description |
|---|---|
| `<command>` | The command to explain. |

## `import`

```
pharo import <source> [<name>]
```

Add an existing image from a folder, a zip file or a URL.

A folder is copied, not moved. The image keeps its file names. When the image has no VM and has a pharo.version file, its VM is downloaded.

Aliases: `im`

| Argument or option | Description |
|---|---|
| `<source>` | A folder or .zip file containing a .image file, or the http(s) URL of such a zip. |
| `<name>` | The name of the image. Without it, the folder or zip name is used. |

Examples:

- `pharo import ~/Documents/Pharo/images/Moose`: Copy an image from Pharo Launcher's images folder.
- `pharo import ~/Downloads/moose.zip Moose`: Add the image in moose.zip, named Moose.
- `pharo import https://example.org/image.zip`: Download a zip and add its image.

## `info`

```
pharo info [<image>]
```

Show details about an image.

Aliases: `i`

| Argument or option | Description |
|---|---|
| `<image>` | The image. Without it, you choose one from a list. |

## `list`

```
pharo list [options]
```

List the images, most recently opened or created first.

Aliases: `l`, `ls`

| Argument or option | Description |
|---|---|
| `-q, --quiet` | Print only the image names, one per line. |

Examples:

- `pharo list -q`: Print only the names, for scripts.

## `new`

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

- `pharo new`: Create an image from the stable Pharo release, with a generated name.
- `pharo new 14 MyImage`: Create MyImage from the newest Pharo 14 build.
- `pharo new latest --no-open`: Create an image from the newest Pharo version, without opening it.
- `pharo new --name 14 --template stable`: Name an image 14: with the flags, 14 is not read as a version.

## `open`

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

- `pharo open`: Choose an image from a list and open it.
- `pharo open MyImage --background`: Open MyImage and get the terminal back.
- `pharo open MyImage --vm-arg --logLevel=4`: Pass an argument to the VM.

## `path`

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

## `remove`

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

## `rename`

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

## `run`

```
pharo run <image> [<script>] [options]
```

Run a script or an expression in an image, without its UI.

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
- `pharo run MyImage build.st`: Run the script build.st in MyImage, then quit.

## `self-uninstall`

```
pharo self-uninstall [options]
```

Remove pharo-cli from this computer.

Removes the pharo-cli folder, the pharo command and its man page, the block the installer added to your shell startup file, and the template cache. Your images and settings are kept.

| Argument or option | Description |
|---|---|
| `-y, --yes` | Do not ask first. |

## `self-update`

```
pharo self-update [options]
```

Update pharo-cli to its newest release.

Aliases: `up`

| Argument or option | Description |
|---|---|
| `--main` | Update to the newest development version (the main branch) instead. |

Examples:

- `pharo self-update --main`: Try the development version (the main branch).

## `templates`

```
pharo templates [<filter>] [options]
```

List the templates that 'pharo new' can use.

Besides these ids, 'pharo new' accepts stable, latest, and a Pharo version such as 14. The list comes from Pharo Launcher's template list and is cached (see the templatesUrl and templatesCacheTtl settings).

Aliases: `t`

| Argument or option | Description |
|---|---|
| `<filter>` | Show only the templates whose id or name contains this text (case does not matter). |
| `--refresh` | Download the template list again instead of using the cached copy. |

Examples:

- `pharo templates moose`: List the templates whose id or name contains moose.

## `version`

```
pharo version
```

Show the version of pharo-cli.

Aliases: `v`

## Settings

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
