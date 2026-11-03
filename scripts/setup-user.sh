#!/usr/bin/env bash
# 将用户配置链接到可写仓库，工具更新配置时直接写回同一份文件。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${1:-${SCRIPT_DIR}/..}" && pwd)"

config_files=(.gitconfig claude-settings.json codex-config.toml mise.toml opencode.jsonc opencode-service.json)
config_targets=(.gitconfig .claude/settings.json .codex/config.toml .config/mise/config.toml .config/opencode/opencode.jsonc .config/opencode/service.json)

# 先检查完整来源，缺文件时不迁移任何已有配置。
for file in "${config_files[@]}"; do
  test -f "${ROOT_DIR}/config/${file}"
done
test -f "${ROOT_DIR}/agents/AGENTS.md"
test -d "${ROOT_DIR}/agents/skills"

mkdir -p "${HOME}/.cache" "${HOME}/.claude" "${HOME}/.codex" \
  "${HOME}/.config/mise" "${HOME}/.config/opencode"
# app、OpenCode、Multica 会同时启动，共享 home 的链接迁移必须串行。
exec 9>"${HOME}/.cache/workspace-config.lock"
flock 9

link_resource() {
  local source="$1" target="$2" suffix="${3:-.before-workspace-link}"
  local backup="${target}${suffix}"
  if [ -L "${target}" ] && [ "$(readlink -- "${target}")" = "${source}" ]; then
    return
  fi
  if [ -e "${target}" ] || [ -L "${target}" ]; then
    if [ -e "${backup}" ] || [ -L "${backup}" ]; then
      printf 'Cannot replace %s: backup already exists at %s\n' "${target}" "${backup}" >&2
      return 1
    fi
    mv -- "${target}" "${backup}"
    printf 'Preserved existing %s at %s\n' "${target}" "${backup}"
  fi
  ln -sT -- "${source}" "${target}"
}

for index in "${!config_files[@]}"; do
  link_resource "${ROOT_DIR}/config/${config_files[index]}" "${HOME}/${config_targets[index]}"
done
link_resource "${ROOT_DIR}/agents" "${HOME}/.agents"
link_resource ../.agents/AGENTS.md "${HOME}/.claude/CLAUDE.md" .before-agents-link
link_resource ../.agents/skills "${HOME}/.claude/skills" .before-agents-link
