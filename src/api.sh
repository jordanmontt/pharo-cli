#!/usr/bin/env bash
set -e

source "${BASH_SOURCE%/*}"/image_manager.sh
source "${BASH_SOURCE%/*}"/help_commands.sh


open_command() {
    open_image ${@:2}
}

remove_command() { 
    remove_image
}

duplicate_command() { 
    duplicate_image
}

install_image_command() { 
    install_image ${2} 
}

print_version_command() {
    print_version
}

print_help_command() {
    print_help
}

print_examples_command() {
    print_examples
}

rename_command() {
    rename_image
}

list_command() { 
    list_all_images
}