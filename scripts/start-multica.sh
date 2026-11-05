#!/usr/bin/env bash
# 由 mise exec 提供 provider 的真实 PATH，不使用 mise shims 启动 agent。
set -euo pipefail

if ! multica auth status >/dev/null 2>&1; then
  multica login --token "${MULTICA_TOKEN:?请配置 MULTICA_TOKEN}"
fi
exec multica daemon start --foreground
