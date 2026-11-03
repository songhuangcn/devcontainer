#!/usr/bin/env bash
# 启动后安装工具；所有产物留在共享 home 中，可独立重复执行。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

mkdir -p "${HOME}/.cache" "${HOME}/.local/bin" \
  "${HOME}/.docker/cli-plugins" "${HOME}/.claude"
# 多个容器共享 home，安装和链接迁移必须串行。
exec 9>"${HOME}/.cache/workspace-install.lock"
flock 9

if [ ! -x "${HOME}/.local/bin/mise" ]; then
  curl -fsSL https://mise.run | sh
fi

# 从临时目录读取用户全局配置，避免当前项目的 mise 配置干扰安装。
install_dir="$(mktemp -d)"
trap 'rm -rf -- "${install_dir}"' EXIT
cd "${install_dir}"
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

ln -sf "$(mise which docker-compose)" "${HOME}/.docker/cli-plugins/docker-compose"

# 不在 mise registry 中的工具独立安装到用户默认 bin，校验后才替换已有文件。
MULTICA_VERSION=0.6.1
archive="multica-cli-${MULTICA_VERSION}-linux-$(dpkg --print-architecture).tar.gz"
curl -fsSL --retry 3 "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/${archive}" -o "${archive}"
curl -fsSL --retry 3 "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/checksums.txt" -o checksums.txt
grep -F " ${archive}" checksums.txt | sha256sum --check -
tar -xzf "${archive}" multica
install -m 755 multica "${HOME}/.local/bin/multica"

AUTOTEAM_LAUNCHER_REF=47edf2b69b85d3a229e579f7c8f89607a7d5174b
AUTOTEAM_LAUNCHER_SHA256=c3d0e9fd5546cf189e9e7094b5134e65859f95adefd425521df86efa1eb30321
curl -fsSL --retry 3 "https://raw.githubusercontent.com/autoteam-ai/autoteam/${AUTOTEAM_LAUNCHER_REF}/skills/autoteam/bin/autoteam-launcher" -o autoteam
printf '%s  autoteam\n' "${AUTOTEAM_LAUNCHER_SHA256}" | sha256sum --check -
install -m 755 autoteam "${HOME}/.local/bin/autoteam"

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
multica version
mise exec -- bash "${SCRIPT_DIR}/smoke-agent-cli-launchers.sh"
