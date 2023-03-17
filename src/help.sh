#!/bin/bash

print_version () {
	printf "pharo-cli - A Pharo Images Manager [version 0.8]\n"

print_basic_help () {
	program_name="pharo"
	printf "Usage: %s new [pharo_version] | open [vm arguments] | remove | duplicate | help" "$program_name"
    printf "\n"
    printf "Usage: %s n [pharo_version] | o [vm arguments] | r | d | h" "$program_name"
    printf "\n"
    printf "\n"
}

print_help () {
	print_version
cat << EOF
pharo-cli is a command line image manager. It lets you download, open, duplicate and remove pharo images from any version.

EOF

	print_basic_help

cat << EOF
The options include:
	new [pharo_version]         Downloads a Pharo from from the specified version
                                (latest development version by default). After downloading
                                renames the files and puts them into a filder with the name
                                that was entered (current date and hour by default).
                                Opens the image at the end.

	open [vm_arguments]         Lists all pharo images present in the images folder.
                                Supports fuzzy search and navigation.
                                It sends to the vm all the arguments if they were specified.\n

	duplicate                   Duplicates an image and renames it.

                                If name not specified adds an incremental number at the end.
	remove                      Deletes a Pharo image.

	help		            	Shows help menu

pharo-cli project home page: https://github.com/jordanmontt/pharo-cli
Developed by jordanmontt
This software is licensed under the MIT License.
EOF
}