#!/usr/bin/env bash
# 镜像 ENTRYPOINT 补齐系统默认文件后，在运行时准备用户配置再启动应用。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/setup-user.sh"
exec "$@"
