#!/usr/bin/env bash
# 判断这个仓库的 PR 由谁放行、由谁合并。Implementer 开 PR 前、Reviewer 批准后各跑一次。
# 用法：.autoteam/scripts/merge-mode.sh
#
# platform  规则集要求至少 1 个审批，检查也由平台强制。Implementer 正常开 PR 并
#           `gh pr merge <PR> --auto --squash`；Reviewer 用 `gh pr review --approve` 放行；
#           平台在审批和检查都通过后自己合并。
# staged    检查由平台强制，但规则集不要求审批——写代码和评审是同一个 GitHub 账号时只能这样，
#           GitHub 不允许作者批准自己的 PR。Implementer 开 draft PR 且不开自动合并：draft
#           本来就不能开自动合并，正好挡住"检查一绿就合并、Reviewer 来不及看"。Reviewer 批准后
#           `gh pr ready <PR>` 再 `gh pr merge <PR> --auto --squash`，检查仍然绕不过。
# reviewer  没有平台闸门（比如 GitHub Free 的私有仓库）。绝对不要开自动合并——这种仓库里
#           `gh pr merge --auto` 不报错，而是立即合并，绕过评审和检查。由 Reviewer 批准、
#           确认检查全绿之后 `gh pr merge <PR> --squash --delete-branch`。
#
# 查不到（没权限、网络错误）时按 reviewer 处理。依赖 gh、jq、git。
set -o pipefail

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
conf="$root/.autoteam/autoteam.conf"
repo=$(sed -n 's/^AUTOTEAM_REPO=//p' "$conf" 2>/dev/null | tail -n 1 | tr -d '[:space:]')
[ -n "$repo" ] || repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
branch=$(sed -n 's/^AUTOTEAM_DEFAULT_BRANCH=//p' "$conf" 2>/dev/null | tail -n 1 | tr -d '[:space:]')
[ -n "$branch" ] || branch=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null)

auto=$(gh api "repos/$repo" --jq '.allow_auto_merge' 2>/dev/null)
# 这个接口返回的是该分支实际生效的全部规则（规则集和分支保护合并后的结果），
# 比按名字找规则集准确：别人另建的规则集、老的分支保护一样算数。
rules=$(gh api "repos/$repo/rules/branches/$branch" 2>/dev/null)

checks=0
approvals=0
if [ -n "$rules" ]; then
  checks=$(printf '%s' "$rules" | jq '[.[] | select(.type == "required_status_checks")] | length' 2>/dev/null)
  approvals=$(printf '%s' "$rules" |
    jq '[.[] | select(.type == "pull_request") | .parameters.required_approving_review_count // 0] | max // 0' 2>/dev/null)
fi

if [ "$auto" = true ] && [ "${checks:-0}" -ge 1 ] 2>/dev/null; then
  if [ "${approvals:-0}" -ge 1 ] 2>/dev/null; then
    echo platform
  else
    echo staged
  fi
else
  echo reviewer
fi
