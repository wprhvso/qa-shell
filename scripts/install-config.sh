#!/usr/bin/env bash

set -euo pipefail

action_path="${QA_ACTION_PATH:?QA_ACTION_PATH is required}"
config_dir="$action_path/config"
mode="${QA_CONFIG_MODE:-enforce}"

case "$mode" in
    enforce | check | off) ;;
    *)
        echo "::error::config-mode должен быть enforce, check или off (получено: $mode)"
        exit 2
        ;;
esac

if [[ $mode == off ]]; then
    echo "config-mode=off — используются настройки самого репозитория"
    exit 0
fi

leftovers=()

note_leftover() {
    leftovers+=("$1")
    echo "::warning title=Локальная конфигурация QA::$1 — настройки должны жить только в wprhvso/qa-shell"
}

ours() {
    local candidate="$config_dir/$2"
    [[ -n $2 && -f $candidate ]] && cmp -s "$1" "$candidate"
}

while read -r file config; do
    [[ -f $file ]] || continue
    ours "$file" "${config:-}" && continue
    note_leftover "$file"
done <<'CONFIGS'
.shellcheckrc shellcheckrc
.yamllint yamllint.yml
.github/actionlint.yaml actionlint.yaml
.yamllint.yaml
.yamllint.yml
.github/actionlint.yml
CONFIGS

install_config() {
    local src="$config_dir/$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    rm -f "$dst"
    cp "$src" "$dst"
    chmod u+w "$dst"
    echo "  $dst <- qa-shell/config/$1"
}

echo "Устанавливаю общие конфиги:"
install_config shellcheckrc .shellcheckrc
install_config yamllint.yml .yamllint
install_config actionlint.yaml .github/actionlint.yaml

if ((${#leftovers[@]} > 0)); then
    printf '\nЛокальных настроек найдено: %d\n' "${#leftovers[@]}"
    printf '  - %s\n' "${leftovers[@]}"
    if [[ $mode == check ]]; then
        echo "::error title=Локальная конфигурация QA::config-mode=check: удалите перечисленные настройки из репозитория"
        exit 1
    fi
fi
