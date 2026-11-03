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

# 隔离测试所用的旧镜像环境；被测脚本仅使用 mise 默认用户目录。
unset MISE_INSTALL_PATH MISE_DATA_DIR MISE_CACHE_DIR MISE_STATE_DIR
export TEST_BIN="${root}/bin" TEST_LOG="${root}/commands.log" TEST_FIXTURES="${root}/fixtures"
export TMPDIR="${root}/tmp"
mkdir -p "${TEST_BIN}" "${TEST_FIXTURES}" "${TMPDIR}" "${HOME}/.config/mise" \
  "${HOME}/.agents/skills/example" "${HOME}/.claude/skills/legacy"
cp "${SCRIPT_DIR}/../config/mise.toml" "${HOME}/.config/mise/config.toml"
printf 'instructions\n' > "${HOME}/.agents/AGENTS.md"
printf 'skill\n' > "${HOME}/.agents/skills/example/SKILL.md"
printf 'legacy instructions\n' > "${HOME}/.claude/CLAUDE.md"
printf 'legacy skill\n' > "${HOME}/.claude/skills/legacy/SKILL.md"

cat > "${TEST_BIN}/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
url='' output=''
while [ $# -gt 0 ]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    --retry) shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
printf 'download %s\n' "${url}" >> "${TEST_LOG}"
case "${url}" in
  https://mise.run)
    cat <<'INSTALLER'
#!/usr/bin/env sh
cp "${TEST_BIN}/fake-mise" "${HOME}/.local/bin/mise"
chmod +x "${HOME}/.local/bin/mise"
INSTALLER
    ;;
  */multica-cli-*.tar.gz) cp "${TEST_FIXTURES}/multica.tar.gz" "${output}" ;;
  */checksums.txt) printf '%064d  multica-cli-0.6.1-linux-%s.tar.gz\n' 0 "$(dpkg --print-architecture)" > "${output}" ;;
  */autoteam-launcher) printf '#!/bin/sh\nexit 0\n' > "${output}" ;;
  *) exit 1 ;;
esac
SH
cat > "${TEST_BIN}/fake-mise" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'mise %s (%s)\n' "$*" "${PWD}" >> "${TEST_LOG}"
case "$1" in
  which) printf '%s/%s\n' "${TEST_BIN}" "$2" ;;
  install) test -r "${HOME}/.config/mise/config.toml" ;;
  reshim) ;;
  exec)
    shift 2
    if [ "$1" != python ]; then
      "$@"
      printf 'smoke\n' >> "${TEST_LOG}"
    fi
    ;;
  *) exit 1 ;;
esac
SH
cat > "${TEST_BIN}/sha256sum" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
test "$*" = '--check -'
read -r checksum file
test "${#checksum}" = 64
test -f "${file}"
printf 'checksum %s\n' "${file}" >> "${TEST_LOG}"
case "${file}:${TEST_FAIL_CHECKSUM:-}" in
  multica-*:multica|autoteam:autoteam) exit 1 ;;
esac
SH
cat > "${TEST_FIXTURES}/multica" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  version) printf 'multica version 0.6.1\n' ;;
  auth) test "${TEST_AUTHENTICATED:-0}" = 1 ;;
  login) printf 'login\n' >> "${TEST_LOG}" ;;
  daemon) printf 'daemon\n' >> "${TEST_LOG}" ;;
  *) exit 1 ;;
esac
SH
tar -czf "${TEST_FIXTURES}/multica.tar.gz" -C "${TEST_FIXTURES}" multica
for tool in codex claude opencode docker-compose; do
  printf '#!/bin/sh\nprintf "test-cli 1.0\\n"\n' > "${TEST_BIN}/${tool}"
done
chmod +x "${TEST_BIN}"/*
export PATH="${TEST_BIN}:${PATH}"

bash "${SCRIPT_DIR}/install.sh"
test -x "${HOME}/.local/bin/mise"
test -x "${HOME}/.local/bin/multica"
test -x "${HOME}/.local/bin/autoteam"
test "$(readlink "${HOME}/.docker/cli-plugins/docker-compose")" = "${TEST_BIN}/docker-compose"
test "$(readlink "${HOME}/.claude/CLAUDE.md")" = '../.agents/AGENTS.md'
test -r "${HOME}/.claude/CLAUDE.md"
test "$(readlink "${HOME}/.claude/skills")" = '../.agents/skills'
test -f "${HOME}/.claude/skills/example/SKILL.md"
test -f "${HOME}/.claude/CLAUDE.md.before-agents-link"
test -f "${HOME}/.claude/skills.before-agents-link/legacy/SKILL.md"

# 重复安装保留用户备份，不重复引导 mise，并清理临时下载目录。
bash "${SCRIPT_DIR}/install.sh"
test "$(grep -c '^download https://mise.run$' "${TEST_LOG}")" = 1
test "$(grep -c '^mise install --yes (' "${TEST_LOG}")" = 2
test "$(grep -c '^smoke$' "${TEST_LOG}")" = 2
test -z "$(ls -A "${TMPDIR}")"

# 校验失败不能覆盖旧工具，也不能继续 smoke。
for tool in multica autoteam; do
  printf 'existing tool\n' > "${HOME}/.local/bin/${tool}"
  if TEST_FAIL_CHECKSUM="${tool}" bash "${SCRIPT_DIR}/install.sh"; then
    printf 'Expected checksum failure for %s\n' "${tool}" >&2
    exit 1
  fi
  test "$(cat "${HOME}/.local/bin/${tool}")" = 'existing tool'
  test "$(grep -c '^smoke$' "${TEST_LOG}")" = 2
done

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

# 已登录不需要 token；未登录时登录成功后以前台方式启动 daemon。
cp "${TEST_FIXTURES}/multica" "${HOME}/.local/bin/multica"
chmod +x "${HOME}/.local/bin/multica"
export PATH="${HOME}/.local/bin:${PATH}"
TEST_AUTHENTICATED=1 bash "${SCRIPT_DIR}/start-multica.sh"
MULTICA_TOKEN=test-token bash "${SCRIPT_DIR}/start-multica.sh"
test "$(grep -c '^login$' "${TEST_LOG}")" = 1
test "$(grep -c '^daemon$' "${TEST_LOG}")" = 2
if env -u MULTICA_TOKEN bash "${SCRIPT_DIR}/start-multica.sh"; then
  printf 'Expected missing token to fail\n' >&2
  exit 1
fi
printf 'Runtime script tests passed.\n'
