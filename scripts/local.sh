#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'USAGE'
qa-shell — локальный прогон тех же проверок, что делает экшен в CI.

  bash <(curl -fsSL https://raw.githubusercontent.com/wprhvso/qa-shell/v1/scripts/local.sh)
  ... --fix                      shfmt -w вместо shfmt --diff
  ... shellcheck shfmt           только выбранные проверки
  ... --paths 'scripts bin/run'  что проверяют shellcheck и shfmt
  ... --yaml-paths '.github'     что проверяет yamllint

Проверки: shellcheck, shfmt, actionlint, yamllint. По умолчанию — все четыре.

Переменные окружения: QA_REF (тег qa-shell, по умолчанию v1), QA_LOCAL
(локальная копия qa-shell), QA_NIXPKGS, QA_SHELL_PATHS, QA_YAML_PATHS.
USAGE
}

ref=${QA_REF:-v1}
base=${QA_BASE:-"https://raw.githubusercontent.com/wprhvso/qa-shell/$ref"}
nixpkgs=${QA_NIXPKGS:-github:NixOS/nixpkgs/nixos-unstable}
yamllint_version=${QA_YAMLLINT_VERSION:-1.38.0}

fix=false
checks=()
shell_paths=${QA_SHELL_PATHS:-}
yaml_paths=${QA_YAML_PATHS:-.}

need_value() {
    if (($1 < 2)); then
        echo "$2 требует значение" >&2
        exit 2
    fi
}

while (($# > 0)); do
    case "$1" in
        --fix)
            fix=true
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        --paths)
            need_value $# "$1"
            shell_paths=$2
            shift 2
            ;;
        --paths=*)
            shell_paths=${1#--paths=}
            shift
            ;;
        --yaml-paths)
            need_value $# "$1"
            yaml_paths=$2
            shift 2
            ;;
        --yaml-paths=*)
            yaml_paths=${1#--yaml-paths=}
            shift
            ;;
        shellcheck | shfmt | actionlint | yamllint)
            checks+=("$1")
            shift
            ;;
        *)
            echo "неизвестный аргумент: $1" >&2
            exit 2
            ;;
    esac
done
((${#checks[@]} == 0)) && checks=(shellcheck shfmt actionlint yamllint)

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fetch() {
    local rel=$1 dst=$2
    mkdir -p "$(dirname "$dst")"
    rm -f "$dst"
    if [[ -n ${QA_LOCAL:-} && -f "$QA_LOCAL/$rel" ]]; then
        cp "$QA_LOCAL/$rel" "$dst"
        chmod u+w "$dst"
    else
        curl -fsSL --retry 3 --retry-all-errors "$base/$rel" -o "$dst"
    fi
}

installed=()
install_config() {
    fetch "config/$1" "$root/$2"
    installed+=("$2")
    if [[ -d $root/.git ]] && ! grep -qxF "/$2" "$root/.git/info/exclude" 2>/dev/null; then
        mkdir -p "$root/.git/info"
        echo "/$2" >>"$root/.git/info/exclude"
    fi
}

install_config shellcheckrc .shellcheckrc
install_config yamllint.yml .yamllint
install_config actionlint.yaml .github/actionlint.yaml

fetch config/shfmt.args "$work/shfmt.args"
read -r -a flags <<<"$(grep -vE '^[[:space:]]*(#|$)' "$work/shfmt.args" | tr '\n' ' ')" || true

fetch scripts/list-shell-files.sh "$work/list-shell-files.sh"
mapfile -t files < <(QA_SHELL_PATHS="$shell_paths" bash "$work/list-shell-files.sh")

read -r -a yaml_targets <<<"$yaml_paths" || true
((${#yaml_targets[@]} > 0)) || yaml_targets=(.)

workflows=()
if [[ -d .github/workflows ]]; then
    mapfile -t workflows < <(
        find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort
    )
fi

tool() {
    local bin=$1 pkg=$2
    shift 2
    if command -v "$bin" >/dev/null 2>&1; then
        "$bin" "$@"
    elif command -v nix >/dev/null 2>&1; then
        nix --extra-experimental-features "nix-command flakes" shell "$nixpkgs#$pkg" -c "$bin" "$@"
    else
        echo "не найден $bin: поставьте его или nix" >&2
        return 127
    fi
}

yamllint_tool() {
    if command -v uvx >/dev/null 2>&1; then
        uvx "yamllint@$yamllint_version" "$@"
    else
        tool yamllint yamllint "$@"
    fi
}

echo "qa-shell@$ref — shell-файлов: ${#files[@]}, workflow'ов: ${#workflows[@]}"
printf 'конфиги: %s\n\n' "${installed[*]}"

failed=()
run() {
    local title=$1
    shift
    echo "== $title"
    printf '+ %s\n' "$*"
    if "$@"; then
        echo
    else
        failed+=("$title")
        echo
    fi
}

for check in "${checks[@]}"; do
    case "$check" in
        shellcheck)
            if ((${#files[@]} == 0)); then
                echo "== shellcheck: shell-файлов нет"
                continue
            fi
            run "shellcheck" tool shellcheck shellcheck -- "${files[@]}"
            ;;
        shfmt)
            if ((${#files[@]} == 0)); then
                echo "== shfmt: shell-файлов нет"
                continue
            fi
            if [[ $fix == true ]]; then
                run "shfmt -w" tool shfmt shfmt "${flags[@]}" -w -- "${files[@]}"
            else
                run "shfmt --diff" tool shfmt shfmt "${flags[@]}" --diff -- "${files[@]}"
            fi
            ;;
        actionlint)
            if ((${#workflows[@]} == 0)); then
                echo "== actionlint: workflow'ов нет"
                continue
            fi
            run "actionlint" tool actionlint actionlint -color \
                -config-file .github/actionlint.yaml "${workflows[@]}"
            ;;
        yamllint)
            run "yamllint" yamllint_tool --strict -c .yamllint -- "${yaml_targets[@]}"
            ;;
    esac
done

if ((${#failed[@]} > 0)); then
    printf 'упало: %s\n' "${failed[*]}"
    exit 1
fi
echo "всё чисто"
