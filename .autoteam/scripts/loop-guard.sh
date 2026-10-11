#!/usr/bin/env bash
# 统计一个任务来回打转的次数，判断是否该升级给人。Reviewer 打回前、Planner 巡检时使用。
# 用法：.autoteam/scripts/loop-guard.sh <任务编号>
# 输出 JSON：每个 PR 的打回次数、验收不通过次数、两类换人次数、上限，以及 escalate（是否该升级）和原因。
# 次数只从 GitHub 评审记录和任务评论里算，不依赖 agent 自己上报。依赖 gh、jq、multica。
set -eo pipefail

key=${1:-}
if [ -z "$key" ] || [ "$key" = -h ] || [ "$key" = --help ]; then
  sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
conf=$root/.autoteam/autoteam.conf
conf_get() { sed -n "s/^$1=//p" "$conf" 2>/dev/null | head -n 1 | tr -d '[:space:]'; }
max_rej=$(conf_get AUTOTEAM_MAX_REVIEW_REJECTIONS)
max_acc=$(conf_get AUTOTEAM_MAX_ACCEPTANCE_FAILURES)
max_sw=$(conf_get AUTOTEAM_MAX_IMPLEMENTER_SWITCHES)
repo=$(conf_get AUTOTEAM_REPO)
repo_args=()
[ -n "$repo" ] && repo_args=(--repo "$repo")
mc=${MULTICA_BIN:-multica}
mc_args=()
[ -n "${AUTOTEAM_MULTICA_PROFILE:-}" ] && mc_args=(--profile "$AUTOTEAM_MULTICA_PROFILE")

# 标题以任务编号开头的 PR（包括已关闭、已合并的）
prs=$(gh pr list ${repo_args[@]+"${repo_args[@]}"} --state all --search "$key in:title" --limit 50 \
        --json number,title,state,url,reviews) || { echo "loop-guard.sh：查询 PR 失败" >&2; exit 2; }

# 任务评论里的标记（Planner 写的【验收不通过】【换人】【换人-Reviewer】）
comments=$("$mc" issue comment list "$key" --full --output json "${mc_args[@]}") || { echo "loop-guard.sh：查询任务评论失败" >&2; exit 2; }
jq -e 'type == "array"' <<<"$prs" >/dev/null || { echo "loop-guard.sh：PR 格式错误" >&2; exit 2; }
jq -e 'type == "array" or (type == "object" and (.comments | type == "array"))' <<<"$comments" >/dev/null || { echo "loop-guard.sh：任务评论格式错误" >&2; exit 2; }

jq -n --arg key "$key" --argjson prs "$prs" --argjson comments "$comments" \
  --argjson max_rej "${max_rej:-2}" --argjson max_acc "${max_acc:-2}" \
  --argjson max_sw "${max_sw:-1}" '
  def rejected: .state == "CHANGES_REQUESTED" or ((.body // "") | startswith("【阻塞】"));
  def marker($m): [(if ($comments | type) == "array" then $comments else ($comments.comments // []) end)[]
                   | select((.content // "") | ltrimstr(" ") | startswith($m))] | length;
  ([$prs[] | select(.title | test("^" + $key + "([^0-9]|$)"))
    | {number, state, url, rejections: ([.reviews[]? | select(rejected)] | length)}]) as $mine
  | ([$mine[].rejections] | max // 0) as $rej
  | marker("【验收不通过】") as $acc
  | marker("【换人】") as $sw
  | marker("【换人-Reviewer】") as $reviewer_sw
  | {
      issue: $key,
      pull_requests: $mine,
      review_rejections: $rej,
      acceptance_failures: $acc,
      implementer_switches: $sw,
      reviewer_switches: $reviewer_sw,
      limits: {review_rejections: $max_rej, acceptance_failures: $max_acc, implementer_switches: $max_sw, reviewer_switches: 1},
      reasons: [
        (if $rej >= $max_rej then "同一个 PR 已被打回 \($rej) 次" else empty end),
        (if $acc >= $max_acc then "验收已不通过 \($acc) 次" else empty end)
      ],
      notes: [
        (if $sw >= $max_sw then "已经换过 \($sw) 次 Implementer，再因额度或权限失败就升级" else empty end),
        (if $reviewer_sw >= 1 then "已经换过 \($reviewer_sw) 次 Reviewer，再次评审前失败就升级" else empty end)
      ]
    }
  | .escalate = (.reasons | length > 0)'
