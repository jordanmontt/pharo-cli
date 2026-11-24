#!/usr/bin/env bats
# pharo help and pharo <command> --help, generated from the command headers.

load ../helpers/common

setup() { sandbox_setup; }

@test "help lists every command with its aliases and summary" {
    run_pharo help
    assert_success
    assert_line --regexp '^  open, o +Open an image with its VM\.$'
    assert_line --regexp '^  list, l, ls +List the images, most recently opened or created first\.$'
    assert_line --regexp '^  self-update, up +Update pharo-cli to its newest release\.$'
}

@test "help shows every setting with its default" {
    run_pharo help
    assert_line --regexp '^  imagesDir +Folder that holds one sub-folder per image\. Default: ~/Documents/PharoCliImages$'
    assert_line --regexp '^  vmArgs +.*Default: \(empty\)$'
}

@test "help shows the examples of every command" {
    run_pharo help
    assert_line "  pharo new 14 MyImage"
    assert_line "      Create a Pharo 14 image named MyImage."
    assert_line "  pharo run MyImage --eval '3 + 4'"
    assert_line "  pharo config set imagesDir ~/Pharo/images"
}

@test "help <command> shows usage, description, aliases, arguments, options and examples" {
    run_pharo help new
    assert_success
    assert_line --index 0 "Usage: pharo new [<template>] [<name>] [options]"
    assert_line "Create an image from a template."
    assert_line "Aliases: n"
    assert_line --regexp '^  <template> +The template to create the image from\.$'
    assert_line --regexp '^  -t, --template <template> +The template to create the image from\.$'
    assert_line --regexp '^  --no-open +Do not open the image once it is created\.$'
    assert_line --regexp '^  -h, --help +Show this help\.$'
    assert_line "  pharo new latest MyImage --no-open"
}

@test "help accepts aliases" {
    run_pharo help o
    assert_line --index 0 "Usage: pharo open [<image>] [options]"
    run_pharo h n
    assert_line --index 0 "Usage: pharo new [<template>] [<name>] [options]"
}

@test "<command> --help and -h are the same as help <command>" {
    run_pharo help rename
    local expected="$output"
    run_pharo rename --help
    assert_output "$expected"
    run_pharo re -h
    assert_output "$expected"
}

@test "--help wins over other arguments" {
    run_pharo remove Something --help
    assert_success
    assert_line --index 0 --partial "Usage: pharo remove"
}

@test "commands without options show only -h" {
    run_pharo help path
    assert_line --index 0 "Usage: pharo path [<image>]"
    assert_line --regexp '^  -h, --help +Show this help\.$'
}

@test "help of an unknown command is a usage error" {
    run_pharo help nope
    assert_failure 2
    assert_output --partial "unknown command: nope"
}

@test "labels too long for the column wrap onto their own line" {
    run_lib 'help_row "a-very-long-label-here" "Text." 10; help_row "short" "Text." 10'
    assert_output "  a-very-long-label-here
          Text.
  short   Text."
}
