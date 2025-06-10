#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$PROJECT_ROOT/src/image_manager.sh"

  export TEST_DIR=$(mktemp -d)
  export PHARO_IMAGES_DIR="$TEST_DIR/images"
  export LOCAL_VM_DIR="mock_pharo_vm"
  mkdir -p "$PHARO_IMAGES_DIR"
  export DEFAULT_PHARO_VERSION="alpha"

  # Mock fzf
  fzf() { echo "$MOCK_FZF_OUTPUT"; }
  export -f fzf

  # Mock trash
  trash() {
    # skip flags like -F because trash is used with flags
    while [[ "$1" == -* ]]; do
        shift
    done
    local src="$1"
    local dest="$TEST_DIR/trash"
    mkdir -p "$dest"
    mv "$src" "$dest/$(basename "$src")"
  }
  export -f trash

  # Mock curl
  curl() {
    local dest="${@: -1}"
    mkdir -p "$(dirname "$dest")"

    # Simulate image extraction directly
    local image_dir="$PHARO_IMAGES_DIR/test-image"
    mkdir -p "$image_dir"
    touch "$image_dir/test-image.image"
    touch "$image_dir/test-image.changes"
  }
  export -f curl

  # Mock Pharo VM
  mock_pharo_vm() { echo "Mock Pharo VM"; }
  export -f mock_pharo_vm
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "open_image: opens an image successfully" {
  mkdir -p "$PHARO_IMAGES_DIR/test-image"
  touch "$PHARO_IMAGES_DIR/test-image/test.image"
  export MOCK_FZF_OUTPUT="test-image"
  run open_image
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Opening Pharo image:" ]]
  [[ "$output" =~ "/test.image" ]]
  [[ "$output" =~ "location:" ]]
  [[ "$output" =~ "test-image" ]]
  [[ "$output" =~ "Mock Pharo VM" ]]
}

@test "open_image: cancels if fzf returns empty" {
  export MOCK_FZF_OUTPUT=""
  run open_image
  [ "$status" -eq 255 ]
  [ "$output" = "Operation canceled." ]
}

@test "list_all_images: lists images in directory" {
  mkdir -p "$PHARO_IMAGES_DIR/image1" "$PHARO_IMAGES_DIR/image2"
  run list_all_images
  [ "$status" -eq 0 ]
  [[ "$output" =~ "image1" ]]
  [[ "$output" =~ "image2" ]]
}

@test "rename_image: renames image and folder" {
  mkdir -p "$PHARO_IMAGES_DIR/old-name"
  touch "$PHARO_IMAGES_DIR/old-name/old-name.image" "$PHARO_IMAGES_DIR/old-name/old-name.changes"
  export MOCK_FZF_OUTPUT="old-name"
  run rename_image <<< "new-name"
  [ "$status" -eq 0 ]
  [ -d "$PHARO_IMAGES_DIR/new-name" ]
  [ -f "$PHARO_IMAGES_DIR/new-name/new-name.image" ]
  [ -f "$PHARO_IMAGES_DIR/new-name/new-name.changes" ]
  [ ! -d "$PHARO_IMAGES_DIR/old-name" ]
}

@test "remove_image: moves image to trash" {
  mkdir -p "$PHARO_IMAGES_DIR/test-image"
  touch "$PHARO_IMAGES_DIR/test-image/test.image"
  export MOCK_FZF_OUTPUT="test-image"
  run remove_image <<< "y"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Image test-image moved to the Trash successfully" ]]
  [ ! -d "$PHARO_IMAGES_DIR/test-image" ]
  [ ! -f "$PHARO_IMAGES_DIR/test-image/test.image" ]
}

@test "duplicate_image: creates copy with new name" {
  mkdir -p "$PHARO_IMAGES_DIR/original"
  touch "$PHARO_IMAGES_DIR/original/original.image" "$PHARO_IMAGES_DIR/original/original.changes"
  export MOCK_FZF_OUTPUT="original"
  run duplicate_image <<< "copy"
  [ "$status" -eq 0 ]
  [ -d "$PHARO_IMAGES_DIR/copy" ]
  [ -f "$PHARO_IMAGES_DIR/copy/copy.image" ]
  [ -f "$PHARO_IMAGES_DIR/copy/copy.changes" ]
  [ -d "$PHARO_IMAGES_DIR/original" ]
  [ -f "$PHARO_IMAGES_DIR/original/original.image" ]
  [ -f "$PHARO_IMAGES_DIR/original/original.changes" ]
}

@test "install_image: downloads and renames image" {
  export MOCK_FZF_OUTPUT=""
  run install_image "140" <<< "test-image"
  [ "$status" -eq 0 ]
  [ -d "$PHARO_IMAGES_DIR/test-image" ]
  [ -f "$PHARO_IMAGES_DIR/test-image/test-image.image" ]
  [ -f "$PHARO_IMAGES_DIR/test-image/test-image.changes" ]
  [[ "$output" =~ "Opening Pharo image" ]]
}

@test "_open_pharo_: fails if no directory provided" {
  run _open_pharo_ ""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Error, you need to send an image directory as argument" ]]
}