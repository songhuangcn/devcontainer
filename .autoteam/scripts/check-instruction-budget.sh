#!/usr/bin/env bash
# Check line limits for role, autopilot and runbook instructions listed in a budget file.
set -euo pipefail

budget=${1:-.autoteam/instruction-budget}
[ -f "$budget" ] || { echo "指令预算文件不存在：$budget" >&2; exit 1; }
failed=0
while read -r limit path extra; do
  case ${limit:-} in ''|'#'*) continue ;; esac
  if [[ ! $limit =~ ^[0-9]+$ || -z ${path:-} || -n ${extra:-} || $path = /* || $path = *..* ]]; then
    echo "无效的指令预算行：$limit ${path:-} ${extra:-}" >&2
    failed=1
    continue
  fi
  if [ ! -f "$path" ]; then
    case $path in .autoteam/instructions/*) continue ;; esac # Only ejected instructions are optional.
    echo "指令预算对应文件不存在：$path" >&2
    failed=1
    continue
  fi
  lines=$(awk 'END { print NR }' "$path")
  if (( lines > limit )); then
    echo "指令超预算：$path ($lines > $limit 行)。先删 / 合并旧规则，或由人批准提高预算。" >&2
    failed=1
  fi
done < "$budget"
for dir in skills/autoteam/instructions/roles skills/autoteam/instructions/autopilots skills/autoteam/instructions/runbooks \
  .autoteam/instructions/roles .autoteam/instructions/autopilots .autoteam/instructions/runbooks; do
  for path in "$dir"/*.md; do
    [ -f "$path" ] || continue
    if ! awk -v p="$path" '$2 == p { found=1 } END { exit !found }' "$budget"; then
      echo "指令缺少预算：$path" >&2
      failed=1
    fi
  done
done
exit "$failed"
