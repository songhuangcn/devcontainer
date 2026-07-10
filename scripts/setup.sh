#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${ROOT_DIR}/.env"
ENV_SAMPLE="${ROOT_DIR}/.env.sample"
DATA_DIR="${ROOT_DIR}/data"
CONTAINER_HOME="/home/ubuntu"

log() {
  printf '[setup] %s\n' "$*"
}

create_env() {
  if [ -f "${ENV_FILE}" ]; then
    log '.env already exists; keep existing file.'
  else
    cp "${ENV_SAMPLE}" "${ENV_FILE}"
    log 'created .env from .env.sample.'
  fi

  log '请按需编辑 .env，重点检查 IMAGE_NAME、IMAGE_TAG、OPENCODE_PORT 和 OPENCODE_AUTO_START。'
}

load_env() {
  set -a
  # shellcheck disable=SC1090
  . "${ENV_FILE}"
  set +a
}

sync_home_from_image() {
  local image="${IMAGE_NAME:-songhuangcn/devcontainer}:${IMAGE_TAG:-latest}"

  if ! command -v docker >/dev/null 2>&1; then
    log 'docker command not found; skip image home sync.'
    return 0
  fi

  if ! docker info >/dev/null 2>&1; then
    log 'docker daemon is unavailable; skip image home sync.'
    return 0
  fi

  mkdir -p "${DATA_DIR}"
  log "syncing missing files from ${image}:${CONTAINER_HOME} to ./data"

  if docker run --rm \
    --entrypoint bash \
    -e CONTAINER_HOME="${CONTAINER_HOME}" \
    -v "${DATA_DIR}:/target" \
    "${image}" \
    -lc 'set -euo pipefail; if [ -d "${CONTAINER_HOME}" ]; then tar -C "${CONTAINER_HOME}" --ignore-failed-read -cf - . | tar -C /target -xf - --skip-old-files; fi'; then
    log 'home sync complete.'
  else
    log 'home sync failed; please check Docker access or run `make pull` first.'
  fi
}

remove_legacy_home_mise_activation() {
  local bashrc="${DATA_DIR}/.bashrc"
  local tmp

  if [ -f "${bashrc}" ] && grep -q '/home/ubuntu/.local/bin/mise activate bash' "${bashrc}"; then
    tmp="$(mktemp "${bashrc}.XXXXXX")"
    grep -v -F '/home/ubuntu/.local/bin/mise activate bash' "${bashrc}" >"${tmp}" || true
    mv "${tmp}" "${bashrc}"
    log 'removed legacy home mise activation from ./data/.bashrc.'
  fi
}

create_env
load_env
sync_home_from_image
remove_legacy_home_mise_activation
