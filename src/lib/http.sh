#!/usr/bin/env bash
# Downloads, through curl. -f makes HTTP errors (404, 500...) fail instead of
# saving the error page.
#
# Template and VM zips go through a cache in ~/.cache/pharo-cli/downloads
# (see the cacheDownloads setting): a cached zip is downloaded again only when
# the server has a newer one (curl -z, with the server's time kept by -R).

# True when --refresh was given: cached zips are downloaded again.
HTTP_REFRESH=false

# Makes cached zips be downloaded again, for --refresh.
http_refresh_downloads() {
    HTTP_REFRESH=true
}

# Prints the body of the URL $1.
http_get() {
    curl -fsSL "$1"
}

# Saves the URL $1 into the file $2. Further arguments go to curl. On a
# terminal, curl shows its progress bar on stderr; otherwise (in a log, for
# an agent) one line says when the download is done, and with --quiet
# nothing is shown. When the server answers that the file has not changed
# (curl -z), $2 is not written.
http_download() {
    local url="$1" file="$2" start
    shift 2
    if [ "$PHARO_CLI_QUIET" = true ]; then
        curl -fsSL "$@" -o "$file" "$url"
    elif stderr_is_terminal; then
        curl -fL --progress-bar "$@" -o "$file" "$url"
    else
        start=$(date +%s)
        curl -fsSL "$@" -o "$file" "$url" || return
        [ -f "$file" ] || return 0
        info "Downloaded $(http_size "$file") in $(($(date +%s) - start))s."
    fi
}

# The size of the file $1, for people: 512 B, 37 KB, 51.2 MB.
http_size() {
    wc -c <"$1" | awk '{
        if ($1 < 1024) printf "%d B\n", $1
        else if ($1 < 1048576) printf "%d KB\n", $1 / 1024
        else printf "%.1f MB\n", $1 / 1048576
    }'
}

# The folder of cached downloads.
http_cache_dir() {
    printf '%s/downloads\n' "$(templates_cache_dir)"
}

# The cache file for the URL $1: the URL with every character other than
# letters, digits, dots, dashes and underscores replaced by _.
http_cache_file() {
    local name
    name=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g')
    case "$name" in
        *.zip) ;;
        *) name="$name.zip" ;;
    esac
    printf '%s/%s\n' "$(http_cache_dir)" "$name"
}

# Makes a local copy of the zip at the URL $1 and prints its path. With the
# cacheDownloads setting, it is the cache file, downloaded when missing,
# changed on the server, or with --refresh; when the server cannot be reached
# an older cached copy is used, with a warning. Without it, the zip is saved
# into the file $2, which the caller removes.
http_fetch_zip() {
    local url="$1" file tmp
    if [ "$(config_get cacheDownloads)" != true ]; then
        http_download "$url" "$2" || return 1
        printf '%s\n' "$2"
        return 0
    fi
    file=$(http_cache_file "$url")
    tmp="$file.tmp.$$"
    mkdir -p "$(http_cache_dir)" || return 1
    if [ -f "$file" ] && [ "$HTTP_REFRESH" != true ]; then
        if http_download "$url" "$tmp" -R -z "$file"; then
            if [ -s "$tmp" ]; then
                mv "$tmp" "$file" || return 1
            else
                rm -f "$tmp"
                info "Unchanged since the last download; using the cached copy."
            fi
        else
            rm -f "$tmp"
            warn "could not download $url; using the cached copy"
        fi
    else
        http_download "$url" "$tmp" -R || {
            rm -f "$tmp"
            return 1
        }
        mv "$tmp" "$file" || return 1
    fi
    printf '%s\n' "$file"
}
