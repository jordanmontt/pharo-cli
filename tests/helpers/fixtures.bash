# Fixtures: fake images, templates and VMs, built in the sandbox for each test.
# Zips are made with the real zip tool (outside the sandbox PATH).

FAKE_SERVER="files.pharo.org"

# Writes a fake .image file: the 4 bytes of the 64-bit image format (68021,
# little endian) and some filler.
fake_image_file() {
    printf '\265\011\001\000fake image' >"$1"
}

# Puts the real sources.list (tests/fixtures/sources.ston) on the fake server.
serve_catalogue() {
    mkdir -p "$FAKE_HTTP_ROOT/$FAKE_SERVER/pharo-launcher"
    cp "$PROJECT_ROOT/tests/fixtures/sources.ston" "$FAKE_HTTP_ROOT/$FAKE_SERVER/pharo-launcher/sources.list"
}

# Builds a template zip at the server path $2 for the Pharo version $1, laid
# out like the official ones (image, changes, sources and pharo.version at
# the top). Options after $2: --folder <name> puts the files in a folder;
# --no-version leaves out pharo.version.
serve_template() {
    local version="$1" path="$2" folder="" with_version=true staging content
    shift 2
    while [ $# -gt 0 ]; do
        case "$1" in
            --folder) folder="$2"; shift ;;
            --no-version) with_version=false ;;
        esac
        shift
    done
    staging=$(mktemp -d "$BATS_TEST_TMPDIR/template.XXXXXX")
    content="$staging"
    [ -n "$folder" ] && content="$staging/$folder" && mkdir -p "$content"
    fake_image_file "$content/Pharo$((version / 10)).0-SNAPSHOT-64bit-abc123.image"
    echo "changes" >"$content/Pharo$((version / 10)).0-SNAPSHOT-64bit-abc123.changes"
    echo "sources" >"$content/Pharo$((version / 10)).0-64bit-abc123.sources"
    [ "$with_version" = true ] && echo "$version" >"$content/pharo.version"
    mkdir -p "$(dirname "$FAKE_HTTP_ROOT/$path")"
    (cd "$staging" && zip -qr "$FAKE_HTTP_ROOT/$path" .)
    rm -rf "$staging"
}

# Writes the fake VM layout for the OS $2 (Darwin or Linux) into the folder $1.
fake_vm_layout() {
    local dir="$1" os="$2"
    if [ "$os" = Darwin ]; then
        mkdir -p "$dir/Pharo.app/Contents/MacOS"
        cp "$PROJECT_ROOT/tests/fakes/vm" "$dir/Pharo.app/Contents/MacOS/Pharo"
    else
        mkdir -p "$dir/lib"
        cp "$PROJECT_ROOT/tests/fakes/vm" "$dir/pharo"
    fi
}

# Builds a VM zip at the server path $1 for the OS $2.
serve_vm_at() {
    local path="$1" os="$2" staging
    staging=$(mktemp -d "$BATS_TEST_TMPDIR/vm.XXXXXX")
    fake_vm_layout "$staging" "$os"
    mkdir -p "$(dirname "$FAKE_HTTP_ROOT/$path")"
    (cd "$staging" && zip -qr "$FAKE_HTTP_ROOT/$path" .)
    rm -rf "$staging"
}

# Builds the VM zip for the Pharo version $1, OS $2, CPU $3 and status $4.
serve_vm() {
    serve_vm_at "$FAKE_SERVER/get-files/$1/pharo-vm-$2-$3-$4.zip" "$2"
}

# Serves everything needed to create a Pharo image of the version $1 (e.g.
# 140): its template and VMs for every supported platform, with only a latest
# VM for Linux on ARM (as on the real server).
serve_pharo() {
    local version="$1"
    serve_template "$version" "$FAKE_SERVER/image/$version/latest-64.zip"
    serve_vm "$version" Darwin arm64 stable
    serve_vm "$version" Darwin x86_64 stable
    serve_vm "$version" Linux x86_64 stable
    serve_vm "$version" Linux aarch64 latest
}

# Creates the image folder $1 in the images folder directly (version $2,
# default 140). Options: --no-vm, --no-version, --linux-vm, --file <base>
# (name of the .image file, default the image name).
create_image() {
    local name="$1" version=140 vm=Darwin with_version=true base dir
    shift
    base="$name"
    while [ $# -gt 0 ]; do
        case "$1" in
            --version) version="$2"; shift ;;
            --no-vm) vm="" ;;
            --linux-vm) vm=Linux ;;
            --no-version) with_version=false ;;
            --file) base="$2"; shift ;;
        esac
        shift
    done
    dir="$IMAGES_DIR/$name"
    mkdir -p "$dir"
    fake_image_file "$dir/$base.image"
    echo "changes" >"$dir/$base.changes"
    [ "$with_version" = true ] && echo "$version" >"$dir/pharo.version"
    [ -n "$vm" ] && fake_vm_layout "$dir/pharo-vm" "$vm"
    return 0
}

# Writes metadata into the image folder named $1: key=value pairs.
set_image_metadata() {
    local name="$1"
    shift
    printf '%s\n' "$@" >>"$IMAGES_DIR/$name/.pharo-cli"
}
