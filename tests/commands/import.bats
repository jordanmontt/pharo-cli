#!/usr/bin/env bats
# pharo import: folders, zip files and URLs.

load ../helpers/common

setup() {
    sandbox_setup
    serve_pharo 140
    mkdir -p "$SANDBOX/outside/MyProject"
    fake_image_file "$SANDBOX/outside/MyProject/Pharo14.0-SNAPSHOT.image"
    echo 140 >"$SANDBOX/outside/MyProject/pharo.version"
}

@test "a folder is copied, keeps its file names and gets a VM" {
    run_pharo import "$SANDBOX/outside/MyProject"
    assert_success
    assert_output --partial "Imported 'MyProject' into $IMAGES_DIR/MyProject"
    assert_output --partial "Downloading the stable VM for Pharo 14"
    [ -f "$IMAGES_DIR/MyProject/Pharo14.0-SNAPSHOT.image" ]
    [ -x "$IMAGES_DIR/MyProject/pharo-vm/Pharo.app/Contents/MacOS/Pharo" ]
    [ -d "$SANDBOX/outside/MyProject" ]
    run cat "$IMAGES_DIR/MyProject/.pharo-cli"
    assert_line "origin=import of $SANDBOX/outside/MyProject"
    run ls -A "$IMAGES_DIR"
    assert_output MyProject
}

@test "a trailing slash and a custom name work" {
    run_pharo import "$SANDBOX/outside/MyProject/" Renamed
    assert_success
    [ -d "$IMAGES_DIR/Renamed" ]
}

@test "a folder that already has a VM keeps it" {
    fake_vm_layout "$SANDBOX/outside/MyProject/pharo-vm" Darwin
    run_pharo import "$SANDBOX/outside/MyProject"
    assert_success
    run curl_requests
    assert_output ""
}

@test "a zip file is unpacked, named after the zip" {
    (cd "$SANDBOX/outside" && zip -qr "$SANDBOX/proj.zip" MyProject)
    run_pharo import "$SANDBOX/proj.zip"
    assert_success
    [ -f "$IMAGES_DIR/proj/Pharo14.0-SNAPSHOT.image" ]
}

@test "a URL is downloaded and unpacked" {
    mkdir -p "$FAKE_HTTP_ROOT/example.org"
    (cd "$SANDBOX/outside/MyProject" && zip -qr "$FAKE_HTTP_ROOT/example.org/remote.zip" .)
    run_pharo import https://example.org/remote.zip
    assert_success
    assert_output --partial "Downloading https://example.org/remote.zip"
    [ -f "$IMAGES_DIR/remote/Pharo14.0-SNAPSHOT.image" ]
}

@test "without pharo.version it warns that no VM can be chosen" {
    rm "$SANDBOX/outside/MyProject/pharo.version"
    run_pharo import "$SANDBOX/outside/MyProject"
    assert_success
    assert_output --partial "'MyProject' has no VM and no pharo.version file"
}

@test "errors: missing source, folder without image, failed download, taken name" {
    run_pharo import "$SANDBOX/nope"
    assert_failure 3
    assert_output --partial "no such folder or zip file"
    mkdir -p "$SANDBOX/empty"
    run_pharo import "$SANDBOX/empty"
    assert_failure 1
    assert_output --partial "no .image file in $SANDBOX/empty"
    run_pharo import https://example.org/missing.zip
    assert_failure 4
    assert_output --partial "could not download https://example.org/missing.zip"
    run_pharo import "$SANDBOX/missing.zip"
    assert_failure 3
    assert_output --partial "no such file"
    create_image MyProject
    run_pharo import "$SANDBOX/outside/MyProject"
    assert_failure 1
    assert_output --partial "already exists"
    run ls -A "$IMAGES_DIR"
    assert_output MyProject
}

@test "import needs a source" {
    run_pharo import
    assert_failure 2
}

@test "-q and --quiet print nothing but errors" {
    run_pharo import "$SANDBOX/outside/MyProject" -q
    assert_success
    assert_output ""
    run_pharo import "$SANDBOX/outside/MyProject" Other --quiet
    assert_output ""
    run_pharo import "$SANDBOX/nope" -q
    assert_failure 3
    assert_output "pharo: no such folder or zip file: $SANDBOX/nope"
}
