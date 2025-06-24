#!/usr/bin/env bash

# Load config variables
source "${BASH_SOURCE%/*}/config.sh"

### Private functions

_go_to_pharo_images_folder_() {
    cd $PHARO_IMAGES_DIR
}

_find_current_directory_() {
    # some magic to find out the real location of this script dealing with symlinks (copied from zeroconf)
    DIR=$(readlink "$0") || DIR="$0"
    DIR=$(dirname "$DIR")
    cd "$DIR"
    DIR=$(pwd)
    cd - >/dev/null
    echo $DIR
}

_open_pharo_() {
    directory=${1}
    if [ -z $directory ]; then
        echo "Error, you need to send an image directory as argument"
    else
        cd "$directory"
        image=$(find . -name "*.image" -maxdepth 1 | head -n 1)
        echo "Opening Pharo image: $image in location: $(pwd)" 
        # disable parameter expansion to forward all arguments unprocessed to the VM
        set -f
        $LOCAL_VM_DIR ${@:2} $image --interactive
    fi
}

_rename_images_files_() {
    name=${1}
    new_name=${2}
    echo "Renaming ${name}.image to ${new_name}.image"
    mv "${name}".image "${new_name}".image
    echo "Renaming ${name}.changes to ${new_name}.changes"
    mv "${name}".changes "${new_name}".changes
}

_rename_files_and_container_folder_() {
    _rename_images_files_ ${1} ${2}
    cd ..
    echo "Renaming folder ${1} to ${2}"
    mv "${1}" "${2}"
}

####
######## API
####

open_image() {
    old_location=$(_find_current_directory_)

    _go_to_pharo_images_folder_

    image_name=$(ls -t | fzf)
    if [ -z $image_name ]; then
        cd $old_location
        echo "Operation canceled."
        return -1
    fi

    cd "$image_name"
    _open_pharo_ . ${@}

    cd $old_location
}

list_all_images() {
    old_location=$(_find_current_directory_)

    _go_to_pharo_images_folder_
    for f in $(ls -t); do
        echo "$f"
    done

    cd $old_location
}

rename_image() {
    old_location=$(_find_current_directory_)

    _go_to_pharo_images_folder_

    image_name=$(ls -t | fzf)
    if [ -z $image_name ]; then
        cd $old_location
        return -1
    fi

    cd "$image_name"
    echo "Enter a new name:"
    read new_image_name
    if [ -z $new_image_name ]; then
        cd $old_location
        return -1
    fi

    _rename_files_and_container_folder_ $image_name $new_image_name
}

remove_image() {
    old_location=$(pwd)

    _go_to_pharo_images_folder_

    image_name=$(ls -t | fzf)
    if [ -z $image_name ]; then
        cd $old_location
        return -1
    fi

    echo "Are you sure that you want to move to the Trash the image: ${image_name} y/n?"
    read -r choice < /dev/stdin
    case "$choice" in
    y | Y) trash -F "$PHARO_IMAGES_DIR/$image_name" && echo "Image ${image_name} moved to the Trash successfully" ;;
    *) echo "Canceling" ;;
    esac

    cd $old_location
}

duplicate_image() {
    old_location=$(pwd)

    _go_to_pharo_images_folder_
    image_to_duplicate_name=$(ls -t | fzf)
    if [ -z $image_to_duplicate_name ]; then
        cd $old_location
        return -1
    fi

    echo "The name for the image: (skip to copy the name)"
    read new_image_name

    # Append an incremental number to the end of the image name.
    # Searchs for the next number
    if [ -z "$new_image_name" ]; then
        counter=1
        while [ -d "${image_to_duplicate_name}-${counter}" ]; do
            counter=$((counter + 1))
        done
        new_image_name="${image_to_duplicate_name}-${counter}"
    fi

    cp -R $image_to_duplicate_name $new_image_name
    cd $new_image_name
    _rename_images_files_ $image_to_duplicate_name $new_image_name

    cd $old_location
}

# Download only Pharo image using zero conf. Image name optional parameter. Creates the folder and renames the files
install_image() {
    old_location=$(_find_current_directory_)

    # Optional parameters
    # Pharo version (90, 100, 140...)
    pharo_version=${1}
    if [ -z $pharo_version ]; then
        pharo_version=$DEFAULT_PHARO_VERSION
    fi

    # Image name
    image_name=${2}
    if [ -z $image_name ]; then
        #Getting image name
        current_date=$(date +"%d-%m-%Y-%Hh%M")
        echo "Enter an image name: (skip to use ${current_date})"
        read image_name
        if [ -z $image_name ]; then
            image_name=$current_date
        fi
    fi
    
    # Creating folder and go
    _go_to_pharo_images_folder_
    mkdir $image_name
    cd $image_name

    # Download Pharo
    link_to_download="https://get.pharo.org/${pharo_version}+vm"

    curl -L $link_to_download | bash

    # Rename files to image_name
    _rename_images_files_ "Pharo" $image_name

    # Open Pharo
    _open_pharo_ .

    cd $old_location 
}