#!/usr/bin/env bash

set -euo pipefail

bin="${QA_BIN:?QA_BIN is required}"
mkdir -p "$bin"

case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *)
        echo "::error::qa-shell не умеет ставить инструменты на $(uname -s)"
        exit 2
        ;;
esac

case "$(uname -m)" in
    x86_64 | amd64)
        gnu_arch=x86_64
        go_arch=amd64
        ;;
    arm64 | aarch64)
        gnu_arch=aarch64
        go_arch=arm64
        ;;
    *)
        echo "::error::qa-shell не умеет ставить инструменты на $(uname -m)"
        exit 2
        ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

get() {
    curl -fsSL --retry 3 --retry-all-errors "$1" -o "$2"
}

install_shellcheck() {
    local ver=v${QA_SHELLCHECK_VERSION#v}
    get "https://github.com/koalaman/shellcheck/releases/download/$ver/shellcheck-$ver.$os.$gnu_arch.tar.xz" \
        "$work/shellcheck.tar.xz"
    tar -xJf "$work/shellcheck.tar.xz" -C "$work"
    install -m 0755 "$work/shellcheck-$ver/shellcheck" "$bin/shellcheck"
}

install_shfmt() {
    local ver=v${QA_SHFMT_VERSION#v}
    get "https://github.com/mvdan/sh/releases/download/$ver/shfmt_${ver}_${os}_${go_arch}" "$work/shfmt"
    install -m 0755 "$work/shfmt" "$bin/shfmt"
}

install_actionlint() {
    local ver=${QA_ACTIONLINT_VERSION#v}
    get "https://github.com/rhysd/actionlint/releases/download/v$ver/actionlint_${ver}_${os}_${go_arch}.tar.gz" \
        "$work/actionlint.tar.gz"
    tar -xzf "$work/actionlint.tar.gz" -C "$work" actionlint
    install -m 0755 "$work/actionlint" "$bin/actionlint"
}

wanted_version() {
    case "$1" in
        shellcheck) echo "${QA_SHELLCHECK_VERSION:-}" ;;
        shfmt) echo "${QA_SHFMT_VERSION:-}" ;;
        actionlint) echo "${QA_ACTIONLINT_VERSION:-}" ;;
    esac
}

current_version() {
    case "$1" in
        shellcheck) shellcheck --version | sed -n 's/^version: *//p' ;;
        shfmt) shfmt --version | head -n 1 ;;
        actionlint) actionlint --version | head -n 1 ;;
    esac
}

already_installed() {
    local tool=$1 want current
    command -v "$tool" >/dev/null || return 1
    want=$(wanted_version "$tool")
    want=${want#v}
    current=$(current_version "$tool" 2>/dev/null || true)
    current=${current#v}
    [[ -n $want && $current == "$want" ]] || return 1
    echo "$tool v$want уже установлен — пропускаю"
}

tools=()
read -r -a tools <<<"${QA_TOOLS:-}" || true

installed=()

for tool in "${tools[@]}"; do
    case "$tool" in
        shellcheck | shfmt | actionlint) ;;
        *)
            echo "::error::qa-shell не умеет ставить $tool"
            exit 2
            ;;
    esac
    if already_installed "$tool"; then
        continue
    fi
    "install_$tool"
    installed+=("$tool")
done

if ((${#installed[@]} > 0)); then
    echo "$bin" >>"${GITHUB_PATH:-/dev/null}"
    for tool in "${installed[@]}"; do
        "$bin/$tool" --version | head -n 2
    done
fi
