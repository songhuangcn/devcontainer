#!/usr/bin/env bash
# 把镜像里的 home 模板补进（可能是空的）持久化 home 卷。
# 幂等：只补缺失项，从不覆盖已有文件；并发执行安全（源相同 + --skip-old-files）。
set -euo pipefail

SKEL="${DEVCONTAINER_SKEL:-/opt/home-skel}"
VSCODE_ROOT="${DEVCONTAINER_VSCODE_ROOT:-/opt/vscode-server}"

[ "${1:-}" = "--exec" ] && shift

if [ -d "${SKEL}" ]; then
  tar -C "${SKEL}" -cf - . | tar -C "${HOME}" -xf - --skip-old-files --no-same-owner
fi

# 预装的 VS Code Server 用软链而非复制（556 MB 不进卷）。仅 Java 镜像有内容。
if [ -d "${VSCODE_ROOT}/bin" ]; then
  mkdir -p "${HOME}/.vscode-server/bin"
  for d in "${VSCODE_ROOT}"/bin/*/; do
    sha="$(basename "${d}")"
    [ "${sha}" = "default_version" ] || ln -sfn "${d%/}" "${HOME}/.vscode-server/bin/${sha}"
  done
  # default_version 是镜像元数据不是用户数据，每次对齐镜像自带版本。
  [ -L "${VSCODE_ROOT}/bin/default_version" ] \
    && ln -sfn "$(readlink "${VSCODE_ROOT}/bin/default_version")" \
               "${HOME}/.vscode-server/bin/default_version"
fi

[ $# -gt 0 ] && exec "$@"
