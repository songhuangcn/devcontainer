#!/usr/bin/env bash
set -euo pipefail

tools=(codex claude opencode)
mise_path="$(readlink -f "$(command -v mise)")"
smoke_dir="$(mktemp -d)"
trap 'rmdir "${smoke_dir}"' EXIT

for tool in "${tools[@]}"; do
  launcher="$(command -v "${tool}")"
  resolved="$(readlink -f "${launcher}")"

  if [[ "${resolved}" == "${mise_path}" ]]; then
    printf '%s resolves to the mise task runner: %s\n' "${tool}" "${launcher}" >&2
    exit 1
  fi

  version="$(cd "${smoke_dir}" && "${resolved}" --version 2>&1)"
  if [[ "${version}" == mise\ * ]]; then
    printf '%s returned the mise version from an empty workdir: %s\n' \
      "${tool}" "${version}" >&2
    exit 1
  fi

  printf '%s -> %s (%s)\n' "${tool}" "${resolved}" "${version%%$'\n'*}"
done
