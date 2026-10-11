#!/usr/bin/env bash
# Implementer 交付用：开 PR，并按 merge-mode.sh 的结果决定开不开自动合并、核对确实开了。
# 用法：.autoteam/scripts/open-pr.sh --title "<任务编号> <标题>" --body-file <文件>
#       .autoteam/scripts/open-pr.sh <PR 编号>      只核对、补开（返工时用）
# 先把分支推上去。当前分支已有打开的 PR 时不再新开，只核对、补开。
# merge-mode.sh 按默认分支的规则判断，所以只处理目标分支是默认分支、还开着（或已合并）的 PR。
#
# platform  开 PR，`gh pr merge --auto --squash`，用 merge-status.sh 核对；none 就重试一次
# staged    开 draft PR，不开自动合并，由 Reviewer 批准后放行
# reviewer  开 PR，绝不执行 gh pr merge（这种仓库里 --auto 会立即合并），由 Reviewer 合并
#
# 输出 PR 链接、合并模式、自动合并核对结果，原样贴进任务评论。platform 下核对不到
# merged / queued / auto、查询失败或 PR 已关闭时返回非 0 并打印原因。依赖 gh、jq、git。
set -o pipefail

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }
fail() { echo "open-pr.sh：$*" >&2; exit 1; }

title="" body_file="" pr=""
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --title|--body-file)
      [ $# -ge 2 ] && [ -n "$2" ] || { echo "open-pr.sh：$1 缺少值" >&2; usage >&2; exit 2; }
      if [ "$1" = --title ]; then title=$2; else body_file=$2; fi
      shift 2 ;;
    *[!0-9]*|'') usage >&2; exit 2 ;;
    *) pr=$1; shift ;;
  esac
done

here=$(cd "$(dirname "$0")" && pwd)
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
repo=$(sed -n 's/^AUTOTEAM_REPO=//p' "$root/.autoteam/autoteam.conf" 2>/dev/null | tail -n 1 | tr -d '[:space:]')
repo_args=()
[ -n "$repo" ] && repo_args=(--repo "$repo")

# 和 merge-mode.sh 用同一个默认分支
base=$(sed -n 's/^AUTOTEAM_DEFAULT_BRANCH=//p' "$root/.autoteam/autoteam.conf" 2>/dev/null | tail -n 1 | tr -d '[:space:]')
[ -n "$base" ] || base=$(gh repo view ${repo:+"$repo"} --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
[ -n "$base" ] || fail "读不出默认分支（AUTOTEAM_DEFAULT_BRANCH）"

mode=$(bash "$here/merge-mode.sh")
[ -n "$mode" ] || fail "merge-mode.sh 没有输出"

if [ -z "$pr" ]; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || fail "读不出当前分支（detached HEAD？）"
  existing=$(gh pr list ${repo_args[@]+"${repo_args[@]}"} --head "$branch" --state open \
               --json number --jq '.[0].number // empty') || fail "查询分支 $branch 的 PR 失败"
  if [ -n "$existing" ]; then
    pr=$existing
    echo "分支 $branch 已有 PR #$pr，不再新开，只核对"
  else
    [ -n "$title" ] && [ -f "$body_file" ] || fail "新开 PR 要给 --title 和存在的 --body-file"
    draft=()
    [ "$mode" = staged ] && draft=(--draft)
    url=$(gh pr create ${repo_args[@]+"${repo_args[@]}"} --base "$base" --head "$branch" --title "$title" \
            --body-file "$body_file" ${draft[@]+"${draft[@]}"}) || fail "gh pr create 失败"
    pr=${url##*/}
    case $pr in ''|*[!0-9]*) fail "读不出新 PR 的编号：$url" ;; esac
  fi
fi

info=$(gh pr view "$pr" ${repo_args[@]+"${repo_args[@]}"} --json url,state,baseRefName \
         --jq '[.url, .state, .baseRefName] | join(" ")') || fail "查询 PR #$pr 失败"
read -r url state pr_base <<<"$info"
echo "PR：$url"
[ "$pr_base" = "$base" ] ||
  fail "PR #$pr 的目标分支是 ${pr_base:-未知}，不是默认分支 $base；合并模式按 $base 的规则判断，不适用，不处理"
[ "$state" = CLOSED ] && fail "PR #$pr 已关闭"
echo "合并模式：$mode"

case $mode in
  staged) echo "自动合并：不开（staged：draft PR，由 Reviewer 批准后放行）"; exit 0 ;;
  reviewer) echo "自动合并：不开（reviewer：没有平台闸门，由 Reviewer 批准并合并）"; exit 0 ;;
  platform) ;;
  *) fail "不认识的合并模式：$mode" ;;
esac

status=$(bash "$here/merge-status.sh" "$pr") || fail "merge-status.sh 查询失败"
tries=0
while [ "$status" = none ] && [ "$tries" -lt 2 ]; do
  tries=$((tries + 1))
  err=$(gh pr merge "$pr" ${repo_args[@]+"${repo_args[@]}"} --auto --squash 2>&1 >/dev/null) ||
    echo "第 $tries 次 gh pr merge --auto 报错：$err" >&2
  status=$(bash "$here/merge-status.sh" "$pr") || fail "merge-status.sh 查询失败"
done

case $status in
  merged|queued|auto) echo "自动合并：$status" ;;
  none) echo "自动合并：none"; fail "开了 $tries 次自动合并仍是 none，把上面的报错原文写进任务评论" ;;
  *) echo "自动合并：$status"; fail "PR #$pr 状态是 $status，不能开自动合并" ;;
esac
