#!/usr/bin/env bash
# Help, generated from the command headers (see registry.sh) and the settings
# table (see config.sh). The same data is rendered three ways: as terminal
# help, as the pharo(1) man page and as the README command reference.

PHARO_CLI_DESCRIPTION="pharo-cli is a command-line manager for Pharo images. It creates images from the official templates, opens them with the right VM, and lets you list, rename, duplicate and remove them. Each image lives in its own folder with its own VM."

# Prints "name, alias, alias" for the command $1.
help_names() {
    local names="$1" alias
    while IFS= read -r alias; do
        [ -n "$alias" ] && names="$names, $alias"
    done <<EOF
$(registry_values "$1" alias)
EOF
    printf '%s\n' "$names"
}

# The flags of an option line ("-b --background") as "-b, --background", with
# its value appended ("--vm-arg <arg>").
help_option_label() {
    local flags="$1" value="$2" label
    label=$(printf '%s' "$flags" | sed 's/ /, /g')
    [ -n "$value" ] && label="$label <${value%%:*}>"
    printf '%s\n' "$label"
}

# The width the help is wrapped to.
HELP_WIDTH=80

# Prints the text $3 wrapped to HELP_WIDTH columns. The first line starts
# with $1, the others with $2 spaces. A word longer than the space left (a
# URL) is not split.
help_wrap() {
    printf '%s\n' "$3" | awk -v first_prefix="$1" -v indent="$2" -v max="$HELP_WIDTH" '
        function out(    row) {
            row = (first ? first_prefix : sprintf("%" indent "s", "")) line
            sub(/ +$/, "", row)
            print row
            first = 0
            line = ""
        }
        {
            first = 1
            line = ""
            for (i = 1; i <= NF; i++) {
                if (line != "" && length(line) + 1 + length($i) > max - indent) out()
                line = line == "" ? $i : line " " $i
            }
            out()
        }'
}

# Prints "  label   text" with the text aligned at column $3 and wrapped. A
# label too long for its column gets a line of its own.
help_row() {
    local label="$1" text="$2" width="$3"
    if [ "${#label}" -ge $((width - 2)) ]; then
        printf '  %s\n' "$label"
        label=""
    fi
    help_wrap "$(printf '  %-*s' $((width - 2)) "$label")" "$width" "$text"
}

help_version() {
    printf '%s %s\n' "$PHARO_CLI_PROGRAM_NAME" "$(pharo_cli_version)"
}

# The full help: commands, settings and every example.
help_overview() {
    local command
    help_version
    echo
    help_wrap "" 0 "$PHARO_CLI_DESCRIPTION"
    echo
    printf 'Usage: %s <command> [arguments] [options]\n' "$PHARO_CLI_COMMAND_NAME"
    echo
    echo "Commands:"
    for command in $(registry_commands); do
        help_row "$(help_names "$command")" "$(registry_value "$command" summary)" 22
    done
    echo
    echo "Global options:"
    help_row "-h, --help" "Show this help. '$PHARO_CLI_COMMAND_NAME help <command>' shows one command." 22
    help_row "-v, --version" "Show the version." 22
    echo
    printf "Settings (change them with '%s config set <key> <value>'):\n" "$PHARO_CLI_COMMAND_NAME"
    help_settings
    echo
    echo "Examples:"
    # shellcheck disable=SC2046 # one word per command name
    help_examples $(registry_commands)
    echo
    help_wrap "" 0 "Run '$PHARO_CLI_COMMAND_NAME help <command>' for one command's options, or 'man $PHARO_CLI_COMMAND_NAME'."
    printf 'Source and issues: https://github.com/%s (MIT License)\n' "$PHARO_CLI_REPOSITORY"
}

# Prints each setting with its description, its default on the next line,
# and a blank line between settings.
help_settings() {
    local key default description first=true
    while IFS='|' read -r key default _ description; do
        [ -n "$default" ] || default="(empty)"
        [ "$first" = true ] || echo
        first=false
        help_row "$key" "$description" 22
        # Not wrapped: a default is easier to read, and to copy, in one piece.
        printf '%22s%s\n' "" "Default: $default"
    done <<EOF
$(config_table)
EOF
}

# Prints the examples of the commands $@, each as a comment with its
# description above the command line, separated by blank lines.
help_examples() {
    local command line first=true
    for command in "$@"; do
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            [ "$first" = true ] || echo
            first=false
            printf '  # %s\n  %s\n' "${line#* | }" "${line%% | *}"
        done <<EOF
$(registry_values "$command" example)
EOF
    done
}

# The help of the command $1.
help_command() {
    local command="$1" line name description flags value aliases
    printf 'Usage: %s\n' "$(registry_usage "$command")"
    echo
    help_wrap "" 0 "$(registry_value "$command" summary)"
    while IFS= read -r line; do
        [ -n "$line" ] && { echo; help_wrap "" 0 "$line"; }
    done <<EOF
$(registry_values "$command" description)
EOF
    aliases=$(registry_values "$command" alias | tr '\n' ' ' | sed 's/ $//; s/ /, /g')
    if [ -n "$aliases" ]; then
        echo
        printf 'Aliases: %s\n' "$aliases"
    fi
    if [ -n "$(registry_values "$command" arg)" ]; then
        echo
        echo "Arguments:"
        while IFS="$PHARO_CLI_SEP" read -r name _ _ _ description; do
            [ -n "$name" ] && help_row "<$name>" "$description" 30
        done <<EOF
$(registry_arguments "$command")
EOF
    fi
    echo
    echo "Options:"
    while IFS="$PHARO_CLI_SEP" read -r flags value description; do
        [ -n "$flags" ] && help_row "$(help_option_label "$flags" "$value")" "$description" 30
    done <<EOF
$(registry_options "$command")
EOF
    help_row "-h, --help" "Show this help." 30
    if [ -n "$(registry_values "$command" example)" ]; then
        echo
        echo "Examples:"
        help_examples "$command"
    fi
}

# Escapes text for roff: backslashes, dashes, and dots or quotes at the start
# of a line.
help_roff() {
    printf '%s\n' "$1" | sed -e 's/\\/\\e/g' -e 's/-/\\-/g' -e "s/^\\([.']\\)/\\\\\\&\\1/"
}

# The pharo(1) man page, in roff.
help_man() {
    local command line name description flags value key default
    printf '.TH PHARO 1 "" "%s %s" "User Commands"\n' "$PHARO_CLI_PROGRAM_NAME" "$(pharo_cli_version)"
    echo ".SH NAME"
    echo 'pharo \- command\-line manager for Pharo images'
    echo ".SH SYNOPSIS"
    echo '.B pharo'
    echo '\fIcommand\fR [\fIarguments\fR] [\fIoptions\fR]'
    echo ".SH DESCRIPTION"
    help_roff "$PHARO_CLI_DESCRIPTION"
    echo ".SH COMMANDS"
    for command in $(registry_commands); do
        printf '.SS "%s"\n' "$(help_roff "$(help_names "$command")")"
        printf '.B %s\n' "$(help_roff "$(registry_usage "$command")")"
        echo ".PP"
        help_roff "$(registry_value "$command" summary)"
        while IFS= read -r line; do
            [ -n "$line" ] && { echo ".PP"; help_roff "$line"; }
        done <<EOF
$(registry_values "$command" description)
EOF
        while IFS="$PHARO_CLI_SEP" read -r name _ _ _ description; do
            [ -n "$name" ] || continue
            echo ".TP"
            printf '.I %s\n' "$(help_roff "<$name>")"
            help_roff "$description"
        done <<EOF
$(registry_arguments "$command")
EOF
        while IFS="$PHARO_CLI_SEP" read -r flags value description; do
            [ -n "$flags" ] || continue
            echo ".TP"
            printf '.B %s\n' "$(help_roff "$(help_option_label "$flags" "$value")")"
            help_roff "$description"
        done <<EOF
$(registry_options "$command")
EOF
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            echo ".TP"
            printf '.B %s\n' "$(help_roff "${line%% | *}")"
            help_roff "${line#* | }"
        done <<EOF
$(registry_values "$command" example)
EOF
    done
    echo ".SH SETTINGS"
    printf 'Settings are changed with \\fB%s config set\\fR \\fIkey value\\fR and stored in\n' "$PHARO_CLI_COMMAND_NAME"
    echo '\fI$XDG_CONFIG_HOME/pharo\-cli/config\fR (\fI~/.config/pharo\-cli/config\fR by default).'
    echo 'An environment variable \fBPHARO_CLI_\fR\fIKEY\fR overrides the file, for example'
    echo '\fBPHARO_CLI_IMAGES_DIR\fR for \fBimagesDir\fR.'
    while IFS='|' read -r key default _ description; do
        [ -n "$default" ] || default="(empty)"
        echo ".TP"
        printf '.B %s\n' "$key"
        help_roff "$description Default: $default"
    done <<EOF
$(config_table)
EOF
    echo ".SH FILES"
    echo ".TP"
    echo '.I ~/.config/pharo\-cli/config'
    echo "User settings."
    echo ".TP"
    echo '.I ~/.cache/pharo\-cli/sources.list'
    echo "Cached template list."
    echo ".TP"
    echo '.I ~/.cache/pharo\-cli/downloads/'
    echo "Cached template and VM zips (see cacheDownloads). Safe to delete; self\\-uninstall removes it."
    echo ".TP"
    echo '.I <imagesDir>/<image>/'
    echo "One folder per image, with its image files, its VM in pharo\\-vm/ and pharo\\-cli metadata in .pharo\\-cli."
    echo ".SH EXIT STATUS"
    echo "These codes are stable: scripts can rely on them."
    while IFS='|' read -r key description; do
        echo ".TP"
        printf '.B %s\n' "$key"
        help_roff "$description"
    done <<EOF
$(help_exit_codes)
EOF
    echo ".SH SEE ALSO"
    printf 'https://github.com/%s\n' "$PHARO_CLI_REPOSITORY"
}

# The exit codes, one "code|meaning" line each, for the man page and
# docs/commands.md. They match the EXIT_* constants in core.sh.
help_exit_codes() {
    cat <<'EOF'
0|Success.
1|A command failed or was cancelled. For 'pharo run', the script or expression failed: the status is the VM's own.
2|The command line was wrong, or a question needed a terminal (no image given, a confirmation without --yes).
3|No such image, script or import source.
4|A download failed.
5|The VM could not be started.
124|'pharo run --timeout' stopped the VM.
EOF
}

# Escapes text for Markdown, where <word> would be read as an HTML tag.
help_md() {
    printf '%s\n' "$1" | sed -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# The command reference in docs/commands.md, in Markdown.
help_markdown() {
    local command line name description flags value aliases
    printf '# Command reference\n\n'
    printf 'Generated from the code by `scripts/gen-docs.sh`. The same help is in `%s help <command>` and `man %s`.\n\n' "$PHARO_CLI_COMMAND_NAME" "$PHARO_CLI_COMMAND_NAME"
    for command in $(registry_commands); do
        printf '## `%s`\n\n' "$command"
        printf '```\n%s\n```\n\n' "$(registry_usage "$command")"
        help_md "$(registry_value "$command" summary)"
        while IFS= read -r line; do
            [ -n "$line" ] && printf '\n%s\n' "$(help_md "$line")"
        done <<EOF
$(registry_values "$command" description)
EOF
        aliases=$(registry_values "$command" alias | sed 's/.*/`&`/' | tr '\n' ' ' | sed 's/ $//; s/ /, /g')
        [ -n "$aliases" ] && printf '\nAliases: %s\n' "$aliases"
        if [ -n "$(registry_values "$command" arg)$(registry_values "$command" option)" ]; then
            printf '\n| Argument or option | Description |\n|---|---|\n'
            while IFS="$PHARO_CLI_SEP" read -r name _ _ _ description; do
                [ -n "$name" ] && printf '| `<%s>` | %s |\n' "$name" "$(help_md "$description")"
            done <<EOF
$(registry_arguments "$command")
EOF
            while IFS="$PHARO_CLI_SEP" read -r flags value description; do
                [ -n "$flags" ] && printf '| `%s` | %s |\n' "$(help_option_label "$flags" "$value")" "$(help_md "$description")"
            done <<EOF
$(registry_options "$command")
EOF
        fi
        if [ -n "$(registry_values "$command" example)" ]; then
            printf '\nExamples:\n\n'
            while IFS= read -r line; do
                [ -n "$line" ] && printf -- '- `%s`: %s\n' "${line%% | *}" "$(help_md "${line#* | }")"
            done <<EOF
$(registry_values "$command" example)
EOF
        fi
        echo
    done
    printf '## Settings\n\n'
    help_markdown_settings
    printf '\n## Exit status\n\n'
    printf 'These codes are stable: scripts can rely on them.\n\n'
    printf '| Code | Meaning |\n|---|---|\n'
    while IFS='|' read -r key description; do
        printf '| `%s` | %s |\n' "$key" "$(help_md "$description")"
    done <<EOF
$(help_exit_codes)
EOF
    help_markdown_scripts
}

# The section of docs/commands.md on using pharo-cli from scripts and agents.
help_markdown_scripts() {
    cat <<'EOF'

## Scripts and agents

pharo-cli works the same for a person and for a program:

- **Nothing waits for an answer without a terminal.** When stdin or stderr is not a terminal, a command that would show the image list or ask a question fails at once with status 2: give the image name, or `--yes`.
- **stdout carries only results**: names, paths, JSON, and the process id of `pharo open --background`. Progress and status messages go to stderr. Without a terminal, each download prints one line when it is done instead of a progress bar; `--quiet` prints nothing but errors and warnings.
- **JSON.** `info`, `list`, `templates`, `config` and `path` take `--json`. Unknown values are `null`; dates are ISO 8601 in UTC.
- **Headless runs.** `pharo run` passes the VM's exit status on. `--save` keeps what the script changed, `--timeout <seconds>` stops a script that hangs (status 124), and `--temporary <template>` runs in a fresh image that is removed afterwards, however the run ends.
- **Downloads are cached** in `~/.cache/pharo-cli/downloads/` and downloaded again only when the server has a newer version, so temporary images are quick to make. The folder is safe to delete.

Setting up an image that starts a server, for example an MCP server, takes two steps: a script that loads the code and registers the server to start when the image starts, saved into the image, then the image started without its UI:

```bash
pharo run MyServer setup.st --save
pharo open MyServer --headless --background
```
EOF
}

# The settings table, in Markdown (in docs/commands.md and README.md).
help_markdown_settings() {
    local key default description
    printf 'Change them with `%s config set <key> <value>`, or with an environment variable `PHARO_CLI_<KEY>` (for example `PHARO_CLI_IMAGES_DIR`).\n\n' "$PHARO_CLI_COMMAND_NAME"
    printf '| Key | Default | Description |\n|---|---|---|\n'
    while IFS='|' read -r key default _ description; do
        if [ -n "$default" ]; then
            default="\`$default\`"
        else
            default="(empty)"
        fi
        printf '| `%s` | %s | %s |\n' "$key" "$default" "$(help_md "$description")"
    done <<EOF
$(config_table)
EOF
}
