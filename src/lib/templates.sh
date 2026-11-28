#!/usr/bin/env bash
# Image templates. The catalogue is Pharo Launcher's sources.list (STON
# format), downloaded from the templatesUrl setting and cached for
# templatesCacheTtl seconds. Only its plain URL entries are used; each gets an
# id derived from its name, so it can be typed and completed:
# "Pharo 14.0 - 64bit (stable)" becomes pharo-14.0-64bit-stable.
#
# A template can be named in four ways:
#   stable     the official Pharo release marked "(stable)" in the catalogue
#   latest     the newest official Pharo version in the catalogue
#   14         a Pharo version: the newest build of Pharo 14, straight from
#              filesServer, without the catalogue
#   <id>       any template id from the catalogue (see 'pharo templates')

templates_cache_dir() {
    printf '%s/pharo-cli\n' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

templates_cache_file() {
    printf '%s/sources.list\n' "$(templates_cache_dir)"
}

# Downloads the catalogue into the cache.
templates_refresh() {
    local dir file tmp
    dir=$(templates_cache_dir)
    file=$(templates_cache_file)
    tmp="$file.tmp.$$"
    mkdir -p "$dir" || return 1
    if ! http_get "$(config_get templatesUrl)" >"$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$file" && date +%s >"$file.fetched"
}

# Makes sure a catalogue is cached and fresh enough. When it cannot be
# downloaded, an older cached copy is used with a warning.
templates_ensure() {
    local file fetched now ttl
    file=$(templates_cache_file)
    if [ -f "$file" ] && [ -f "$file.fetched" ]; then
        IFS= read -r fetched <"$file.fetched" || fetched=0
        is_number "$fetched" || fetched=0
        now=$(date +%s)
        ttl=$(config_get templatesCacheTtl)
        [ $((now - fetched)) -lt "$ttl" ] && return 0
    fi
    templates_refresh && return 0
    if [ -f "$file" ]; then
        warn "could not download the template list; using the cached copy"
        return 0
    fi
    die_with "$EXIT_DOWNLOAD" "could not download the template list from $(config_get templatesUrl)"
}

# The template id for the template name $1.
templates_id() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' |
        sed -e 's/[^a-z0-9.]\{1,\}/-/g' -e 's/^-//' -e 's/-$//'
}

# Lists the catalogue, downloading it when the cache is missing or stale.
templates_list() {
    templates_ensure
    templates_parse "$(templates_cache_file)"
}

# Lists the URL entries of the sources.list file $1 as "id<SEP>name<SEP>url"
# lines, in catalogue order and without duplicate ids.
templates_parse() {
    awk -v OFS="$PHARO_CLI_SEP" '
        function ston_string(line) {
            sub(/^[^'\'']*'\''/, "", line)
            sub(/'\''[^'\'']*$/, "", line)
            gsub(/\\'\''/, "'\''", line)
            return line
        }
        /#type[ \t]*:/ { is_url = ($0 ~ /#type[ \t]*:[ \t]*#URL[ \t]*,?[ \t]*$/); name = ""; next }
        is_url && /#name[ \t]*:/ { name = ston_string($0); next }
        is_url && /#url[ \t]*:/ && name != "" { print name, ston_string($0); is_url = 0 }
    ' "$1" |
        while IFS="$PHARO_CLI_SEP" read -r name url; do
            printf '%s%s%s%s%s\n' "$(templates_id "$name")" "$PHARO_CLI_SEP" "$name" "$PHARO_CLI_SEP" "$url"
        done | awk -F "$PHARO_CLI_SEP" '!seen[$1]++'
}

# The image URL for the Pharo version $1 (14 or 140 both mean Pharo 14).
templates_version_url() {
    local version="$1"
    [ "$version" -lt 100 ] && version=$((version * 10))
    printf '%s/image/%s/latest-64.zip\n' "$(config_get filesServer)" "$version"
}

# Succeeds when $1 names a template (see the top of this file).
templates_exists() {
    templates_resolve "$1" >/dev/null 2>&1
}

# Prints "label<SEP>url" for the template named $1. Fails when there is none.
templates_resolve() {
    local spec="$1" entries
    if is_number "$spec"; then
        printf 'Pharo %s%s%s\n' "$spec" "$PHARO_CLI_SEP" "$(templates_version_url "$spec")"
        return 0
    fi
    entries=$(templates_list) || return 1
    case "$spec" in
        stable)
            printf '%s\n' "$entries" |
                awk -F "$PHARO_CLI_SEP" -v OFS="$PHARO_CLI_SEP" '!found && $2 ~ /^Pharo [0-9.]+ - 64bit \(stable\)$/ { print $2, $3; found = 1 } END { exit !found }'
            ;;
        latest)
            printf '%s\n' "$entries" |
                awk -F "$PHARO_CLI_SEP" -v OFS="$PHARO_CLI_SEP" '
                    $2 ~ /^Pharo [0-9]+\.[0-9]+ - 64bit/ {
                        version = substr($2, 7) + 0
                        if (version > best) { best = version; line = $2 OFS $3 }
                    }
                    END { if (line == "") exit 1; print line }'
            ;;
        *)
            printf '%s\n' "$entries" |
                awk -F "$PHARO_CLI_SEP" -v OFS="$PHARO_CLI_SEP" -v spec="$spec" '!found && ($1 == spec || $2 == spec) { print $2, $3; found = 1 } END { exit !found }'
            ;;
    esac
}
