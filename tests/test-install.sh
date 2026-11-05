#!/usr/bin/env bash
# 在一次性容器中验证真实安装，不能在持久化用户 home 中直接执行。
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash "${ROOT_DIR}/scripts/entrypoint.sh"
bash "${ROOT_DIR}/scripts/install.sh"
export PATH="${HOME}/.local/bin:${PATH}"

cd /tmp
mise exec -- docker compose version
mise exec -- python -c 'import defusedxml, jsonschema, numpy, pypdf, pymupdf, yaml, requests, ruamel.yaml, urllib3'
mise settings set jobs 2
grep -q 'jobs = 2' "${ROOT_DIR}/config/mise.toml"
test -r "${HOME}/.claude/CLAUDE.md"
test -d "${HOME}/.claude/skills"
