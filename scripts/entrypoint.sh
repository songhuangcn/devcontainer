#!/usr/bin/env bash
# 从系统默认模板补齐 home 中缺失的文件，不覆盖已有用户文件。
set -euo pipefail

cp -r --update=none /etc/skel/. "${HOME}/"

if [ $# -gt 0 ]; then
  exec "$@"
fi
