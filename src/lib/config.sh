#!/usr/bin/env bash
# Configuration. Every setting has a built-in default (the table below). A
# value in the user's config file overrides it, and an environment variable
# PHARO_CLI_<KEY> (imagesDir -> PHARO_CLI_IMAGES_DIR) overrides both.
#
# The config file holds one "key=value" line per setting. Lines starting with
# # are comments. Values are taken literally: there is no quoting or expansion,
# except a leading ~ in paths.

# The settings, one "key|default|type|description" line each. The type is one
# of: path, url, int, bool, text, template, or enum:<value>,<value>,...
config_table() {
    cat <<'EOF'
imagesDir|~/Documents/PharoCliImages|path|Folder that holds one sub-folder per image.
defaultTemplate|stable|template|Template used by 'pharo new' when none is given: stable, latest, a Pharo version such as 14, or a template id.
vmStatus|stable|enum:stable,latest|Which VM build to download: the released one (stable) or the newest nightly build (latest).
openMode|foreground|enum:foreground,background|Whether 'pharo open' runs the VM in this terminal or in the background.
autoOpenOnNew|true|bool|Whether 'pharo new' opens the image once it is created.
vmArgs||text|Arguments always passed to the VM, separated by spaces.
picker|auto|enum:auto,fzf,select|How to choose an image when none is named: fzf, a numbered menu (select), or fzf when installed (auto).
templatesUrl|https://files.pharo.org/pharo-launcher/sources.list|url|Template list in Pharo Launcher's sources.list format.
templatesCacheTtl|86400|int|Seconds before the template list is downloaded again.
filesServer|https://files.pharo.org|url|Server for Pharo images and VMs (change it to use a mirror).
EOF
}

# The config file path.
config_file() {
    printf '%s/pharo-cli/config\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Lists the setting keys.
config_keys() {
    config_table | cut -d '|' -f 1
}

# Succeeds when $1 is a setting key.
config_is_key() {
    config_keys | grep -x -- "$1" >/dev/null
}

# Prints the field $2 (2 default, 3 type, 4 description) of the key $1.
config_field() {
    config_table | awk -F '|' -v key="$1" -v field="$2" '$1 == key { print $field }'
}

# The environment variable that overrides the key $1, e.g. PHARO_CLI_IMAGES_DIR.
config_env_name() {
    printf 'PHARO_CLI_%s\n' "$(printf '%s' "$1" | sed 's/\([A-Z]\)/_\1/g' | tr '[:lower:]' '[:upper:]')"
}

# Prints the value of the key $1 stored in the config file. Fails when the
# file does not set it.
config_file_value() {
    local file
    file=$(config_file)
    [ -f "$file" ] || return 1
    awk -v key="$1" '
        /^[[:space:]]*#/ { next }
        index($0, "=") > 0 && substr($0, 1, index($0, "=") - 1) == key { value = substr($0, index($0, "=") + 1); found = 1 }
        END { if (found) print value; else exit 1 }
    ' "$file"
}

# Where the value of the key $1 comes from: env, file or default.
config_origin() {
    local env_name
    env_name=$(config_env_name "$1")
    if [ -n "${!env_name:-}" ]; then
        echo env
    elif config_file_value "$1" >/dev/null; then
        echo file
    else
        echo default
    fi
}

# Prints the raw value of the key $1 (no ~ expansion).
config_raw() {
    local env_name
    env_name=$(config_env_name "$1")
    if [ -n "${!env_name:-}" ]; then
        printf '%s\n' "${!env_name}"
    elif ! config_file_value "$1"; then
        config_field "$1" 2
    fi
}

# Prints the effective value of the key $1. Paths get their ~ expanded.
config_get() {
    local value
    value=$(config_raw "$1")
    if [ "$(config_field "$1" 3)" = path ]; then
        expand_home "$value"
    else
        printf '%s\n' "$value"
    fi
}

# Checks that $2 is a valid value for the key $1. Prints why it is not on
# stderr and fails otherwise.
config_validate() {
    local key="$1" value="$2" type
    type=$(config_field "$key" 3)
    case "$value" in
        *"
"*)
            echo "values cannot span several lines" >&2
            return 1
            ;;
    esac
    case "$type" in
        path | text | template)
            if [ "$type" != text ] && [ -z "$value" ]; then
                echo "'$key' cannot be empty" >&2
                return 1
            fi
            ;;
        url)
            case "$value" in
                http://* | https://* | file://*) ;;
                *)
                    echo "'$key' must be an http(s) or file URL" >&2
                    return 1
                    ;;
            esac
            ;;
        int)
            if ! is_number "$value"; then
                echo "'$key' must be a whole number" >&2
                return 1
            fi
            ;;
        bool)
            case "$value" in
                true | false) ;;
                *)
                    echo "'$key' must be true or false" >&2
                    return 1
                    ;;
            esac
            ;;
        enum:*)
            if ! printf '%s\n' "${type#enum:}" | tr ',' '\n' | grep -x -- "$value" >/dev/null; then
                echo "'$key' must be one of: $(printf '%s' "${type#enum:}" | sed 's/,/, /g')" >&2
                return 1
            fi
            ;;
    esac
}

# The values offered by completion for the key $1.
config_suggested_values() {
    local type
    type=$(config_field "$1" 3)
    case "$type" in
        bool) printf '%s\n' true false ;;
        enum:*) printf '%s\n' "${type#enum:}" | tr ',' '\n' ;;
        template) printf '%s\n' stable latest ;;
    esac
}

# Writes the config file without the key $1, keeping comments and other keys.
config_remove_key() {
    local file tmp
    file=$(config_file)
    [ -f "$file" ] || return 0
    tmp="$file.tmp.$$"
    awk -v key="$1" 'index($0, "=") == 0 || substr($0, 1, index($0, "=") - 1) != key' "$file" >"$tmp" &&
        mv "$tmp" "$file"
}

# Stores value $2 for the key $1 in the config file.
config_set() {
    local file
    file=$(config_file)
    mkdir -p "$(dirname "$file")" || return 1
    config_remove_key "$1" || return 1
    printf '%s=%s\n' "$1" "$2" >>"$file"
}

# Removes the key $1 from the config file, so its default applies again.
config_unset() {
    config_remove_key "$1"
}

# Deletes the config file, so every key is back to its default.
config_reset() {
    rm -f "$(config_file)"
}
