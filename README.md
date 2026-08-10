# qa-shell

Единый QA для shell-скриптов и YAML во всех репозиториях: **shellcheck**,
**shfmt**, **actionlint**, **yamllint**. Настройки живут только здесь — в
проектах не должно быть ни `.shellcheckrc`, ни `.yamllint`, ни
`.github/actionlint.yaml`.

| Способ | Чем ставится |
| --- | --- |
| GitHub-экшен | `uses: wprhvso/qa-shell@v1` |
| Флейк nix | `nix run github:wprhvso/qa-shell` |
| Скрипт | `bash <(curl -fsSL https://raw.githubusercontent.com/wprhvso/qa-shell/v1/scripts/local.sh)` |

## Проверки

| Проверка | Команда | Что проверяет |
| --- | --- | --- |
| `shellcheck` | `shellcheck` | найденные shell-файлы |
| `shfmt` | `shfmt --diff` с флагами из [`config/shfmt.args`](config/shfmt.args) | они же |
| `actionlint` | `actionlint -color` | `.github/workflows/*.yml` |
| `yamllint` | `yamllint --strict` | пути из `yaml-paths` |

`all` — все четыре.

Shell-файлы ищутся через `git ls-files` (без git — через `find`): берутся
`*.sh`, `*.bash` и файлы с shebang `#!.*(ba)?sh`. Исключаются `.git`, `result`,
`result-*`, `.direnv`, `node_modules`, `target`, `.venv`, `dist`, `build`.

## Использование

```yaml
name: ci

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  qa:
    runs-on: nested
    steps:
      - uses: actions/checkout@v7
      - uses: wprhvso/qa-shell@v1
```

Каждая проверка отдельной галочкой в PR:

```yaml
jobs:
  qa:
    runs-on: nested
    strategy:
      fail-fast: false
      matrix:
        check: [shellcheck, shfmt, actionlint, yamllint]
    steps:
      - uses: actions/checkout@v7
      - uses: wprhvso/qa-shell@v1
        with:
          checks: ${{ matrix.check }}
```

## Входные параметры

| Параметр | По умолчанию | Назначение |
| --- | --- | --- |
| `checks` | `all` | `all` либо список через запятую: `shellcheck`, `shfmt`, `actionlint`, `yamllint`. |
| `working-directory` | `.` | Каталог проекта в рабочей копии. |
| `config-mode` | `enforce` | `enforce` — общие конфиги перекрывают локальные, о найденных пишем warning; `check` — то же плюс падение job'а; `off` — конфиги не устанавливаются. |
| `setup-uv` | `true` | Ставить ли uv (`astral-sh/setup-uv`), которым запускается yamllint. |
| `shellcheck-version` | `v0.11.0` | Версия shellcheck. |
| `shfmt-version` | `v3.13.1` | Версия shfmt. |
| `actionlint-version` | `v1.7.12` | Версия actionlint. |
| `yamllint-version` | `1.38.0` | Версия yamllint. |
| `shell-paths` | пусто | Файлы и каталоги через пробел для shellcheck и shfmt; пусто — автопоиск. |
| `yaml-paths` | `.` | Пути через пробел для yamllint. |
| `shellcheck-args` / `shfmt-args` / `actionlint-args` / `yamllint-args` | пусто | Дополнительные аргументы. |

## Конфиги

| Файл | Куда кладётся |
| --- | --- |
| [`config/shellcheckrc`](config/shellcheckrc) | `.shellcheckrc` |
| [`config/yamllint.yml`](config/yamllint.yml) | `.yamllint` |
| [`config/actionlint.yaml`](config/actionlint.yaml) | `.github/actionlint.yaml` |
| [`config/shfmt.args`](config/shfmt.args) | флаги дописываются к `shfmt` |

`config/actionlint.yaml` объявляет метку self-hosted-раннера `nested`.
`config/shfmt.args` задаёт отступ в 4 пробела и отступ в ветках `case`.

Локальные настройки, о которых экшен предупреждает: `.shellcheckrc`,
`.yamllint`, `.yamllint.yaml`, `.yamllint.yml`, `.github/actionlint.yaml`,
`.github/actionlint.yml`.

## Локальный прогон

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wprhvso/qa-shell/v1/scripts/local.sh)
```

| Аргумент | Назначение |
| --- | --- |
| `--fix` | `shfmt -w` вместо `shfmt --diff`. |
| `--paths ПУТИ` | Что проверяют shellcheck и shfmt. |
| `--yaml-paths ПУТИ` | Что проверяет yamllint. |
| `shellcheck` / `shfmt` / `actionlint` / `yamllint` | Только выбранные проверки. |
| `-h`, `--help` | Справка. |

Конфиги прописываются в `.git/info/exclude`, так что в git не попадают и
`.gitignore` не трогают. Инструменты берутся из `PATH` или `nix shell`,
yamllint — через `uvx` с пином версии.

```bash
nix run github:wprhvso/qa-shell
nix develop
```
