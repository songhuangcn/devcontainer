#!/usr/bin/env bash
# 启动后安装工具；所有产物留在共享 home 中，可独立重复执行。
set -euo pipefail

export MISE_INSTALL_PATH="${MISE_INSTALL_PATH:-${HOME}/.local/bin/mise}"
export MISE_DATA_DIR="${MISE_DATA_DIR:-${HOME}/.local/share/mise}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-${HOME}/.cache/mise}"
export MISE_STATE_DIR="${MISE_STATE_DIR:-${HOME}/.local/state/mise}"
AGENT_BIN="${HOME}/.local/share/agent-bin"
PATH="${AGENT_BIN}:$(dirname "${MISE_INSTALL_PATH}"):${MISE_DATA_DIR}/shims:${PATH}"
export PATH

mkdir -p "${MISE_STATE_DIR}" "$(dirname "${MISE_INSTALL_PATH}")" "${AGENT_BIN}" \
  "${HOME}/.docker/cli-plugins" "${HOME}/.claude"
# 多个容器共享 home，安装和链接迁移必须串行。
exec 9>"${MISE_STATE_DIR}/install.lock"
flock 9

if [ ! -x "${MISE_INSTALL_PATH}" ]; then
  curl -fsSL https://mise.run | sh
fi

# 从中立目录安装 system config，避免 /workspace 项目的 mise 配置影响全局工具。
cd /tmp
mise install --yes
mise reshim
mise exec -- python -m pip install --no-cache-dir \
  defusedxml \
  'jsonschema[format]>=4.17' \
  numpy \
  pypdf \
  pymupdf \
  pyyaml \
  requests~=2.32.5 \
  'ruamel.yaml>=0.17' \
  urllib3~=2.6.3

# Multica 会解析可执行文件的真实路径，不能让 provider 落到 mise shim。
for tool in codex claude opencode; do
  ln -sf "$(mise which "${tool}")" "${AGENT_BIN}/${tool}"
done
ln -sf "$(mise which docker-compose)" "${HOME}/.docker/cli-plugins/docker-compose"

link_agent_resource() {
  local source="$1" target="$2"
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

link_agent_resource ../.agents/AGENTS.md "${HOME}/.claude/CLAUDE.md"
link_agent_resource ../.agents/skills "${HOME}/.claude/skills"
smoke-agent-cli-launchers
