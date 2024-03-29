# pharo-cli

`pharo-cli` is a command-line Pharo Image manager application written in bash. It lets you download, open, rename (coming soon), duplicate and remove Pharo images for any Pharo version. It keeps the images organized in separate folders. In each folder you will have your Pharo image, the data and the respective vm. By default, the images will be stored in `~/Documents/PharoImages` but it can be changed. `pharo-cli` also supports fuzzy search for searching between your list of images.

This is a personal work that I use everyday to manage my Pharo images. It's for the people that prefer using the terminal. It is not meant to be a replacement of the [PharoLauncher](https://github.com/pharo-project/pharo-launcher). As I use this, it only works for MacOS out-of-the-box. It can be easily changed to work also in Linux and Windows (see below). If there is interest of people of using this project, I can put some work to make this OS-agnostic.

## How to use

You can run `pharo help` and `pharo examples` to have more info of how the tools works.

![gif5](https://user-images.githubusercontent.com/33934979/226468018-d9387b97-4c0c-4997-a1e0-e0b417715c14.gif)

```bash
$ pharo help
```

```bash
pharo-cli - A Pharo Images Manager [version 0.8]
pharo-cli is a command line image manager. It lets you download, open, duplicate and remove pharo images from any version.

For more detailed examples execute "pharo examples" command.

Usage: pharo [ n | new <pharo_version> ] [ o | open <vm arguments> ] [ re | rename ]
             [ rm | remove ] [ d | duplicate ] [ h | help ] [ l | list ] 
             [ e | examples ] [ v | version]

The options include:
    new <pharo_version>        Downloads a Pharo image using the specified version.
                               Uses the latest development version by default if no version was
                               specified. Asks for an image name, uses the current date and hour
                               by default. After downloading renames the files and puts them into
                               a folder with the name.  Opens the image at the end.

    open <vm_arguments>        Lists all pharo images present in the images folder.
                               Supports fuzzy search and navigation.
                               It sends to the vm all the arguments if they were specified.

    rename                     Renames the selected image to the entered name.
                               Aborts if no name was entered.

    duplicate                  Duplicates an image and renames it.
                               If name not specified adds an incremental number at the end.

    remove                     Deletes a Pharo image.

    help                       Shows help menu

    list                       List all images cointened in the image folder

    examples                   How to use examples

    version                    Current version of pharo-cli

Developed by jordanmontt: https://github.com/jordanmontt/pharo-cli
This software is licensed under the MIT License.
```

```bash
$ pharo examples
```

```bash
USAGE EXAMPLES:

    pharo new
Downloads a new latest development version Pharo image. Asks for a name. If no name was specified uses the current date and time.

    pharo new 10
Downloads a new Pharo 100 image.

    pharo new 09
Downloads a new Pharo 90 image.

    pharo open
Lists all images and then opens the selected one. Supports fuzzy search.

    pharo open -logLevel=4 
Opens the selected Pharo image sending the parameter logLevel=4 to the vm.

    pharo rename
Lists all images, renames the selected one to the entered name.

    pharo duplicate
Duplicates the selected image. Ask for a name. If no one was specified adds an incremental number to the end.

    pharo remove
Lists all images and removes the selected one. It aborts if the operation was canceled.

    pharo help
Shows information and commands about the tool.

    pharo list
Lists all images.

    pharo examples
Lists examples.

    pharo version
Lists pharo-cli version
```

## How to install

First you need to install [fzf](https://github.com/junegunn/fzf) that `pharo-cli` uses for doing the fuzzy search of the list of images.

The, you need to install [trash](https://github.com/ali-rantakari/trash) using `brew install trash`. This is for not deleting the pharo images using `rm -rf` which is irreversible.

After that, you need to clone this repository on `~/.pharo`. You will have as a result the code of this repo here: `~/.pharo/pharo-cli/`. And finally you need to update your `$PATH` variable to point to `~/.pharo/pharo-cli/`. For example in my case I need to add: `export PATH="$PATH:/Users/sebastian/.pharo/pharo-cli/bin/"` to my `.zshrc` file.

Finally, you need to create the folder `~/Documents/PharoImages`. That is the folder in which the images will be stored.

## Important notes

This implementation currently only works on MacOS out-of-the-box. You can make it work easily on other OS. For that, you need:

- to change the `_open_pharo_` function to point to your vm. Currently it's hard coded to get the MacOS VM.
- Replace the use of the command `trash` which only works for Mac and use an equivalent. It can be `rm` or your command of preference.

## Future improvements

- Automate the cloning of the repository and the update of the PATH variable is missing. It will be added in a next release. I would like to have something like `brew install pharo-cli`.
- Generate automatically the help command. For example https://github.com/SierraSoftworks/bash-cli
