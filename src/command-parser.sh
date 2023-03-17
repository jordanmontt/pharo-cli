#!/bin/bash
#
# pi - Pharo Install - A MIT-pip-like library for Pharo Smalltalk
#

source "${BASH_SOURCE%/*}"/image-manager.sh
source "${BASH_SOURCE%/*}"/../src/help.sh

parse_command () {
	case "$1" in
		open | o)
			open
			;;	
		remove | r)
			remove
			;;
		duplicate | d )
			duplicate
			;;
		new | n )
			install_image
			;;
		version )
            # not yet implemented
			exit 0
			;;
        help | h )
			print_help
			exit 0
            ;;
		* )
			print_help
			exit 1
	esac
}