#!/bin/bash

source "${BASH_SOURCE%/*}"/image-manager.sh
source "${BASH_SOURCE%/*}"/../src/help-commands.sh

parse_command() {
	case "$1" in
	open | o)
		open
		;;
	remove | rm)
		remove
		;;
	duplicate | d)
		duplicate
		;;
	new | n)
		install_image
		;;
	version | v)
		print_version
		exit 0
		;;
	help | h)
		print_help
		exit 0
		;;
	examples | e)
		print_examples
		exit 0
		;;
	rename | re)
		rename
		exit 0
		;;
	list | l)
		list
		exit 0
		;;
	*)
		echo Unknow command $1
		exit 1
		;;
	esac
}
