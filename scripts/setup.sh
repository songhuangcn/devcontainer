#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DATA_DIR="${ROOT_DIR}/data"
ENV_FILE="${ROOT_DIR}/.env"
ENV_SAMPLE="${ROOT_DIR}/.env.sample"

if [ -f "${ENV_FILE}" ]; then
  printf '[setup] .env already exists; keep existing file.\n'
else
  cp "${ENV_SAMPLE}" "${ENV_FILE}"
  printf '[setup] created .env from .env.sample.\n'
fi

# 在宿主机创建 home 卷根，避免 Docker daemon 以 root 身份创建它。
# 配置链接由容器内的 start.sh 创建。
mkdir -p "${DATA_DIR}"
printf '[setup] prepared persistent home directory under ./data.\n'
