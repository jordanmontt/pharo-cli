# pharo-cli

`pharo-cli` is a lightweight Bash command-line Pharo image manager.It lets you download, open, rename, duplicate, and remove Pharo images (and more) for **any** Pharo version. It keeps the images organized in separate folders. Each folder contains your Pharo image and its corresponding VM. `pharo-cli` also supports fuzzy search for searching between your list of images.

By default, the images will be stored in `~/Documents/PharoCliImages` but it can be changed.

This is a personal work that I use everyday to manage my Pharo images. It's for the people that prefer using the terminal. It is not meant to be a replacement of the [PharoLauncher](https://github.com/pharo-project/pharo-launcher). Since I use it daily, it only works out-of-the-box on MacOS. It can be easily changed to work also in Linux and Windows (see below). If there is interest of people of using this project, I can put some work to make this OS-agnostic.

## How To Install

### For MacOS

You can install `pharo-cli` on MacOS using either of the following methods:

#### Recommended (via Homebrew)

```bash
brew install pharo-cli
```

#### Manual installation

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jordanmontt/pharo-cli/refs/heads/main/src/install.sh)"
```

### Windows and Linux

Automatic installation is not yet supported on Windows or Linux.

However, `pharo-cli` can be adapted for these platforms with minor modifications. See the [Important Notes](#important-notes) section for more details.

If you're interested in helping add Windows or Linux support, feel free to contact me.

## How To Use

Run `pharo help` and `pharo examples` for more information on how the tool works.

![gif5](https://user-images.githubusercontent.com/33934979/226468018-d9387b97-4c0c-4997-a1e0-e0b417715c14.gif)

```bash
$ pharo help
```

```shell
pharo-cli - A Pharo Images Manager [version 0.8]

pharo-cli is a command-line manager for Pharo images.
It lets you download, open, duplicate, and remove Pharo images.

Usage: pharo <command> [arguments]

Type 'pharo examples' for examples.

Commands:
    new [ver] [name]       Download a Pharo image with optional version and name.
                           Default version is 'alpha'.
                           Prompts for a name (defaults to timestamp if skipped).

    open [vm-args]         Open a Pharo image with optional VM arguments.
                           Supports fuzzy search.

    rename                 Rename the selected image.

    duplicate              Duplicate the selected image and rename it.

    remove                 Delete a selected Pharo image.

    list                   List all available images.

    help                   Show this help message.

    examples               Show usage examples.

    version                Display the current version of pharo-cli.
    
    images-folder           Display the images folder path

Developed by jordanmontt: https://github.com/jordanmontt/pharo-cli
This software is licensed under the MIT License.
```

```bash
$ pharo examples
```

```shell
USAGE EXAMPLES:

    pharo new
        Downloads a new Pharo image using the latest development version.
        Prompts for a name (defaults to timestamp if skipped).

    pharo new 130
        Downloads a new Pharo 13 image.
        Prompts for a name (defaults to timestamp if skipped).

    pharo new 140 MyImage
        Downloads a Pharo 14 image named 'MyImage'.

    pharo open
        Lists and opens a Pharo image (fuzzy-searchable).

    pharo open -logLevel=4
        Opens an image with VM arguments.

    pharo rename
        Renames a selected image.

    pharo duplicate
        Duplicates a selected image and optionally renames it.

    pharo remove
        Deletes a selected image.

    pharo list
        Lists all images.

    pharo help
        Shows help menu.

    pharo examples
        Shows usage examples.

    pharo version
        Displays the version of pharo-cli.
    
    pharo images-folder
        Displays the images folder path
```

## Important Notes

This implementation currently only works on MacOS out-of-the-box. You can make it work easily on other OS. For that, you need:

- Change the `LOCAL_VM_DIR` variable in `config.sh`. Currently it's hard coded to get the MacOS VM.
- Replace the use of `trash` and `fzf`, which only work on MacOS. Instead of `trash` one can use `rm` or your command of preference. Instead of `fzf` one could use just `ls` or an equivalent command.

## Future Improvements

- Support out-of-the-box Linux and Windows installations.
- Have as os dispatcher which will resolve the OS-specific functionalities. Like the vm path or the `trash` or `fzf` commands.
- Make configuration variables easily editable. Currently, if one wants to change the default image folder, one needs to modify the `config.sh` file manually. Next step is to allow to change all the default values without modifying the source code. Something like `pharon changeVariable vmDirectoy new_vm_path`
- Generate automatically the help command. For example https://github.com/SierraSoftworks/bash-cli
