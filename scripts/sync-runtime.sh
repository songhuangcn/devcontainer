#!/usr/bin/env bash
# 更新持久化仓库；保留未提交改动，冲突时停止，不使用强制检出或清理。
set -euo pipefail

repository="${RUNTIME_REPOSITORY:-https://github.com/songhuangcn/devcontainer.git}"
revision="${RUNTIME_REVISION:?请指定 RUNTIME_REVISION}"
directory="${1:-/workspace/.devcontainer}"

mkdir -p -- "$(dirname -- "${directory}")"
exec 9>"${directory}.sync.lock"
flock 9

if [ -L "${directory}" ]; then
  printf 'Refusing to update a symlinked runtime directory: %s\n' "${directory}" >&2
  exit 1
fi
mkdir -p -- "${directory}"
directory="$(cd -- "${directory}" && pwd -P)"
if [ ! -e "${directory}/.git" ]; then
  if [ -n "$(find "${directory}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    printf 'Runtime directory is not empty; existing files were left untouched: %s\n' "${directory}" >&2
    exit 1
  fi
  git init -q "${directory}"
  git -C "${directory}" remote add origin "${repository}"
fi

if [ "$(git -C "${directory}" rev-parse --show-toplevel)" != "${directory}" ] || \
   [ "$(git -C "${directory}" remote get-url origin)" != "${repository}" ]; then
  printf 'Runtime directory belongs to a different repository; refusing to overwrite it: %s\n' "${directory}" >&2
  exit 1
fi

git -C "${directory}" fetch --no-tags origin "${revision}"
target="$(git -C "${directory}" rev-parse FETCH_HEAD)"
current="$(git -C "${directory}" rev-parse --verify HEAD 2>/dev/null || true)"
deployed="$(git -C "${directory}" rev-parse --verify refs/workspace/deployed 2>/dev/null || true)"
# 保存旧 HEAD 的引用，避免用户在 detached HEAD 上提交的内容变成不可达对象。
if [ -n "${current}" ] && [ "${current}" != "${target}" ]; then
  git -C "${directory}" update-ref "refs/workspace/saved-heads/${current}" "${current}"
  if [ "${current}" != "${deployed}" ] && ! git -C "${directory}" merge-base --is-ancestor "${current}" "${target}"; then
    printf 'Runtime has local commits not included in the target revision. Push or integrate them before retrying; the working tree was left unchanged: %s\n' "${directory}" >&2
    exit 1
  fi
fi
if ! git -C "${directory}" checkout --detach "${target}"; then
  printf 'Runtime update stopped. Local changes were preserved in %s; resolve checkout conflicts before retrying.\n' "${directory}" >&2
  exit 1
fi
git -C "${directory}" update-ref refs/workspace/deployed "${target}"
