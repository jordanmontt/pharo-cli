#!/usr/bin/env bash

source "${BASH_SOURCE%/*}"/api.sh


parse_user_input() {
	case "$1" in
	open | o)
		open_command ${@:2}
		;;
	remove | rm)
		remove_command
		;;
	duplicate | d)
		duplicate_command
		;;
	new | n)
		install_image_command ${2}
		;;
	version | v)
		print_version_command
		exit 0
		;;
	help | h)
		print_help_command
		exit 0
		;;
	examples | e)
		print_examples_command
		exit 0
		;;
	rename | re)
		rename_command
		exit 0
		;;
	list | l)
		list_command
		exit 0
		;;
	images-folder)
		print_images_folder
		exit 0
		;;
	*)
		echo Unknow command $1
		exit 1
		;;
	esac
}
