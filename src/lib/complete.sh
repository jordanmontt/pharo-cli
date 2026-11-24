#!/usr/bin/env bash
# Shell completion. completions/pharo.bash calls 'pharo __complete <index>
# <words...>', where <index> is the position of the word being completed in
# <words...> (the whole command line). This prints the candidates, one per
# line. A line __files__ asks the shell to complete file names instead.
# Everything comes from the command headers, so new commands, options and
# argument kinds complete without touching the shell scripts.

# The VM options (from Pharo 14 VM --help) offered after --vm-arg.
COMPLETE_VM_ARGS="--headless --worker --logLevel= --maxFramesToLog= --maxOldSpaceSize= --codeSize= --edenSize= --maxSlotsForNewSpaceAlloc= --minPermSpaceSize= --stackPageSize= --workingDirectory= --avoidSearchingSegmentsWithPinnedObjects"

# Prints the words of $2... that start with the prefix $1.
complete_filter() {
    local prefix="$1" word
    shift
    for word in "$@"; do
        case "$word" in
            "$prefix"*) printf '%s\n' "$word" ;;
        esac
    done
}

# Prints the lines read from stdin that start with the prefix $1.
complete_filter_lines() {
    local line
    while IFS= read -r line; do
        case "$line" in
            "$1"*) printf '%s\n' "$line" ;;
        esac
    done
}

# Prints the candidates for an argument of the kind $1 starting with $2.
complete_kind() {
    local kind="$1" prefix="$2"
    case "$kind" in
        image) images_list | complete_filter_lines "$prefix" ;;
        template) complete_templates | complete_filter_lines "$prefix" ;;
        command) registry_commands | complete_filter_lines "$prefix" ;;
        config-key) config_keys | complete_filter_lines "$prefix" ;;
        vm-arg)
            # shellcheck disable=SC2086 # the list is split on spaces
            complete_filter "$prefix" $COMPLETE_VM_ARGS
            ;;
        file) echo "__files__" ;;
    esac
    return 0
}

# Template names for completion: the keywords, then the ids in the cached
# list. The list is not downloaded: completion must not wait for the network.
complete_templates() {
    local file
    printf '%s\n' stable latest
    file=$(templates_cache_file)
    [ -f "$file" ] || return 0
    templates_parse "$file" | cut -d "$PHARO_CLI_SEP" -f 1
}

# Completes the config command: action, then key, then value. $1 is the
# position of the argument being completed, $2 its prefix, then the
# arguments before it.
complete_config() {
    local position="$1" prefix="$2" action="${3:-}" key="${4:-}"
    case "$position" in
        1) complete_filter "$prefix" list get set unset reset ;;
        2)
            case "$action" in
                get | set | unset) config_keys | complete_filter_lines "$prefix" ;;
            esac
            ;;
        3)
            if [ "$action" = set ] && config_is_key "$key"; then
                config_suggested_values "$key" | complete_filter_lines "$prefix"
            fi
            ;;
    esac
    return 0
}

# Succeeds when the word $2 is an option of the command $1 that takes a value.
complete_option_takes_value() {
    registry_options "$1" | awk -F "$PHARO_CLI_SEP" -v word="$2" '
        $2 != "" { n = split($1, flags, " "); for (i = 1; i <= n; i++) if (flags[i] == word) found = 1 }
        END { exit !found }'
}

# The kind of value the option $2 of the command $1 takes. Fails when it
# takes none.
complete_option_kind() {
    registry_options "$1" | awk -F "$PHARO_CLI_SEP" -v word="$2" '
        $2 != "" { n = split($1, flags, " "); for (i = 1; i <= n; i++) if (flags[i] == word) { kind = $2; sub(/^[^:]*:/, "", kind); print kind; found = 1; exit } }
        END { exit !found }'
}

# Entry point: $1 is the index of the word to complete, then the words.
complete_words() {
    local index="$1" current command previous kind position i word custom
    shift
    local -a words positionals
    words=("$@")
    positionals=()
    current="${words[$index]:-}"
    current="${current//\\/}"
    if [ "$index" -le 1 ]; then
        case "$current" in
            -*) complete_filter "$current" -h --help -v --version ;;
            *) registry_commands | complete_filter_lines "$current" ;;
        esac
        return 0
    fi
    command=$(registry_resolve "${words[1]}") || return 0
    previous="${words[$((index - 1))]}"

    # The value of an option that takes one.
    if kind=$(complete_option_kind "$command" "$previous"); then
        complete_kind "$kind" "$current"
        return 0
    fi

    if [ "${current#-}" != "$current" ]; then
        {
            registry_options "$command" | cut -d "$PHARO_CLI_SEP" -f 1 | tr ' ' '\n'
            printf '%s\n' -h --help
        } | complete_filter_lines "$current"
        return 0
    fi

    # Collect the positional arguments before the current word.
    position=1
    i=2
    while [ "$i" -lt "$index" ]; do
        word="${words[$i]}"
        if complete_option_takes_value "$command" "$word"; then
            i=$((i + 1))
        elif [ "${word#-}" = "$word" ]; then
            positionals[${#positionals[@]}]="$word"
            position=$((position + 1))
        fi
        i=$((i + 1))
    done

    custom=$(registry_value "$command" complete)
    if [ -n "$custom" ]; then
        "$custom" "$position" "$current" ${positionals[@]+"${positionals[@]}"}
        return 0
    fi
    kind=$(registry_arguments "$command" | sed -n "${position}p" | cut -d "$PHARO_CLI_SEP" -f 2)
    complete_kind "$kind" "$current"
}
