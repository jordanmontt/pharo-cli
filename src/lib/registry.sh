#!/usr/bin/env bash
# The command registry. Every command lives in src/commands/<name>.sh and
# starts with a header of "# @tag value" lines that describe it:
#
#   # @command open                     the command name (required, first)
#   # @alias o                          a short alias (repeatable)
#   # @summary Open an image            one line for the command list (required)
#   # @description Longer text          a paragraph line (repeatable)
#   # @arg [image:image] Description    a positional argument: <name:kind> is
#                                       required, [name:kind] optional, a
#                                       trailing ... makes it repeatable
#   # @option -b --background Desc      a flag; a <value:kind> after the flags
#                                       means the option takes a value
#   # @example pharo open foo | Desc    a usage example and what it does
#   # @complete function_name           a custom completion function
#
# The kind after the colon tells the completion what to offer (image,
# template, config-key, file, ...). Dispatch, help, the man page, the README
# and the shell completion are all generated from these headers.

PHARO_CLI_REGISTRY=""

# Reads the headers of every command file into PHARO_CLI_REGISTRY, one
# "command<TAB>tag<TAB>value" line per header line.
registry_load() {
    PHARO_CLI_REGISTRY=$(awk '
        FNR == 1 { command = "" }
        /^# @[a-z]+( |$)/ {
            line = substr($0, 4)
            space = index(line, " ")
            if (space == 0) { tag = line; value = "" }
            else { tag = substr(line, 1, space - 1); value = substr(line, space + 1) }
            sub(/^ +/, "", value)
            if (tag == "command") command = value
            if (command != "") print command "\t" tag "\t" value
        }
    ' "$PHARO_CLI_ROOT"/src/commands/*.sh)
}

# Lists the command names, in file name order.
registry_commands() {
    printf '%s\n' "$PHARO_CLI_REGISTRY" | awk -F '\t' '$2 == "command" { print $1 }'
}

# Prints every value of the tag $2 for the command $1, one per line.
registry_values() {
    printf '%s\n' "$PHARO_CLI_REGISTRY" |
        awk -F '\t' -v command="$1" -v tag="$2" '$1 == command && $2 == tag { print $3 }'
}

# Prints the first value of the tag $2 for the command $1.
registry_value() {
    registry_values "$1" "$2" | sed -n 1p
}

# Prints the command named or aliased $1. Fails when there is none.
registry_resolve() {
    local resolved
    resolved=$(printf '%s\n' "$PHARO_CLI_REGISTRY" |
        awk -F '\t' -v word="$1" '!found && ($2 == "command" || $2 == "alias") && $3 == word { print $1; found = 1 }')
    [ -n "$resolved" ] || return 1
    printf '%s\n' "$resolved"
}

# The name of the shell function that implements the command $1.
registry_function() {
    printf 'cmd_%s\n' "$1" | tr '-' '_'
}

# Prints the options of the command $1 as "flags<SEP>value<SEP>description"
# lines, where SEP is PHARO_CLI_SEP, flags is a space separated list and value
# is "name:kind" or empty for a plain flag.
registry_options() {
    registry_values "$1" option | awk -v OFS="$PHARO_CLI_SEP" '
        {
            flags = ""; value = ""; i = 1
            while (i <= NF && substr($i, 1, 1) == "-") { flags = flags (flags == "" ? "" : " ") $i; i++ }
            if (i <= NF && substr($i, 1, 1) == "<") { value = substr($i, 2, length($i) - 2); i++ }
            description = ""
            for (; i <= NF; i++) description = description (description == "" ? "" : " ") $i
            print flags, value, description
        }'
}

# Prints the positional arguments of the command $1 as
# "name<SEP>kind<SEP>required|optional<SEP>repeat|once<SEP>description" lines.
registry_arguments() {
    registry_values "$1" arg | awk -v OFS="$PHARO_CLI_SEP" '
        {
            spec = $1
            required = substr(spec, 1, 1) == "<" ? "required" : "optional"
            repeat = "once"
            if (substr(spec, length(spec) - 2) == "...") { repeat = "repeat"; spec = substr(spec, 1, length(spec) - 3) }
            spec = substr(spec, 2, length(spec) - 2)
            colon = index(spec, ":")
            if (colon == 0) { name = spec; kind = "none" }
            else { name = substr(spec, 1, colon - 1); kind = substr(spec, colon + 1) }
            description = ""
            for (i = 2; i <= NF; i++) description = description (description == "" ? "" : " ") $i
            print name, kind, required, repeat, description
        }'
}

# The usage line of the command $1, built from its arguments and options.
registry_usage() {
    local command="$1" usage name required repeat
    usage="$PHARO_CLI_COMMAND_NAME $command"
    while IFS="$PHARO_CLI_SEP" read -r name _ required repeat _; do
        [ -n "$name" ] || continue
        if [ "$required" = required ]; then
            usage="$usage <$name>"
        else
            usage="$usage [<$name>]"
        fi
        [ "$repeat" = repeat ] && usage="$usage..."
    done <<EOF
$(registry_arguments "$command")
EOF
    if [ -n "$(registry_values "$command" option)" ]; then
        usage="$usage [options]"
    fi
    printf '%s\n' "$usage"
}
