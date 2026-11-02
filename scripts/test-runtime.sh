#!/usr/bin/env bash
# 在临时 home 和命令替身中验证行为，不安装依赖、不改真实用户数据。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(mktemp -d)"
trap 'rm -rf -- "${root}"' EXIT
export HOME="${root}/home"
mkdir -p "${HOME}"
chmod 700 "${HOME}"

# 空 home 从 /etc/skel 补齐；已有用户文件不覆盖；参数和退出码原样传递。
bash "${SCRIPT_DIR}/entrypoint.sh"
cmp /etc/skel/.bashrc "${HOME}/.bashrc"
test "$(stat -c %a "${HOME}")" = 700
printf 'custom profile\n' > "${HOME}/.profile"
bash "${SCRIPT_DIR}/entrypoint.sh" bash -c 'test "$1" = "two words"' -- 'two words'
test "$(cat "${HOME}/.profile")" = 'custom profile'
rc=0
bash "${SCRIPT_DIR}/entrypoint.sh" bash -c 'exit 23' || rc=$?
test "${rc}" = 23

# 隔离镜像 ENV，让所有安装产物进入测试 home。
unset MISE_INSTALL_PATH MISE_DATA_DIR MISE_CACHE_DIR MISE_STATE_DIR
export TEST_BIN="${root}/bin" TEST_LOG="${root}/commands.log"
mkdir -p "${TEST_BIN}" "${HOME}/.agents/skills/example" "${HOME}/.claude/skills/legacy"
printf 'instructions\n' > "${HOME}/.agents/AGENTS.md"
printf 'skill\n' > "${HOME}/.agents/skills/example/SKILL.md"
printf 'legacy instructions\n' > "${HOME}/.claude/CLAUDE.md"
printf 'legacy skill\n' > "${HOME}/.claude/skills/legacy/SKILL.md"

cat > "${TEST_BIN}/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl\n' >> "${TEST_LOG}"
cat <<'INSTALLER'
#!/usr/bin/env sh
cp "${TEST_BIN}/fake-mise" "${MISE_INSTALL_PATH}"
chmod +x "${MISE_INSTALL_PATH}"
INSTALLER
SH
cat > "${TEST_BIN}/fake-mise" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'mise %s (%s)\n' "$*" "${PWD}" >> "${TEST_LOG}"
case "$1" in
  which) printf '%s/%s\n' "${TEST_BIN}" "$2" ;;
  install|reshim|exec) ;;
  *) exit 1 ;;
esac
SH
cat > "${TEST_BIN}/smoke-agent-cli-launchers" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
for tool in codex claude opencode; do
  test "$(readlink "${HOME}/.local/share/agent-bin/${tool}")" = "${TEST_BIN}/${tool}"
done
printf 'smoke\n' >> "${TEST_LOG}"
SH
chmod +x "${TEST_BIN}"/*
export PATH="${TEST_BIN}:${PATH}"

bash "${SCRIPT_DIR}/install.sh"
test -x "${HOME}/.local/bin/mise"
test "$(readlink "${HOME}/.docker/cli-plugins/docker-compose")" = "${TEST_BIN}/docker-compose"
test "$(readlink "${HOME}/.claude/CLAUDE.md")" = '../.agents/AGENTS.md'
test -r "${HOME}/.claude/CLAUDE.md"
test "$(readlink "${HOME}/.claude/skills")" = '../.agents/skills'
test -f "${HOME}/.claude/skills/example/SKILL.md"
test -f "${HOME}/.claude/CLAUDE.md.before-agents-link"
test -f "${HOME}/.claude/skills.before-agents-link/legacy/SKILL.md"

# 重复安装不重新下载 mise，不破坏已有备份；安装始终从中立目录执行。
bash "${SCRIPT_DIR}/install.sh"
test "$(grep -c '^curl$' "${TEST_LOG}")" = 1
test "$(grep -c '^mise install --yes (/tmp)$' "${TEST_LOG}")" = 2
test "$(grep -c '^smoke$' "${TEST_LOG}")" = 2

# 已有备份时拒绝覆盖；依赖安装失败时不得继续执行 smoke。
rm "${HOME}/.claude/CLAUDE.md"
printf 'new instructions\n' > "${HOME}/.claude/CLAUDE.md"
if bash "${SCRIPT_DIR}/install.sh"; then
  printf 'Expected backup conflict to fail\n' >&2
  exit 1
fi
test "$(cat "${HOME}/.claude/CLAUDE.md")" = 'new instructions'
cat > "${HOME}/.local/bin/mise" <<'SH'
#!/usr/bin/env bash
exit 42
SH
rc=0
bash "${SCRIPT_DIR}/install.sh" || rc=$?
test "${rc}" = 42
test "$(grep -c '^smoke$' "${TEST_LOG}")" = 2
printf 'Runtime script tests passed.\n'
