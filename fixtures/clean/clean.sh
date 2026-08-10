#!/usr/bin/env bash

set -euo pipefail

greet() {
    local name=$1
    case "$name" in
        world) printf 'привет, %s\n' "$name" ;;
        *) printf 'здравствуй, %s\n' "$name" ;;
    esac
}

main() {
    local target=${1:-world}
    local count=${2:-1}
    for _ in $(seq 1 "$count"); do
        greet "$target"
    done
}

main "$@"
