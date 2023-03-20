#!/bin/bash

program_name="pharo-cli"
command_name="pharo"
version_number="0.8"

print_version() {
    printf "%s - A Pharo Images Manager [version %s]\n" "$program_name" "$version_number"
}

print_basic_help() {
    printf "Usage: %s [ n | new <pharo_version> ] [ o | open <vm arguments> ] [ re | rename ]" "$command_name"
    printf "\n"
    printf "             [ rm | remove ] [ d | duplicate ] [ h | help ] [ e | examples ] [ v | version ]" "$command_name"
    printf "\n"
    printf "             [ v | version]" "$command_name"
    printf "\n"
}

print_help() {
    print_version
    cat <<EOF
$program_name is a command line image manager. It lets you download, open, duplicate and remove pharo images from any version.

For more detailed examples execute "$program_name examples" command.

EOF

    print_basic_help

    cat <<EOF
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


Developed by jordanmontt: https://github.com/jordanmontt/pharo-cli
This software is licensed under the MIT License.
EOF
}

print_examples() {
    cat <<EOF
USAGE EXAMPLES:

    $command_name new
Downloads a new latest development version Pharo image. Asks for a name. If no name was specified uses the current date and time.

    $command_name new 10
Downloads a new Pharo 10 image.

    $command_name new 09
Downloads a new Pharo 9 image.

    $command_name open
Lists all images and then opens the selected one. Supports fuzzy search.

    $command_name open -logLevel=4 
Opens the selected Pharo image sending the parameter logLevel=4 to the vm.

    $command_name rename
Lists all images, renames the selected one to the entered name.

    $command_name duplicate
Duplicates the selected image. Ask for a name. If no one was specified adds an incremental number to the end.

    $command_name remove
Lists all images and removes the selected one. It aborts if the operation was canceled.
EOF
}
