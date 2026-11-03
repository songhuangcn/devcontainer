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
  # 在宿主机创建 home 卷根，避免 Docker daemon 以 root 身份创建它。
  # 配置链接由容器内的 setup-user.sh 创建，不再使用嵌套文件挂载。
  mkdir -p "${DATA_DIR}"

  log 'prepared persistent home directory under ./data.'
}

create_env
prepare_persistent_files
