#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/config.sh"

print_images_folder() {
    cat <<EOF
$PHARO_IMAGES_DIR
EOF
}

print_version() {
    cat <<EOF
$PROGRAM_NAME - A Pharo Images Manager [version $VERSION_NUMBER]
EOF
}

print_usage() {
    cat <<EOF
Usage: $COMMAND_NAME <command> [arguments]

Type '$COMMAND_NAME examples' for examples.
EOF
}

print_description() {
    cat <<EOF

$PROGRAM_NAME is a command-line manager for Pharo images.
It lets you download, open, duplicate, and remove Pharo images.

EOF
}

print_commands_help() {
    cat <<EOF
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
EOF
}

print_footer() {
    cat <<EOF

Developed by jordanmontt: https://github.com/jordanmontt/pharo-cli
This software is licensed under the MIT License.
EOF
}

print_help() {
    print_version
    print_description
    print_usage
    echo
    print_commands_help
    print_footer
}

print_examples() {
    cat <<EOF
USAGE EXAMPLES:

    $COMMAND_NAME new
        Downloads a new Pharo image using the latest development version.
        Prompts for a name (defaults to timestamp if skipped).

    $COMMAND_NAME new 130
        Downloads a new Pharo 13 image.
        Prompts for a name (defaults to timestamp if skipped).

    $COMMAND_NAME new 140 MyImage
        Downloads a Pharo 14 image named 'MyImage'.

    $COMMAND_NAME open
        Lists and opens a Pharo image (fuzzy-searchable).

    $COMMAND_NAME open -logLevel=4
        Opens an image with VM arguments.

    $COMMAND_NAME rename
        Renames a selected image.

    $COMMAND_NAME duplicate
        Duplicates a selected image and optionally renames it.

    $COMMAND_NAME remove
        Deletes a selected image.

    $COMMAND_NAME list
        Lists all images.

    $COMMAND_NAME help
        Shows help menu.

    $COMMAND_NAME examples
        Shows usage examples.

    $COMMAND_NAME version
        Displays the version of pharo-cli.
    
    $COMMAND_NAME images-folder
        Displays the images folder path
EOF
}
