#!/usr/bin/env bash
# 使用本地 Git 仓库验证更新与冲突保护，不访问远端服务。
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(mktemp -d)"
trap 'rm -rf -- "${root}"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
export RUNTIME_REPOSITORY="${root}/upstream"

git init -q -b main "${RUNTIME_REPOSITORY}"
mkdir "${RUNTIME_REPOSITORY}/config"
printf 'version = 1\n' > "${RUNTIME_REPOSITORY}/config/mise.toml"
git -C "${RUNTIME_REPOSITORY}" add .
git -C "${RUNTIME_REPOSITORY}" commit -qm initial
export RUNTIME_REVISION
RUNTIME_REVISION="$(git -C "${RUNTIME_REPOSITORY}" rev-parse HEAD)"
directory="${root}/workspace/.devcontainer"

bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${directory}"
test "$(git -C "${directory}" rev-parse HEAD)" = "${RUNTIME_REVISION}"
printf 'version = 2\n' > "${directory}/config/mise.toml"
printf 'user file\n' > "${directory}/untracked"
bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${directory}"
test "$(cat "${directory}/config/mise.toml")" = 'version = 2'

# 上游改其他文件时可以更新，配置和未跟踪文件仍然保留。
printf 'upstream addition\n' > "${RUNTIME_REPOSITORY}/new-file"
git -C "${RUNTIME_REPOSITORY}" add .
git -C "${RUNTIME_REPOSITORY}" commit -qm unrelated
RUNTIME_REVISION="$(git -C "${RUNTIME_REPOSITORY}" rev-parse HEAD)"
bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${directory}"
test -f "${directory}/new-file"
test "$(cat "${directory}/config/mise.toml")" = 'version = 2'
test "$(cat "${directory}/untracked")" = 'user file'
previous="${RUNTIME_REVISION}"

# 上游与用户修改同一文件时拒绝切换，不清理、不覆盖、不隐式 stash。
printf 'version = 3\n' > "${RUNTIME_REPOSITORY}/config/mise.toml"
git -C "${RUNTIME_REPOSITORY}" add .
git -C "${RUNTIME_REPOSITORY}" commit -qm conflicting
RUNTIME_REVISION="$(git -C "${RUNTIME_REPOSITORY}" rev-parse HEAD)"
if bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${directory}"; then
  printf 'Expected checkout conflict to stop the update\n' >&2
  exit 1
fi
test "$(git -C "${directory}" rev-parse HEAD)" = "${previous}"
test "$(cat "${directory}/config/mise.toml")" = 'version = 2'
test "$(cat "${directory}/untracked")" = 'user file'
test -z "$(git -C "${directory}" stash list)"

# 未集成的用户提交不能被目标版本替换，detached HEAD 提交也有引用保护。
git -C "${directory}" add config/mise.toml
git -C "${directory}" commit -qm local-edit
local_commit="$(git -C "${directory}" rev-parse HEAD)"
if bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${directory}"; then
  printf 'Expected unpublished local commits to stop the update\n' >&2
  exit 1
fi
test "$(git -C "${directory}" rev-parse HEAD)" = "${local_commit}"
test "$(cat "${directory}/config/mise.toml")" = 'version = 2'
test "$(git -C "${directory}" rev-parse "refs/workspace/saved-heads/${local_commit}")" = "${local_commit}"
test "$(git -C "${directory}" show "${local_commit}:config/mise.toml")" = 'version = 2'

# 目标版本包含用户提交后，正常更新，不丢失配置修改。
git -C "${RUNTIME_REPOSITORY}" fetch -q "${directory}" "${local_commit}"
git -C "${RUNTIME_REPOSITORY}" checkout -q --detach FETCH_HEAD
printf 'integrated\n' > "${RUNTIME_REPOSITORY}/integrated"
git -C "${RUNTIME_REPOSITORY}" add .
git -C "${RUNTIME_REPOSITORY}" commit -qm integrated
RUNTIME_REVISION="$(git -C "${RUNTIME_REPOSITORY}" rev-parse HEAD)"
bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${directory}"
test "$(git -C "${directory}" rev-parse HEAD)" = "${RUNTIME_REVISION}"
test "$(cat "${directory}/config/mise.toml")" = 'version = 2'

# 不接管已有非仓库目录或其他仓库。
mkdir "${root}/occupied"
printf 'existing\n' > "${root}/occupied/file"
if bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${root}/occupied"; then
  printf 'Expected occupied directory to be preserved\n' >&2
  exit 1
fi
test "$(cat "${root}/occupied/file")" = existing
test ! -e "${root}/occupied/.git"
git -C "${directory}" remote set-url origin other-repository
if bash "${ROOT_DIR}/scripts/sync-runtime.sh" "${directory}"; then
  printf 'Expected unrelated repository to be preserved\n' >&2
  exit 1
fi
test "$(git -C "${directory}" remote get-url origin)" = other-repository
printf 'Runtime repository sync tests passed.\n'
