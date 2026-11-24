#!/usr/bin/env bash
# @command new
# @alias n
# @summary Create an image from a template.
# @description The template is stable (the current Pharo release), latest (the newest Pharo version), a Pharo version such as 14 (its newest build), or a template id from 'pharo templates'. Without a template, the defaultTemplate setting is used.
# @description With one argument, it is read as a template when it is a version, stable, latest or a template id, and as an image name otherwise. Use --template or --name when a name looks like a template.
# @description Without a name, the image is called Pharo<version>-<date and time>. The VM for the image is downloaded with it.
# @arg [template:template] The template to create the image from.
# @arg [name:none] The name of the new image.
# @option -t --template <template:template> The template to create the image from.
# @option -n --name <name:none> The name of the new image.
# @option --open Open the image once it is created (the default, see the autoOpenOnNew setting).
# @option --no-open Do not open the image once it is created.
# @example pharo new | Create an image from the default template (the stable Pharo release).
# @example pharo new 14 | Create an image from the newest Pharo 14 build.
# @example pharo new 14 MyImage | Create a Pharo 14 image named MyImage.
# @example pharo new MyImage | Create an image named MyImage from the default template.
# @example pharo new latest MyImage --no-open | Create MyImage from the newest Pharo version without opening it.
# @example pharo new --name 14 --template stable | Create an image named 14 from the stable template.

cmd_new() {
    local template="" name="" auto_open count=0 first="" second="" resolved label url folder version
    auto_open=$(config_get autoOpenOnNew)
    while [ $# -gt 0 ]; do
        case "$1" in
            -t | --template)
                [ $# -ge 2 ] || usage_error "$1 needs a value" new
                template="$2"
                shift
                ;;
            --template=*) template="${1#--template=}" ;;
            -n | --name)
                [ $# -ge 2 ] || usage_error "$1 needs a value" new
                name="$2"
                shift
                ;;
            --name=*) name="${1#--name=}" ;;
            --open) auto_open=true ;;
            --no-open) auto_open=false ;;
            *)
                common_option new "$1" || {
                    count=$((count + 1))
                    case "$count" in
                        1) first="$1" ;;
                        2) second="$1" ;;
                    esac
                }
                ;;
        esac
        shift
    done
    new_assign_arguments "$count" "$first" "$second"
    [ -n "$template" ] || template=$(config_get defaultTemplate)
    [ -z "$name" ] || image_require_free "$name"

    resolved=$(templates_resolve "$template") ||
        die "unknown template '$template'. Run '$PHARO_CLI_COMMAND_NAME templates' to see them"
    label="${resolved%%"$PHARO_CLI_SEP"*}"
    url="${resolved#*"$PHARO_CLI_SEP"}"

    create_staging
    info "Downloading $label: $url"
    http_download "$url" "$CREATE_STAGING/template.zip" || die "could not download $url"
    folder=$(create_unpack "$CREATE_STAGING/template.zip") || exit "$EXIT_ERROR"
    if [ -z "$name" ]; then
        version=$(image_pharo_version "$folder") || version=""
        name=$(new_default_name "$version" "$template")
    fi
    new_rename_template_files "$folder" "$name"
    create_install "$folder" "$name" "$template"
    image_meta_set "$(image_path "$name")" templateUrl "$url"
    create_cleanup
    vm_install "$(image_path "$name")"
    info "Created the image '$name' in $(image_path "$name")"
    [ "$auto_open" = true ] || return "$EXIT_OK"
    launch_open "$name" "$(config_get openMode)"
}

# Sets template and name (in cmd_new) from the $1 positional arguments $2
# and $3.
new_assign_arguments() {
    local count="$1" first="$2" second="$3"
    check_argument_count new 2 "$count"
    case "$count" in
        2)
            [ -z "$template" ] && [ -z "$name" ] ||
                usage_error "give the template and name either as arguments or with --template and --name" new
            template="$first"
            name="$second"
            ;;
        1)
            if [ -n "$template" ] && [ -n "$name" ]; then
                usage_error "too many arguments for 'new'" new
            elif [ -n "$template" ]; then
                name="$first"
            elif [ -n "$name" ]; then
                template="$first"
            elif templates_exists "$first"; then
                template="$first"
            else
                name="$first"
            fi
            ;;
    esac
}

# The name for an image of the Pharo version $1 (e.g. 140) from the template
# $2: Pharo14-2026-11-24-15h02, with a number appended if it is taken.
new_default_name() {
    local base candidate counter=2
    if [ -n "$1" ]; then
        base="Pharo$(image_version_label "$1" | sed 's/\.0$//')"
    else
        base=$(templates_id "$2")
    fi
    base="$base-$(date +%Y-%m-%d-%Hh%M)"
    candidate="$base"
    while [ -e "$(image_path "$candidate")" ]; do
        candidate="$base-$counter"
        counter=$((counter + 1))
    done
    printf '%s\n' "$candidate"
}

# Renames the .image and .changes files in the unpacked template folder $1 to
# the image name $2. The .sources file keeps its name: the image refers to it.
new_rename_template_files() {
    local folder="$1" name="$2" image
    image=$(image_file "$folder") || return 0
    image_rename_files "$folder" "$(basename "$image" .image)" "$name"
}
