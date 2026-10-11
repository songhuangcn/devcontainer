---
description: 升级：什么情况下把任务设为 blocked 并指派给人，怎么写
---
出现以下情况，把任务设为 `blocked` 并**指派给人**，在父任务评论里用成员链接提及人（`multica workspace member list --output json` 查 `user_id`），说明卡点、可选方案和你的建议：

- 同一个 PR 被打回满 `AUTOTEAM_MAX_REVIEW_REJECTIONS` 次（默认 2）；
- 同一个任务验收不通过满 `AUTOTEAM_MAX_ACCEPTANCE_FAILURES` 次（默认 2）；
- 因额度或权限失败、换过一次 Implementer 后仍然失败（换人时评论 `【换人】` 加原因）；
- 换过一次 Reviewer 后再次在评审开始前因 runtime 路由、登录、额度或权限失败，且该 Reviewer 在 PR 上没有评审记录（换人时评论 `【换人-Reviewer】` 加原因）；
- 派发时没有 Implementer 或 Reviewer 的私钥检查能通过（写明缺哪个角色的私钥、该放 `AUTOTEAM_KEYS_DIR`）；
- 巡检提及 Implementer 补开自动合并或 rebase 后，同一个 PR 仍然没开自动合并或仍然冲突（见推进巡检的 `pr_remediation`）；
- 线上故障（已回滚）。

```bash
multica issue status <任务> blocked
multica issue assign <任务> --to-id <人的 user_id> --no-start
```

**指派这一步不能省**：球在谁手里，assignee 就该是谁。人打开「指派给我的」要能看到全部等他决断的事，不用一个个翻看板。指派给成员不会启动任何 agent。人回复 @你之后你再按 `dispatch` 把它指回 agent。若指回的是**原来的同一个 Implementer**，只改状态或重复 assign 不会叫醒它，必须按 `dispatch` 第 4 步提及它并核对 `multica issue runs`。

次数用 `<身份> .autoteam/scripts/loop-guard.sh <任务>` 从 GitHub 的评审记录和任务评论里算，不要相信 agent 自己的说法。`<身份>` = `.autoteam/scripts/gh-app-token.sh --run planner`。
