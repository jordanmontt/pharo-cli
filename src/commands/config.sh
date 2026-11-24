#!/usr/bin/env bash
# @command config
# @alias c
# @summary Show and change settings.
# @description Actions: list (the default) shows every setting and where its value comes from; get prints one value; set stores a value in the config file; unset removes it so the default applies again; reset removes every stored value, after you confirm.
# @arg [action:config-action] list, get, set, unset or reset.
# @arg [key:config-key] The setting, for get, set and unset.
# @arg [value:config-value] The new value, for set.
# @option -y --yes Do not ask before reset.
# @complete complete_config
# @example pharo config set imagesDir ~/Pharo/images | Keep new images in ~/Pharo/images.
# @example pharo config set vmArgs --logLevel=4 | Pass --logLevel=4 to the VM every time.

cmd_config() {
    local yes=false count=0 action="" key="" value="" reason
    while [ $# -gt 0 ]; do
        # The value of 'config set <key> <value>' is taken as it is, even
        # when it starts with a dash (vmArgs values do).
        if [ "$count" -eq 2 ] && [ "$action" = set ]; then
            count=3
            value="$1"
            shift
            continue
        fi
        case "$1" in
            -y | --yes) yes=true ;;
            *)
                common_option config "$1" || {
                    count=$((count + 1))
                    case "$count" in
                        1) action="$1" ;;
                        2) key="$1" ;;
                        3) value="$1" ;;
                    esac
                }
                ;;
        esac
        shift
    done
    case "${action:-list}" in
        list)
            check_argument_count config 1 "$count"
            config_list
            ;;
        get)
            check_argument_count config 2 "$count"
            config_require_key "$key"
            config_get "$key"
            ;;
        set)
            check_argument_count config 3 "$count"
            config_require_key "$key"
            [ "$count" -eq 3 ] || usage_error "'config set' needs a key and a value" config
            reason=$(config_validate "$key" "$value" 2>&1) || die "invalid value: $reason"
            config_set "$key" "$value" || die "could not write $(config_file)"
            info "$key = $value"
            if [ "$(config_origin "$key")" = env ]; then
                warn "$(config_env_name "$key") is set in the environment and overrides this value"
            fi
            ;;
        unset)
            check_argument_count config 2 "$count"
            config_require_key "$key"
            config_unset "$key" || die "could not write $(config_file)"
            info "$key = $(config_raw "$key") (default)"
            ;;
        reset)
            check_argument_count config 1 "$count"
            if [ "$yes" != true ]; then
                confirm "Reset every setting to its default?" || {
                    info "Cancelled. Settings were not changed."
                    exit "$EXIT_ERROR"
                }
            fi
            config_reset || die "could not remove $(config_file)"
            info "Every setting is back to its default."
            ;;
        *)
            usage_error "unknown config action: $action" config
            ;;
    esac
}

# Dies with a usage error unless $1 is a setting key.
config_require_key() {
    [ -n "$1" ] || usage_error "a setting key is needed. Run '$PHARO_CLI_COMMAND_NAME config' to see them" config
    config_is_key "$1" || usage_error "unknown setting: $1. Run '$PHARO_CLI_COMMAND_NAME config' to see them" config
}

# Prints every setting with its value and where the value comes from.
config_list() {
    local key origin
    for key in $(config_keys); do
        origin=$(config_origin "$key")
        case "$origin" in
            env) origin="from $(config_env_name "$key")" ;;
            file) origin="set" ;;
        esac
        printf '%s\t%s\t(%s)\n' "$key" "$(config_raw "$key")" "$origin"
    done | list_columns
    printf '\nConfig file: %s\n' "$(config_file)"
}
