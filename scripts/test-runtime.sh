#!/usr/bin/env bash
# 在临时 home 和命令替身中验证行为，不安装依赖、不改真实用户数据。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(mktemp -d)"
trap 'rm -rf -- "${root}"' EXIT
export HOME="${root}/home"
mkdir -p "${HOME}"
chmod 700 "${HOME}"

# Compose 在启动容器之前准备 home 卷根；重复 setup 保留配置、数据和权限。
setup_root="${root}/workspace/.devcontainer"
mkdir -p "${setup_root}/scripts"
cp "${SCRIPT_DIR}/setup.sh" "${setup_root}/scripts/setup.sh"
printf 'TEST_SETTING=default\n' > "${setup_root}/.env.sample"
bash "${setup_root}/scripts/setup.sh"
cmp "${setup_root}/.env.sample" "${setup_root}/.env"
test -d "${setup_root}/data"
test -w "${setup_root}/data"
test "$(stat -c %u "${setup_root}/data")" = "$(id -u)"
printf 'TEST_SETTING=custom\n' > "${setup_root}/.env"
printf 'user data\n' > "${setup_root}/data/existing"
chmod 700 "${setup_root}/data"
bash "${setup_root}/scripts/setup.sh"
test "$(cat "${setup_root}/.env")" = 'TEST_SETTING=custom'
test "$(cat "${setup_root}/data/existing")" = 'user data'
test "$(stat -c %a "${setup_root}/data")" = 700

# 安装命令用一次性容器引导工具，不依赖已启动的服务，并向上传递失败。
cp "${SCRIPT_DIR}/../Makefile" "${setup_root}/Makefile"
make_bin="${root}/make-bin"
mkdir -p "${make_bin}"
export TEST_COMPOSE_LOG="${root}/compose.log"
cat > "${make_bin}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${TEST_COMPOSE_LOG}"
exit "${TEST_COMPOSE_EXIT:-0}"
SH
chmod +x "${make_bin}/docker"
PATH="${make_bin}:${PATH}" make --no-print-directory -C "${setup_root}" install
test "$(cat "${TEST_COMPOSE_LOG}")" = \
  'compose -f docker-compose.yml run --rm --no-deps -T opencode bash /workspace/.devcontainer/scripts/install.sh'
test "$(cat "${setup_root}/.env")" = 'TEST_SETTING=custom'
test "$(cat "${setup_root}/data/existing")" = 'user data'
if PATH="${make_bin}:${PATH}" TEST_COMPOSE_EXIT=23 make --no-print-directory -C "${setup_root}" install; then
  printf 'Expected container installation failure to fail make install\n' >&2
  exit 1
fi

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

# 使用隔离仓库测试配置迁移、双向写回和源文件的原子替换。
runtime="${root}/runtime"
mkdir -p "${runtime}/agents/skills/example" "${HOME}/.config/mise" \
  "${HOME}/.agents" "${HOME}/.claude/skills/legacy"
cp -a "${SCRIPT_DIR}" "${runtime}/scripts"
cp -a "${SCRIPT_DIR}/../config" "${runtime}/config"
printf 'instructions\n' > "${runtime}/agents/AGENTS.md"
printf 'skill\n' > "${runtime}/agents/skills/example/SKILL.md"
printf 'legacy mise config\n' > "${HOME}/.config/mise/config.toml"
printf 'legacy agents\n' > "${HOME}/.agents/AGENTS.md"
printf 'legacy instructions\n' > "${HOME}/.claude/CLAUDE.md"
printf 'legacy skill\n' > "${HOME}/.claude/skills/legacy/SKILL.md"
bash "${runtime}/scripts/setup-user.sh"
test "$(readlink "${HOME}/.config/mise/config.toml")" = "${runtime}/config/mise.toml"
test "$(cat "${HOME}/.config/mise/config.toml.before-workspace-link")" = 'legacy mise config'
test "$(cat "${HOME}/.agents.before-workspace-link/AGENTS.md")" = 'legacy agents'
printf '\n# edited in home\n' >> "${HOME}/.config/mise/config.toml"
grep -q '# edited in home' "${runtime}/config/mise.toml"
cp "${runtime}/config/mise.toml" "${runtime}/config/mise.new"
printf '# atomically replaced source\n' >> "${runtime}/config/mise.new"
mv "${runtime}/config/mise.new" "${runtime}/config/mise.toml"
grep -q '# atomically replaced source' "${HOME}/.config/mise/config.toml"
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="${HOME}/.gitconfig" git config --global workspace.test true
test "$(git config -f "${runtime}/config/.gitconfig" workspace.test)" = true
test -L "${HOME}/.gitconfig"
rc=0
bash "${runtime}/scripts/start.sh" bash -c 'test "$1" = "two words"; exit 23' -- 'two words' || rc=$?
test "${rc}" = 23

# 隔离测试所用的旧镜像环境；被测脚本仅使用 mise 默认用户目录。
unset MISE_INSTALL_PATH MISE_DATA_DIR MISE_CACHE_DIR MISE_STATE_DIR
export TEST_BIN="${root}/bin" TEST_LOG="${root}/commands.log" TEST_FIXTURES="${root}/fixtures"
export TMPDIR="${root}/tmp"
mkdir -p "${TEST_BIN}" "${TEST_FIXTURES}" "${TMPDIR}"

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

bash "${runtime}/scripts/install.sh"
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
bash "${runtime}/scripts/install.sh"
test "$(grep -c '^download https://mise.run$' "${TEST_LOG}")" = 1
test "$(grep -c '^mise install --yes (' "${TEST_LOG}")" = 2
test "$(grep -c '^smoke$' "${TEST_LOG}")" = 2
test -z "$(ls -A "${TMPDIR}")"

# 校验失败不能覆盖旧工具，也不能继续 smoke。
for tool in multica autoteam; do
  printf 'existing tool\n' > "${HOME}/.local/bin/${tool}"
  if TEST_FAIL_CHECKSUM="${tool}" bash "${runtime}/scripts/install.sh"; then
    printf 'Expected checksum failure for %s\n' "${tool}" >&2
    exit 1
  fi
  test "$(cat "${HOME}/.local/bin/${tool}")" = 'existing tool'
  test "$(grep -c '^smoke$' "${TEST_LOG}")" = 2
done

# 已有备份时拒绝覆盖；依赖安装失败时不得继续执行 smoke。
rm "${HOME}/.claude/CLAUDE.md"
printf 'new instructions\n' > "${HOME}/.claude/CLAUDE.md"
if bash "${runtime}/scripts/install.sh"; then
  printf 'Expected backup conflict to fail\n' >&2
  exit 1
fi
test "$(cat "${HOME}/.claude/CLAUDE.md")" = 'new instructions'
rm "${HOME}/.claude/CLAUDE.md"
ln -s ../.agents/AGENTS.md "${HOME}/.claude/CLAUDE.md"
cat > "${HOME}/.local/bin/mise" <<'SH'
#!/usr/bin/env bash
exit 42
SH
rc=0
bash "${runtime}/scripts/install.sh" || rc=$?
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
bash "${SCRIPT_DIR}/test-sync-runtime.sh"
printf 'Runtime script tests passed.\n'
