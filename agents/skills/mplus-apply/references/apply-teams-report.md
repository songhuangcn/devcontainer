# apply teams report

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询申请系统的角色变化报表：某个时间周期内谁被赋予/移除了角色、到期时间怎么调的，以及周期结束时每个角色下的用户快照。用于权限审计和角色治理。

对应命令：`mplus apply teams report`（内部调用 `GET /apply/open_api/v2/teams/report`，通过 API Gateway）。

## 命令示例

```bash
# 默认周期（最近 24 小时）
mplus apply teams report --json

# 最近一周 / 一个月
mplus apply teams report --period last_week --json
mplus apply teams report --period last_month --json

# 自定义周期
mplus apply teams report --period custom \
  --start_at 2026-06-01T00:00:00Z --end_at 2026-07-01T00:00:00Z --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--period <value>` | 否 | string | `last_24_hours` | 统计周期：`last_24_hours` / `last_week` / `last_month` / `last_3_months` / `last_6_months` / `last_year` / `custom` |
| `--start_at <datetime>` | 否 | string | 无 | 自定义周期开始时间，`--period custom` 时使用 |
| `--end_at <datetime>` | 否 | string | 无 | 自定义周期结束时间 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> **权限**：需要 `apply:teams:read` 权限。

> **时间格式**：`--start_at` / `--end_at` 推荐用完整 ISO 8601 带时区（`2026-06-01T00:00:00Z`）。只写日期（`2026-06-01`）会被当成东八区零点，换算成 UTC 后是 `2026-05-31T16:00:00Z`，跨天统计容易差一天。
> **参数不合法**：周期参数非法时命令输出 `错误：时间范围参数不合法` 并以退出码 1 结束。响应里的 `period` 字段会回显服务端实际采用的周期，建议核对。

## 返回字段

响应为顶层对象，含 `period`、`summary`、`role_changes`、`roles` 四块。

```json
{
  "period": {
    "type": "last_24_hours",
    "start_at": "2026-07-27T02:37:18Z",
    "end_at": "2026-07-28T02:37:18Z",
    "generated_at": "2026-07-28T02:37:18Z"
  },
  "summary": {
    "role_count": 18,
    "role_change_count": 4,
    "affected_user_count": 4,
    "assigned_count": 4,
    "expiration_updated_count": 0,
    "removed_count": 0,
    "expired_count": 0,
    "active_assignment_count": 1071
  },
  "role_changes": [
    {
      "event_type": "assigned",
      "occurred_at": "2026-07-28T01:37:25Z",
      "user": { "id": "329340", "name": "林啸" },
      "role": { "id": "41", "name": "alumni-interviewer", "label": "校友面试官" },
      "assignment_type": "permanent",
      "expires_at": null,
      "removed_at": null,
      "operator": { "id": "52443", "name": "刘绍栋" },
      "role_count_after_change": 2,
      "roles_after_change": [ { "id": "41", "name": "alumni-interviewer", "label": "校友面试官", "assignment_type": "permanent", "expires_at": null, "history_tracked": true } ]
    }
  ],
  "roles": [
    {
      "id": "4",
      "name": "apply_admin",
      "label": "管理员",
      "active": true,
      "summary": { "total_user_count": 12, "active_count": 11, "permanent_count": 9, "temporary_count": 2, "expired_count": 1, "removed_count": 0, "added_in_period_count": 1, "invalidated_in_period_count": 0 },
      "users": [ { "id": "7029", "name": "郑诚", "status": "active", "assignment_type": "permanent", "assigned_at": "2021-03-15T02:11:07Z", "expires_at": null, "removed_at": null, "history_tracked": true, "added_in_period": false, "invalidated_in_period": false, "changes_in_period": [], "last_invalidated_at": null, "last_invalidation_type": null } ]
    }
  ]
}
```

### `period`

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | string | 实际使用的周期类型 |
| `start_at` / `end_at` | string | 统计起止时间（UTC） |
| `generated_at` | string | 报表生成时间（UTC） |

### `summary`

| 字段 | 类型 | 说明 |
|------|------|------|
| `role_count` | number | 当前申请系统角色数量 |
| `role_change_count` | number | 周期内角色变化事件总数 |
| `affected_user_count` | number | 周期内受影响的去重用户数 |
| `assigned_count` | number | 角色赋予次数 |
| `expiration_updated_count` | number | 到期时间调整次数 |
| `removed_count` | number | 主动移除次数 |
| `expired_count` | number | 自然到期次数 |
| `active_assignment_count` | number | 周期结束时有效的角色分配总数 |

### `role_changes[]`（按发生时间倒序）

| 字段 | 类型 | 说明 |
|------|------|------|
| `event_type` | string | `assigned`（赋予）/ `expiration_updated`（调整到期）/ `removed`（主动移除）/ `expired`（自然到期） |
| `occurred_at` | string | 变化发生时间（UTC） |
| `user.id` / `user.name` | string | 被操作用户 ID / 姓名 |
| `role.id` / `role.name` / `role.label` | string | 角色 ID / 标识 / 显示名 |
| `assignment_type` | string | `permanent`（长期）/ `temporary`（临时） |
| `expires_at` | string\|null | 角色到期时间；长期角色为 `null` |
| `removed_at` | string\|null | 主动移除或到期清理时间 |
| `operator` | object\|null | 操作人；**自然到期时为 `null`** |
| `role_count_after_change` | number | 操作完成后该用户的有效角色总数 |
| `roles_after_change[]` | array | 操作完成后该用户的全部有效角色 |

### `roles[]`（周期结束时每个角色的用户快照，并保留本期失效用户）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` / `name` / `label` | string | 角色 ID / 标识 / 显示名 |
| `active` | boolean | 角色配置是否启用 |
| `summary.total_user_count` | number | 返回的去重用户总数 |
| `summary.active_count` | number | 周期结束时有效用户数 |
| `summary.permanent_count` / `temporary_count` | number | 有效长期 / 临时角色用户数 |
| `summary.expired_count` / `removed_count` | number | 已自然到期 / 已主动移除用户数 |
| `summary.added_in_period_count` | number | 本期新增角色用户数 |
| `summary.invalidated_in_period_count` | number | 本期失效角色用户数 |
| `users[].id` / `name` | string | 用户 ID / 姓名 |
| `users[].status` | string | 周期结束时的角色状态：`active` / `expired` / `removed` |
| `users[].assignment_type` | string | `permanent` / `temporary` |
| `users[].assigned_at` | string\|null | 可追溯的首次赋予时间 |
| `users[].expires_at` / `removed_at` | string\|null | 到期时间 / 最近一次移除或清理时间 |
| `users[].history_tracked` | boolean | 是否存在可追溯的角色 history |
| `users[].added_in_period` / `invalidated_in_period` | boolean | 角色是否在本期新增 / 失效 |
| `users[].changes_in_period` | array | 本期发生的变化类型列表 |
| `users[].last_invalidated_at` / `last_invalidation_type` | string\|null | 截至周期结束的最近失效时间 / 类型（`removed` / `expired`） |

## AI 使用建议

1. **`roles[].users` 含已失效用户**：快照里保留了本期 `expired` / `removed` 的人，统计"当前还有多少人有该角色"要用 `summary.active_count` 或按 `status === "active"` 过滤，别直接数 `users` 长度。
2. **`operator` 可能为 null**：自然到期（`event_type: "expired"`）没有操作人，做"谁改了权限"归因时要跳过这类事件。
3. **默认周期只有 24 小时**：做审计通常要显式传 `--period last_month` 或 `custom`，否则容易得出"没什么变化"的错误结论。
4. **响应体量大**：`roles[].users` 会展开每个角色的全部用户，18 个角色就上千条。只要汇总数字时读 `summary` 即可，不必解析全量。
5. **配合 teams list**：报表给的是"变化"，要看某人当前完整的角色和团队归属，用 `mplus apply teams list --q <姓名>`。

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-teams-list](apply-teams-list.md) — 团队管理人员列表
