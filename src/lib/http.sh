#!/usr/bin/env bash
# Downloads, through curl. -f makes HTTP errors (404, 500...) fail instead of
# saving the error page.

# Prints the body of the URL $1.
http_get() {
    curl -fsSL "$1"
}

# Saves the URL $1 into the file $2, showing a progress bar on stderr.
http_download() {
    curl -fL --progress-bar -o "$2" "$1"
}
