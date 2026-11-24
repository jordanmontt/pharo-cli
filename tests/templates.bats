#!/usr/bin/env bats
# The template catalogue: parsing Pharo Launcher's sources.list, ids, the
# stable/latest/version names, and the cache.

load helpers/common

setup() {
    sandbox_setup
    serve_catalogue
}

@test "parses the URL entries of the real sources.list, in order, without duplicates" {
    run_lib 'templates_list'
    assert_success
    assert_line --index 0 "pharo-mooc$(printf '\037')Pharo Mooc$(printf '\037')https://mooc.pharo.org/image/PharoWeb.zip"
    assert_line "pharo-14.0-64bit-stable$(printf '\037')Pharo 14.0 - 64bit (stable)$(printf '\037')https://files.pharo.org/image/140/latest-64.zip"
    assert_line "moose-suite-13-stable-pharo-14$(printf '\037')Moose Suite 13 (stable) - Pharo 14$(printf '\037')https://github.com/moosetechnology/Moose/releases/download/v13.x.x/Moose13-stable-Pharo64-14.zip"
    # Pharo 10 is listed twice in the file, but once here.
    [ "$(printf '%s\n' "$output" | grep -c '^pharo-10.0-64bit')" -eq 1 ]
    # Groups, caches and HTTP listings are not templates.
    refute_output --partial "Official distributions"
    refute_output --partial "Templates"
    refute_output --partial "filterPattern"
}

@test "template ids are lowercase words joined by dashes" {
    run_lib 'templates_id "Pharo 15.0 - 64bit (development version, latest)"; templates_id "Smic (Compiler Course)"'
    assert_output "pharo-15.0-64bit-development-version-latest
smic-compiler-course"
}

@test "handles escaped quotes in STON strings" {
    printf '%s\n' "OrderedCollection [" "PhLTemplateSource {" "#type : #URL," "#name : 'Bob\\'s image'," "#url : 'https://example.org/bob.zip'" "}" "]" >"$SANDBOX/s.list"
    run_lib "templates_parse '$SANDBOX/s.list'"
    assert_output "bob-s-image$(printf '\037')Bob's image$(printf '\037')https://example.org/bob.zip"
}

@test "stable is the official release marked (stable)" {
    run_lib 'templates_resolve stable'
    assert_output "Pharo 14.0 - 64bit (stable)$(printf '\037')https://files.pharo.org/image/140/latest-64.zip"
}

@test "latest is the newest official Pharo version" {
    run_lib 'templates_resolve latest'
    assert_output "Pharo 15.0 - 64bit (development version, latest)$(printf '\037')https://files.pharo.org/image/150/latest-64.zip"
}

@test "a version number maps to the newest build of that version, without the catalogue" {
    run_lib 'templates_resolve 14; templates_resolve 140; templates_resolve 9'
    assert_output "Pharo 14$(printf '\037')https://files.pharo.org/image/140/latest-64.zip
Pharo 140$(printf '\037')https://files.pharo.org/image/140/latest-64.zip
Pharo 9$(printf '\037')https://files.pharo.org/image/90/latest-64.zip"
    run curl_requests
    assert_output ""
}

@test "version URLs follow the filesServer setting" {
    write_config "filesServer=https://mirror.example/pharo"
    run_lib 'templates_version_url 13'
    assert_output "https://mirror.example/pharo/image/130/latest-64.zip"
}

@test "a template can be named by id or by its full name" {
    run_lib 'templates_resolve moose-suite-13-stable; templates_resolve "Pharo Mooc"'
    assert_output "Moose Suite 13 (stable)$(printf '\037')https://github.com/moosetechnology/Moose/releases/download/v13.x.x/Moose13-stable-Pharo64-13.zip
Pharo Mooc$(printf '\037')https://mooc.pharo.org/image/PharoWeb.zip"
}

@test "an unknown template fails" {
    run_lib 'templates_resolve no-such-template'
    assert_failure
    run_lib 'templates_exists no-such-template'
    assert_failure
    run_lib 'templates_exists 14 && templates_exists stable && templates_exists pharo-mooc && echo yes'
    assert_output yes
}

@test "stable fails when the catalogue has no stable entry" {
    printf '%s\n' "OrderedCollection [" "PhLTemplateSource {" "#type : #URL," "#name : 'Other'," "#url : 'https://example.org/o.zip'" "}" "]" >"$FAKE_HTTP_ROOT/files.pharo.org/pharo-launcher/sources.list"
    run_lib 'templates_resolve stable'
    assert_failure
    run_lib 'templates_resolve latest'
    assert_failure
}

@test "the catalogue is downloaded once and cached for templatesCacheTtl seconds" {
    run_lib 'templates_list >/dev/null; templates_list >/dev/null'
    run curl_requests
    assert_output "https://files.pharo.org/pharo-launcher/sources.list"
    [ -f "$HOME/.cache/pharo-cli/sources.list" ]
}

@test "a stale cache is downloaded again" {
    run_lib 'templates_list >/dev/null'
    echo 0 >"$HOME/.cache/pharo-cli/sources.list.fetched"
    run_lib 'templates_list >/dev/null'
    run curl_requests
    assert_line --index 1 "https://files.pharo.org/pharo-launcher/sources.list"
}

@test "a templatesCacheTtl of 0 always downloads" {
    write_config "templatesCacheTtl=0"
    run_lib 'templates_list >/dev/null; templates_list >/dev/null'
    run curl_requests
    assert_equal "${#lines[@]}" 2
}

@test "the cache follows XDG_CACHE_HOME" {
    run env XDG_CACHE_HOME="$SANDBOX/cache" PATH="$SANDBOX_PATH" PHARO_CLI_ROOT="$PROJECT_ROOT" bash -c '. "$PHARO_CLI_ROOT/src/main.sh"; os_load; templates_list >/dev/null'
    [ -f "$SANDBOX/cache/pharo-cli/sources.list" ]
}

@test "when the download fails, a stale cached copy is used with a warning" {
    run_lib 'templates_list >/dev/null'
    echo 0 >"$HOME/.cache/pharo-cli/sources.list.fetched"
    rm "$FAKE_HTTP_ROOT/files.pharo.org/pharo-launcher/sources.list"
    run_lib 'templates_resolve stable'
    assert_success
    assert_output --partial "could not download the template list; using the cached copy"
    assert_output --partial "Pharo 14.0 - 64bit (stable)"
}

@test "without a cache, a failed download is an error and leaves no partial file" {
    rm "$FAKE_HTTP_ROOT/files.pharo.org/pharo-launcher/sources.list"
    run_lib 'templates_list'
    assert_failure
    assert_output --partial "could not download the template list from https://files.pharo.org/pharo-launcher/sources.list"
    run ls -A "$HOME/.cache/pharo-cli"
    assert_output ""
}

@test "templatesUrl can point to another list, including a local file" {
    printf '%s\n' "OrderedCollection [" "PhLTemplateSource {" "#type : #URL," "#name : 'Local'," "#url : 'https://example.org/l.zip'" "}" "]" >"$SANDBOX/mine.list"
    write_config "templatesUrl=file://$SANDBOX/mine.list"
    run_lib 'templates_list'
    assert_output "local$(printf '\037')Local$(printf '\037')https://example.org/l.zip"
}
