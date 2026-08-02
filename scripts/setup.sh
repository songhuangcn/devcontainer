#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DATA_DIR="${ROOT_DIR}/data"
ENV_FILE="${ROOT_DIR}/.env"
ENV_SAMPLE="${ROOT_DIR}/.env.sample"
PERSISTENT_FILES=(
  .claude.json
)

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
}

prepare_persistent_files() {
  local file

  mkdir -p "${DATA_DIR}/.openclaw"

  for file in "${PERSISTENT_FILES[@]}"; do
    touch "${DATA_DIR}/${file}"
  done

  log 'prepared required bind-mounted files under ./data.'
}

create_env
prepare_persistent_files
