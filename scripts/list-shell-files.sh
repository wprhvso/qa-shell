#!/usr/bin/env bash

set -euo pipefail

paths=()
read -r -a paths <<<"${QA_SHELL_PATHS:-}" || true

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_repo=true
else
    git_repo=false
fi

walk() {
    if [[ $git_repo == true ]]; then
        git -c core.quotePath=false ls-files --cached --others --exclude-standard -- "$1"
    else
        find "$1" \
            \( -name .git -o -name .direnv -o -name .venv -o -name node_modules \
            -o -name target -o -name dist -o -name build \
            -o -name result -o -name 'result-*' \) -prune \
            -o -type f -print
    fi | sed 's|^\./||'
}

excluded() {
    case "/$1/" in
        */.git/* | */.direnv/* | */.venv/* | */node_modules/* | */target/* | */dist/* | */build/* | */result/*)
            return 0
            ;;
    esac
    case "$1" in
        result | result-*) return 0 ;;
    esac
    return 1
}

shellish() {
    case "$1" in
        *.sh | *.bash) return 0 ;;
    esac
    LC_ALL=C grep -qI '' -- "$1" 2>/dev/null || return 1
    local first=""
    IFS= read -r first <"$1" || true
    [[ $first =~ ^#!.*([[:space:]]|/)(ba)?sh([[:space:]]|$) ]]
}

emit() {
    local file
    while IFS= read -r file; do
        [[ -n $file ]] || continue
        [[ -f $file ]] || continue
        excluded "$file" && continue
        shellish "$file" || continue
        printf '%s\n' "$file"
    done
}

if ((${#paths[@]} > 0)); then
    for path in "${paths[@]}"; do
        if [[ -f $path ]]; then
            printf '%s\n' "$path"
        elif [[ -d $path ]]; then
            walk "$path" | emit
        else
            echo "::warning::путь не найден: $path" >&2
        fi
    done
else
    walk . | emit
fi | sort -u
