#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DATA_DIR="${ROOT_DIR}/data"
ENV_FILE="${ROOT_DIR}/.env"
ENV_SAMPLE="${ROOT_DIR}/.env.sample"

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
  # ./data 整挂到 /home/ubuntu，其余目录由镜像首启的 devcontainer-home-init 从
  # /opt/home-skel 补进来。这里只预建 config/ 那四条嵌套挂载的父目录：缺失时
  # Docker daemon 会以 root 身份创建挂载点父目录，容器内的 ubuntu 就写不进去。
  mkdir -p \
    "${DATA_DIR}/.claude" \
    "${DATA_DIR}/.codex" \
    "${DATA_DIR}/.config/opencode"

  log 'prepared nested bind-mount parent directories under ./data.'
}

create_env
prepare_persistent_files
