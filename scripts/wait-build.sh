#!/usr/bin/env bash
# 等指定提交触发的镜像构建工作流结束；"上线"即构建成功。
# 两个构建工作流都有 push paths 过滤：先按改动文件判断这次提交该不该触发它——
# 确认不触发才跳过；该触发却迟迟没出现 run、或任何 GitHub 查询失败，都按失败处理。
# 用法：GH_TOKEN=... scripts/wait-build.sh <完整提交 sha>（make deploy 传当前检出的 HEAD，回滚时即回滚目标）
set -euo pipefail

sha=${1:?用法：wait-build.sh <sha>}
workflows=(build-devcontainer.yml build-devcontainer-java.yml)
appear_timeout=${APPEAR_TIMEOUT:-120}
finish_timeout=${FINISH_TIMEOUT:-3600}
interval=${POLL_INTERVAL:-15}

log() {
  printf '[wait-build] %s\n' "$*" >&2
}

# 该提交改动的文件，每行一个；查询失败直接退出
changed_files() {
  local files
  files=$(gh api "repos/${GITHUB_REPOSITORY:?}/commits/$sha" --jq '.files[].filename') || {
    log "查询提交 $sha 的改动文件失败。"
    return 1
  }
  printf '%s\n' "$files"
}

# 工作流的 push paths 是否命中改动文件：命中返回 0，确认不命中返回 10，其余（含 python 异常）都是错误。
# 不能用 1 表示未命中：python 未捕获异常的退出码就是 1
triggers_build() {
  local wf=$1 files=$2
  FILES=$files python3 - ".github/workflows/$wf" <<'PY'
import os, re, sys, yaml

def to_regex(glob):
    out, i = "", 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out += "(?:.*/)?"; i += 3
        elif glob.startswith("**", i):
            out += ".*"; i += 2
        elif glob[i] == "*":
            out += "[^/]*"; i += 1
        elif glob[i] == "?":
            out += "[^/]"; i += 1
        else:
            out += re.escape(glob[i]); i += 1
    return re.compile("^" + out + "$")

doc = yaml.safe_load(open(sys.argv[1]))
push = (doc.get("on") or doc.get(True) or {})["push"]
paths = push.get("paths")
if not paths:
    sys.exit(0)  # 没有 paths 过滤：每次 push 都触发
regexes = [to_regex(p) for p in paths]
files = [f for f in os.environ["FILES"].splitlines() if f]
sys.exit(0 if any(r.match(f) for r in regexes for f in files) else 10)
PY
}

wait_workflow() {
  local wf=$1 files=$2 start now run status conclusion rc
  rc=0
  triggers_build "$wf" "$files" || rc=$?
  case $rc in
    0) ;;
    10) log "$wf：改动文件不命中 push paths，确认本次提交不触发它，跳过。"; return 0 ;;
    *) log "$wf：解析 push paths 失败（退出码 $rc）。"; return 1 ;;
  esac
  start=$(date +%s)
  while :; do
    run=$(gh run list --workflow "$wf" --commit "$sha" --event push --limit 1 \
      --json status,conclusion --jq '.[0] // empty') || {
      log "$wf：查询 run 失败。"
      return 1
    }
    now=$(date +%s)
    if [ -z "$run" ]; then
      if [ $((now - start)) -ge "$appear_timeout" ]; then
        log "$wf：本次提交应当触发它，但 ${appear_timeout}s 内没有出现 run。"
        return 1
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

python3 -c 'import yaml' || { log '缺少 python3 的 PyYAML。'; exit 1; }
files=$(changed_files)
rc=0
for wf in "${workflows[@]}"; do
  wait_workflow "$wf" "$files" || rc=1
done
exit "$rc"
