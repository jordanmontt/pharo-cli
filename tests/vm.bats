#!/usr/bin/env bats
# Choosing and downloading VMs, the way Pharo Launcher does.

load helpers/common

setup() { sandbox_setup; }

@test "VM URLs for Pharo 9 and later name the OS, CPU and build status" {
    run_lib 'vm_url 140 stable; vm_url 90 latest'
    assert_output "https://files.pharo.org/get-files/140/pharo-vm-Darwin-arm64-stable.zip
https://files.pharo.org/get-files/90/pharo-vm-Darwin-arm64-latest.zip"
    export FAKE_OS=Linux FAKE_ARCH=aarch64
    run_lib 'vm_url 130 stable'
    assert_output "https://files.pharo.org/get-files/130/pharo-vm-Linux-aarch64-stable.zip"
}

@test "VM URLs for Pharo 8 and older use the old names, with 32 or 64 bits from the image format" {
    run_lib 'vm_url 80 stable 68021; vm_url 70 stable 6521'
    assert_output "https://files.pharo.org/get-files/80/pharo64-mac-stable.zip
https://files.pharo.org/get-files/70/pharo32-mac-stable.zip"
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    run_lib 'vm_url 80 latest 68021'
    assert_output "https://files.pharo.org/get-files/80/pharo64-linux-latest.zip"
}

@test "VM URLs follow the filesServer setting" {
    write_config "filesServer=https://mirror.example"
    run_lib 'vm_url 140 stable'
    assert_output "https://mirror.example/get-files/140/pharo-vm-Darwin-arm64-stable.zip"
}

@test "vm_install downloads the stable VM matching pharo.version into pharo-vm/" {
    serve_pharo 130
    create_image Old --version 130 --no-vm
    run_lib "vm_install '$IMAGES_DIR/Old' && vm_present '$IMAGES_DIR/Old' && echo present"
    assert_success
    assert_output --partial "Downloading the stable VM for Pharo 13: https://files.pharo.org/get-files/130/pharo-vm-Darwin-arm64-stable.zip"
    assert_output --partial present
    [ -x "$IMAGES_DIR/Old/pharo-vm/Pharo.app/Contents/MacOS/Pharo" ]
    [ ! -e "$IMAGES_DIR/Old/pharo-vm.zip" ]
}

@test "vmStatus=latest downloads the latest VM build" {
    serve_pharo 140
    serve_vm 140 Darwin arm64 latest
    write_config "vmStatus=latest"
    create_image Img --no-vm
    run_lib "vm_install '$IMAGES_DIR/Img'"
    assert_success
    run curl_requests
    assert_output "https://files.pharo.org/get-files/140/pharo-vm-Darwin-arm64-latest.zip"
}

@test "falls back to the latest VM when there is no stable one (Linux on ARM)" {
    export FAKE_OS=Linux FAKE_ARCH=aarch64
    serve_pharo 140
    create_image Img --no-vm
    run_lib "vm_install '$IMAGES_DIR/Img'"
    assert_success
    assert_output --partial "no stable VM for this platform; trying the latest build"
    [ -x "$IMAGES_DIR/Img/pharo-vm/pharo" ]
    run curl_requests
    assert_output "https://files.pharo.org/get-files/140/pharo-vm-Linux-aarch64-stable.zip
https://files.pharo.org/get-files/140/pharo-vm-Linux-aarch64-latest.zip"
}

@test "fails cleanly when no VM exists at all" {
    create_image Img --version 999 --no-vm
    run_lib "vm_install '$IMAGES_DIR/Img'"
    assert_failure
    assert_output --partial "could not download a VM for Pharo 999"
    [ ! -e "$IMAGES_DIR/Img/pharo-vm" ]
    [ ! -e "$IMAGES_DIR/Img/pharo-vm.zip" ]
}

@test "an image without pharo.version cannot get a VM" {
    create_image Img --no-vm --no-version
    run_lib "vm_install '$IMAGES_DIR/Img'"
    assert_failure
    assert_output --partial "cannot choose a VM for 'Img': it has no pharo.version file"
}

@test "the VM path is the one for this OS" {
    run_lib "vm_binary /x/Img"
    assert_output "/x/Img/pharo-vm/Pharo.app/Contents/MacOS/Pharo"
    export FAKE_OS=Linux FAKE_ARCH=x86_64
    run_lib "vm_binary /x/Img"
    assert_output "/x/Img/pharo-vm/pharo"
}
