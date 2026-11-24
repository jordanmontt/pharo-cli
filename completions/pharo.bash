# Bash completion for pharo-cli. Also works in zsh after
#   autoload -U +X bashcompinit && bashcompinit
# The candidates come from 'pharo __complete', so this file never needs to
# change when commands change.

_pharo_cli_complete() {
    # In zsh, number arrays from 0 like Bash does (bashcompinit sets
    # COMP_CWORD for 0-based arrays).
    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt localoptions ksharrays
    fi
    local line current
    current="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=()
    while IFS= read -r line; do
        if [ "$line" = "__files__" ]; then
            while IFS= read -r line; do
                COMPREPLY[${#COMPREPLY[@]}]="$line"
            done < <(compgen -f -- "$current")
            if type compopt >/dev/null 2>&1; then
                compopt -o filenames 2>/dev/null
            fi
        else
            COMPREPLY[${#COMPREPLY[@]}]=$(printf '%q' "$line")
        fi
    done < <("${COMP_WORDS[0]}" __complete "$COMP_CWORD" "${COMP_WORDS[@]}" 2>/dev/null)
}

complete -F _pharo_cli_complete pharo
