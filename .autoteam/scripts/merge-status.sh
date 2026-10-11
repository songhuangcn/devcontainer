#!/usr/bin/env bash
# 核对一个 PR 的自动合并是否真的开了。merge-mode.sh 输出 platform 只说明「应该开」，
# 不说明「已经开」：Implementer 可能漏跑 `gh pr merge --auto`。
# 用法：.autoteam/scripts/merge-status.sh <PR 编号>
#
# merged  已合并
# queued  已在合并队列里（条件满足时 `gh pr merge --auto` 直接入队，autoMergeRequest 仍为空）
# auto    已开自动合并，等审批和检查
# none    没合并、不在队列、没开自动合并——platform 模式下要补开
# closed  已关闭且没合并
#
# 查询失败时不输出结果、退出码非 0，不要当成 none 处理。依赖 gh、jq、git。
set -o pipefail

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

pr=${1:-}
case $pr in
  ''|*[!0-9]*) echo "用法：merge-status.sh <PR 编号>" >&2; exit 2 ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
conf="$root/.autoteam/autoteam.conf"
repo=$(sed -n 's/^AUTOTEAM_REPO=//p' "$conf" 2>/dev/null | tail -n 1 | tr -d '[:space:]')
[ -n "$repo" ] || repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
case $repo in
  */*) ;;
  *) echo "merge-status.sh：读不出仓库（AUTOTEAM_REPO）" >&2; exit 1 ;;
esac

# gh pr view --json 没有合并队列字段，只能走 GraphQL
# shellcheck disable=SC2016  # $owner 等是 GraphQL 变量，不是 shell 变量
query='query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) { state isInMergeQueue autoMergeRequest { enabledAt } }
  }
}'
if ! out=$(gh api graphql -f query="$query" -f owner="${repo%%/*}" -f name="${repo#*/}" -F number="$pr"); then
  echo "merge-status.sh：查询 PR #$pr 失败" >&2
  exit 1
fi

status=$(printf '%s' "$out" | jq -r '.data.repository.pullRequest // empty |
  if .state == "MERGED" then "merged"
  elif .state == "CLOSED" then "closed"
  elif .isInMergeQueue then "queued"
  elif .autoMergeRequest != null then "auto"
  else "none" end' 2>/dev/null)
if [ -z "$status" ]; then
  echo "merge-status.sh：$repo 里找不到 PR #$pr" >&2
  exit 1
fi
echo "$status"
