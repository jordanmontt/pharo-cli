#!/usr/bin/env bats
# pharo new: templates, names, VM download, opening.

load ../helpers/common

setup() {
    sandbox_setup
    serve_catalogue
    serve_pharo 140
    serve_pharo 150
    serve_pharo 130
}

@test "new <version> <name> downloads that version and its VM, renames the files and opens the image" {
    run_pharo new 14 MyImage
    assert_success
    assert_output --partial "Downloading Pharo 14: https://files.pharo.org/image/140/latest-64.zip"
    assert_output --partial "Downloading the stable VM for Pharo 14: https://files.pharo.org/get-files/140/pharo-vm-Darwin-arm64-stable.zip"
    assert_output --partial "Created the image 'MyImage' in $IMAGES_DIR/MyImage"
    assert_output --partial "Opening 'MyImage'..."
    assert_output --partial "fake vm ran"
    run env LC_ALL=C ls "$IMAGES_DIR/MyImage"
    assert_output "MyImage.changes
MyImage.image
Pharo14.0-64bit-abc123.sources
pharo-vm
pharo.version"
    assert_equal "$(vm_last_folder)" "$IMAGES_DIR/MyImage"
    run vm_last_arguments
    assert_output "MyImage.image
--interactive"
}

@test "new records where the image came from and when" {
    run_pharo new 14 MyImage --no-open
    run cat "$IMAGES_DIR/MyImage/.pharo-cli"
    assert_line "origin=14"
    assert_line --regexp '^created=[0-9]+$'
    assert_line "templateUrl=https://files.pharo.org/image/140/latest-64.zip"
}

@test "new leaves no staging folder or zip behind" {
    run_pharo new 14 MyImage --no-open
    run ls -A "$IMAGES_DIR"
    assert_output "MyImage"
}

@test "new without arguments uses the default template, stable, and names the image after its version and date" {
    run_pharo new --no-open
    assert_success
    assert_output --partial "Downloading Pharo 14.0 - 64bit (stable): https://files.pharo.org/image/140/latest-64.zip"
    run env LC_ALL=C ls "$IMAGES_DIR"
    assert_output --regexp '^Pharo14-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}h[0-9]{2}$'
}

@test "the default template can be changed" {
    write_config "defaultTemplate=13"
    run_pharo new --no-open
    assert_success
    assert_output --partial "https://files.pharo.org/image/130/latest-64.zip"
}

@test "new latest downloads the newest Pharo version" {
    run_pharo new latest Dev --no-open
    assert_success
    assert_output --partial "https://files.pharo.org/image/150/latest-64.zip"
    run cat "$IMAGES_DIR/Dev/pharo.version"
    assert_output 150
}

@test "a default name that is taken gets a number" {
    run_pharo new 14 --no-open
    run_pharo new 14 --no-open
    assert_success
    run env LC_ALL=C ls "$IMAGES_DIR"
    assert_line --regexp '^Pharo14-.*h[0-9]{2}$'
    assert_line --regexp '^Pharo14-.*h[0-9]{2}-2$'
}

@test "one argument that is not a template is a name" {
    run_pharo new MyImage --no-open
    assert_success
    assert_output --partial "Pharo 14.0 - 64bit (stable)"
    [ -f "$IMAGES_DIR/MyImage/MyImage.image" ]
}

@test "one argument that is a template is the template" {
    run_pharo new 13 --no-open
    assert_success
    run env LC_ALL=C ls "$IMAGES_DIR"
    assert_output --regexp '^Pharo13-'
}

@test "--name and --template remove the ambiguity" {
    run_pharo new --name 14 --template 13 --no-open
    assert_success
    run cat "$IMAGES_DIR/14/pharo.version"
    assert_output 130
    run_pharo new -n stable -t 14 --no-open
    assert_success
    [ -d "$IMAGES_DIR/stable" ]
    run_pharo new --name=eq --template=13 --no-open
    assert_success
    [ -d "$IMAGES_DIR/eq" ]
}

@test "one argument with --name is the template, with --template the name" {
    run_pharo new 13 --name WithName --no-open
    assert_success
    run cat "$IMAGES_DIR/WithName/pharo.version"
    assert_output 130
    run_pharo new 14 --template 13 --no-open
    assert_success
    run cat "$IMAGES_DIR/14/pharo.version"
    assert_output 130
}

@test "arguments and both flags together are a usage error" {
    run_pharo new 13 Name --template 14
    assert_failure 2
    run_pharo new X --template 14 --name Y
    assert_failure 2
    run_pharo new a b c
    assert_failure 2
    run_pharo new --name
    assert_failure 2
    assert_output --partial "--name needs a value"
}

@test "a template id from the catalogue works, and files inside a folder in the zip are found" {
    serve_template 140 "github.com/moosetechnology/Moose/releases/download/v13.x.x/Moose13-stable-Pharo64-13.zip" --folder Moose13
    run_pharo new moose-suite-13-stable Moose --no-open
    assert_success
    [ -f "$IMAGES_DIR/Moose/Moose.image" ]
    [ -x "$IMAGES_DIR/Moose/pharo-vm/Pharo.app/Contents/MacOS/Pharo" ]
}

@test "an existing name is refused before downloading anything" {
    create_image Taken
    run_pharo new 14 Taken
    assert_failure 1
    assert_output --partial "an image named 'Taken' already exists"
    run curl_requests
    assert_output ""
}

@test "an invalid name is refused" {
    run_pharo new 14 "a/b"
    assert_failure 1
    assert_output --partial "image names cannot contain '/'"
}

@test "an unknown template is an error" {
    run_pharo new --template nope Name
    assert_failure 1
    assert_output --partial "unknown template 'nope'. Run 'pharo templates' to see them"
}

@test "a missing template download is an error and leaves nothing behind" {
    run_pharo new 99 Name
    assert_failure 1
    assert_output --partial "could not download https://files.pharo.org/image/990/latest-64.zip"
    run ls -A "$IMAGES_DIR"
    assert_output ""
}

@test "a zip without an image is an error and leaves nothing behind" {
    mkdir -p "$FAKE_HTTP_ROOT/files.pharo.org/image/120"
    (cd "$SANDBOX" && echo hi >readme.txt && zip -q "$FAKE_HTTP_ROOT/files.pharo.org/image/120/latest-64.zip" readme.txt)
    run_pharo new 12 Name
    assert_failure 1
    assert_output --partial "no .image file in"
    run ls -A "$IMAGES_DIR"
    assert_output ""
}

@test "a template without pharo.version gets its id as default name, and no VM can be chosen" {
    serve_template 140 "files.pharo.org/image/110/latest-64.zip" --no-version
    run_pharo new 11 --no-open
    assert_failure 1
    assert_output --partial "it has no pharo.version file"
    run env LC_ALL=C ls "$IMAGES_DIR"
    assert_output --regexp '^11-'
}

@test "--no-open and autoOpenOnNew=false do not open; --open overrides the setting" {
    run_pharo new 14 A --no-open
    refute_output --partial "fake vm ran"
    write_config "autoOpenOnNew=false"
    run_pharo new 14 B
    refute_output --partial "fake vm ran"
    run_pharo new 14 C --open
    assert_output --partial "fake vm ran"
}

@test "opening after new follows openMode" {
    write_config "openMode=background"
    run_pharo new 14 Bg
    assert_success
    assert_output --partial "Opened 'Bg' in the background"
}

@test "Linux on ARM gets the latest VM build" {
    export FAKE_OS=Linux FAKE_ARCH=aarch64
    run_pharo new 14 Arm --no-open
    assert_success
    assert_output --partial "trying the latest build"
    [ -x "$IMAGES_DIR/Arm/pharo-vm/pharo" ]
}

@test "vmStatus=latest downloads the latest VM" {
    serve_vm 140 Darwin arm64 latest
    write_config "vmStatus=latest"
    run_pharo new 14 L --no-open
    assert_success
    assert_output --partial "pharo-vm-Darwin-arm64-latest.zip"
}

@test "the images folder is created when missing and follows imagesDir" {
    write_config "imagesDir=~/elsewhere/images"
    run_pharo new 14 Img --no-open
    assert_success
    [ -f "$HOME/elsewhere/images/Img/Img.image" ]
}
