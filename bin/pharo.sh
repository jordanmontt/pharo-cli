#!/bin/bash
#
# pharo image manager
#

source "${BASH_SOURCE%/*}"/../src/image-manager.sh
source "${BASH_SOURCE%/*}"/../src/command-parser.sh

#################################
## Main Section
#################################

parse_command ${@}