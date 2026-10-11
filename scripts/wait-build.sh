#!/usr/bin/env bash
# 等指定提交触发的镜像构建工作流结束；"上线"即构建成功。
# 两个构建工作流都有 paths 过滤：宽限期内始终没出现 run，说明这次提交不触发它，直接跳过。
# 用法：GH_TOKEN=... scripts/wait-build.sh <完整提交 sha>（make deploy 传当前检出的 HEAD，回滚时即回滚目标）
set -euo pipefail

sha=${1:?用法：wait-build.sh <sha>}
workflows=(build-devcontainer.yml build-devcontainer-java.yml)
appear_timeout=${APPEAR_TIMEOUT:-120}
finish_timeout=${FINISH_TIMEOUT:-3600}
interval=${POLL_INTERVAL:-15}

log() {
  printf '[wait-build] %s\n' "$*"
}

wait_workflow() {
  local wf=$1 start now run status conclusion
  start=$(date +%s)
  while :; do
    run=$(gh run list --workflow "$wf" --commit "$sha" --event push --limit 1 \
      --json status,conclusion --jq '.[0] // empty')
    now=$(date +%s)
    if [ -z "$run" ]; then
      if [ $((now - start)) -ge "$appear_timeout" ]; then
        log "$wf：${appear_timeout}s 内没有出现 run，本次提交不触发它，跳过。"
        return 0
      fi
    else
      status=$(jq -r .status <<<"$run")
      conclusion=$(jq -r .conclusion <<<"$run")
      if [ "$status" = completed ]; then
        if [ "$conclusion" = success ]; then
          log "$wf：构建成功。"
          return 0
        fi
        log "$wf：构建结束但结论是 $conclusion。"
        return 1
      fi
      if [ $((now - start)) -ge "$finish_timeout" ]; then
        log "$wf：等待超过 ${finish_timeout}s 仍未结束（$status）。"
        return 1
      fi
    fi
    sleep "$interval"
  done
}

rc=0
for wf in "${workflows[@]}"; do
  wait_workflow "$wf" || rc=1
done
exit "$rc"
