---
description: 派发：选 Implementer 和 Reviewer，写理由，指派并启动
---
先按任务所属项目定位仓库；本 runbook 的 `bash ./autoteam ...`、`.autoteam/scripts/...` 和 registry 均取该仓库。被叫醒的原因是子任务被放行、一批子任务完成，或者巡检时（`multica issue list --project <项目 ID> --status todo --output json` 列出待派发任务）。只派发 `todo` 且指派给你自己的任务，并且它前面的批次已经全部 `done`；否则什么都不做（不用评论）。人把任务从 `backlog` 改到 `todo`、或你按 `release` 自主放行，都是明确放行，不要求人再批准，不要退回 `backlog`，也不要评论请人批准。`todo` 且已指派给 Implementer 的任务是已派发的，不在此列。 跨需求依赖必须写入 metadata `autoteam.depends_on`，不能只写在描述里：`multica issue metadata set <任务 ID> --key autoteam.depends_on --type string --value "HDGCS-125,HDGCS-126"`。编号逗号分隔，全部 `done` 才可派发；编号不存在、读取失败或解析失败时不派发，先修正前提。 派发前运行 `<身份> bash ./autoteam next --output json`，仅派发其中 `dispatchable` 的任务；放行不代表前提已经满足。

**按优先级派发只用于自主放行的任务**：`urgent` / `high` 当次派发，`medium` / `low` 留在指派给你的 `todo` 等下次巡检；额度紧张时只派 `high` 及以上，`low` 等额度充足再派。人批准的任务、前一批全部 `done` 后解锁的任务，被叫醒时直接派发，包括 `medium` / `low`；多个可派发任务按优先级安排先后。始终先核对批次和额度。这与 `release` 一致，不把人的明确批准再延后一轮。

1. 选一个 Implementer 和一个 Reviewer，两者必须是不同的 agent，优先不同厂商（registry.yaml 里 account 不同）：
   - 计费顺序：订阅额度 > 包月点数 > 按量计费（不超过当日预算）；
   - 额度快用完的账号不派大任务，因为中途耗尽会留下半成品。参考 `multica runtime usage <runtime-id> --days 7 --output json`，以及最近因额度失败的运行（`multica issue runs <任务> --output json` 的错误信息，通常带恢复时间）；
   - 条件相同时，优先最近成绩单里一次通过率高的；
   - 派发前只检查选中的 Implementer / Reviewer：用 `multica runtime list --output json` 确认两者的 runtime 在线，用 `multica agent tasks <agent ID> --output json` 看各自最近一次运行没有因额度或登录失败；在能访问其 runtime 文件系统时，用 `.autoteam/scripts/gh-app-token.sh --find-key <角色>` 检查所需私钥。未通过就换一个可用的 agent；都因缺私钥不可用时按 `escalate` 处理，说明缺哪个角色的私钥、该放哪里。完整的 `autoteam doctor` 只在接入、升级或部署了规则文件改动时运行，不在每次派发时运行；
   - 因 runtime 离线或额度暂时不足而没有可用的 Implementer 或 Reviewer，就保持指派给你的 `todo`，下次巡检再试。
2. 在任务评论里写明 Implementer、Reviewer 和选择理由。**Reviewer 只写名字，不要用提及链接**，否则会提前叫醒它。
3. `multica issue status <任务> todo --no-start`，再 `multica issue assign <任务> --to <Implementer 名>`，指派会启动 Implementer。
4. **解除 `blocked` 恢复给同一个 Implementer（人回复后、卡点已解决）**：任务的指派人没变（本来就是该 Implementer）时，`status todo --no-start` 加重复 `assign` 是空操作，**不会叫醒它**——平台只在指派变更、评论提及、条件唤醒时启动 agent，状态变更和指派人不变的重复 assign 都不会（HDGCS-231 事故：任务停在 `todo` 无人处理）。必须二选一：
   - 发一条评论（写当前目录文件，用 `--content-file`），说明卡点已解除和需要它做什么，并用 `[@名字](mention://agent/<UUID>)` 提及该 Implementer（UUID 用 `multica agent list --output json` 查）；
   - 或先改指派给另一个对象，再 `multica issue assign <任务> --to <Implementer 名>` 改回（指派变更会启动它）。
   解除后用 `multica issue runs <任务> --output json` 核对已出现新运行；没有就补一条提及评论叫醒它，不要等下次巡检。
