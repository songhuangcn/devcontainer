#!/usr/bin/env bash
# 把镜像里的 home 模板补进（可能是空的）持久化 home 卷。
# 幂等：只补缺失模板；需替换的既有 Claude 资源会先备份；并发执行安全。
set -euo pipefail

SKEL="${DEVCONTAINER_SKEL:-/opt/home-skel}"
VSCODE_ROOT="${DEVCONTAINER_VSCODE_ROOT:-/opt/vscode-server}"

[ "${1:-}" = "--exec" ] && shift

# Compose 的两个 service 和 Kubernetes Pod 的两个应用容器会共享同一个 home。
# 串行初始化，避免首次迁移已有 Claude 配置时互相覆盖。
mkdir -p "${HOME}/.cache"
exec 9>"${HOME}/.cache/devcontainer-home-init.lock"
flock 9

if [ -d "${SKEL}" ]; then
  tar -C "${SKEL}" -cf - . | tar -C "${HOME}" -xf - --skip-old-files --no-same-owner
fi

mkdir -p "${HOME}/.claude"

link_agent_resource() {
  local source="$1"
  local target="$2"
  local backup="${target}.before-agents-link"

  if [ -e "${target}" ] && [ ! -L "${target}" ]; then
    if [ -e "${backup}" ] || [ -L "${backup}" ]; then
      printf 'Cannot replace %s: backup already exists at %s\n' "${target}" "${backup}" >&2
      return 1
    fi
    mv -- "${target}" "${backup}"
    printf 'Preserved existing %s at %s\n' "${target}" "${backup}"
  fi

  ln -sfnT -- "${source}" "${target}"
}

# Claude Code 使用自己的文件名和目录，同时复用 ~/.agents 中的用户指令与 skills。
link_agent_resource ../.agents/AGENTS.md "${HOME}/.claude/CLAUDE.md"
link_agent_resource ../.agents/skills "${HOME}/.claude/skills"

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

flock -u 9
exec 9>&-

[ $# -gt 0 ] && exec "$@"
