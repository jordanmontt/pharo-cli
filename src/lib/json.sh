#!/usr/bin/env bash
# Writing JSON, for the --json option of info, list, templates, config and
# path. Only writing is needed, so there is no dependency on jq. The escaping
# is done by awk, the same in every Bash version (Bash 5.2 changed what
# ${var//pattern/replacement} does with some replacements).

# Reads "key<SEP>type<SEP>value" lines on stdin and prints them as one JSON
# object on one line. The type is string (escaped and quoted), or number,
# bool or json (printed as they are). An empty value is null. Values are
# single lines.
json_object() {
    awk -F "$PHARO_CLI_SEP" '
        BEGIN {
            for (i = 1; i < 32; i++) code[sprintf("%c", i)] = sprintf("\\u%04x", i)
            code["\t"] = "\\t"; code["\r"] = "\\r"; code["\\"] = "\\\\"; code["\""] = "\\\""
        }
        function quoted(s,   out, i, c) {
            out = ""
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                out = out ((c in code) ? code[c] : c)
            }
            return "\"" out "\""
        }
        {
            value = substr($0, length($1) + length($2) + 3)
            if (value == "") value = "null"
            else if ($2 == "string") value = quoted(value)
            fields = fields (NR > 1 ? "," : "") quoted($1) ":" value
        }
        END { printf "{%s}\n", fields }'
}

# Prints one "key<SEP>type<SEP>value" line for json_object.
json_field() {
    printf '%s%s%s%s%s\n' "$1" "$PHARO_CLI_SEP" "$2" "$PHARO_CLI_SEP" "$3"
}

# Reads JSON values, one per line, on stdin and prints them as a JSON array.
json_array() {
    awk 'BEGIN { printf "[" } { printf "%s%s", (NR > 1 ? "," : ""), $0 } END { print "]" }'
}

# The seconds since the epoch $1 in ISO 8601, or nothing when $1 is empty.
json_date() {
    [ -n "$1" ] && format_iso_date "$1"
    return 0
}
