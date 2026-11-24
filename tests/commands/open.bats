#!/usr/bin/env bats
# pharo open: by name or picker, foreground or background, VM arguments.

load ../helpers/common

setup() {
    sandbox_setup
    create_image MyImage
}

@test "open <name> runs the image's VM in its folder, in the foreground" {
    run_pharo open MyImage
    assert_success
    assert_output "Opening 'MyImage'...
fake vm ran"
    assert_equal "$(vm_last_folder)" "$IMAGES_DIR/MyImage"
    run vm_last_arguments
    assert_output "MyImage.image
--interactive"
}

@test "the VM's exit status is passed on in the foreground" {
    export FAKE_VM_EXIT=3
    run_pharo open MyImage
    assert_failure 3
}

@test "open records when the image was opened" {
    run_pharo open MyImage
    run cat "$IMAGES_DIR/MyImage/.pharo-cli"
    assert_output --regexp '^lastOpened=[0-9]+$'
}

@test "open without a name uses the picker" {
    export FAKE_FZF_CHOICE=MyImage
    run_pharo open
    assert_success
    assert_output --partial "fake vm ran"
}

@test "cancelling the picker exits 1 without running anything" {
    run_pharo open
    assert_failure 1
    assert_output --partial "Operation cancelled."
    [ ! -e "$FAKE_LOG/vm.log" ]
}

@test "an unknown image is an error" {
    run_pharo open Nope
    assert_failure 1
    assert_output --partial "no image named 'Nope' in $IMAGES_DIR"
}

@test "names with spaces work" {
    create_image "My Image"
    run_pharo open "My Image"
    assert_success
    assert_equal "$(vm_last_folder)" "$IMAGES_DIR/My Image"
    run vm_last_arguments
    assert_line --index 0 "My Image.image"
}

@test "the image file does not need to match the folder name" {
    create_image Other --file Pharo14.0-SNAPSHOT-64bit
    run_pharo open Other
    run vm_last_arguments
    assert_line --index 0 "Pharo14.0-SNAPSHOT-64bit.image"
}

@test "--vm-arg passes arguments to the VM before the image, in order" {
    run_pharo open MyImage --vm-arg --logLevel=4 --vm-arg=--headless --vm-arg "with space"
    assert_success
    run vm_last_arguments
    assert_output "--logLevel=4
--headless
with space
MyImage.image
--interactive"
}

@test "--vm-arg can come before the name, and the value may look like a pharo option" {
    run_pharo open --vm-arg -b MyImage
    assert_success
    run vm_last_arguments
    assert_output "-b
MyImage.image
--interactive"
    refute_output --partial "background"
}

@test "--vm-arg without a value is a usage error" {
    run_pharo open MyImage --vm-arg
    assert_failure 2
    assert_output --partial "--vm-arg needs a value"
}

@test "the vmArgs setting comes first, split on spaces, without glob expansion" {
    write_config "vmArgs=--logLevel=2 --maxFramesToLog=* "
    touch "$IMAGES_DIR/MyImage/--maxFramesToLog=glob-trap"
    run_pharo open MyImage --vm-arg --headless
    run vm_last_arguments
    assert_output "--logLevel=2
--maxFramesToLog=*
--headless
MyImage.image
--interactive"
}

@test "--background runs the VM in the background with its output in pharo-cli.log" {
    run_pharo open MyImage --background
    assert_success
    assert_output --regexp "^Opened 'MyImage' in the background \(process [0-9]+\)\. VM output goes to $IMAGES_DIR/MyImage/pharo-cli.log$"
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        [ -s "$IMAGES_DIR/MyImage/pharo-cli.log" ] && break
        sleep 0.2
    done
    run cat "$IMAGES_DIR/MyImage/pharo-cli.log"
    assert_output "fake vm ran"
}

@test "-b is --background; openMode=background makes it the default; -f overrides it" {
    run_pharo open MyImage -b
    assert_output --partial "in the background"
    write_config "openMode=background"
    run_pharo open MyImage
    assert_output --partial "in the background"
    run_pharo open MyImage -f
    assert_output --partial "Opening 'MyImage'..."
    run_pharo open MyImage --foreground
    assert_output --partial "Opening 'MyImage'..."
}

@test "an image without a VM gets one before opening" {
    serve_pharo 140
    create_image NoVm --no-vm
    run_pharo open NoVm
    assert_success
    assert_output --partial "The image 'NoVm' has no VM yet."
    assert_output --partial "Downloading the stable VM for Pharo 14"
    assert_output --partial "fake vm ran"
}

@test "an old zeroconf image with its own VM and no pharo.version still opens" {
    create_image Zeroconf --no-version
    run_pharo open Zeroconf
    assert_success
    assert_output --partial "fake vm ran"
}

@test "on Linux the VM is pharo-vm/pharo" {
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    create_image LinuxImage --linux-vm
    run_pharo open LinuxImage
    assert_success
    assert_output --partial "fake vm ran"
}

@test "too many names is a usage error" {
    run_pharo open MyImage Other
    assert_failure 2
}
