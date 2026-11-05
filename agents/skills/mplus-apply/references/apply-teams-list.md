# apply teams list

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

分页查询团队管理人员列表，返回每个人的任职状态、飞书绑定情况、申请系统角色、团队归属和名下人脉数量。主要用于人员权限盘点和异常排查（如"有系统角色但不在任何团队"）。

对应命令：`mplus apply teams list`（内部调用 `GET /apply/open_api/v2/teams`，通过 API Gateway）。

## 命令示例

```bash
# 查询全部人员（默认第 1 页，每页 20 条）
mplus apply teams list --json

# 按姓名或手机号搜索
mplus apply teams list --q 郑诚 --json

# 查已离职人员
mplus apply teams list --employment_status resigned --json

# 查有系统角色的人
mplus apply teams list --identity_status system_role --json

# 预警：有系统角色但没有团队
mplus apply teams list --alert_type no_team --json

# 预警：未绑定飞书
mplus apply teams list --alert_type unbound --page_size 100 --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--q <value>` | 否 | string | 无 | 关键词，模糊匹配姓名或手机号 |
| `--employment_status <value>` | 否 | string | 无 | 任职状态：`employed`（在职）/ `resigned`（已离职）/ `unknown`（未知） |
| `--identity_status <value>` | 否 | string | 无 | 身份状态：`system_role`（有系统角色）/ `team`（有团队）/ `contact`（有人脉） |
| `--alert_type <value>` | 否 | string | `all` | 预警类型，见下表 |
| `--page <number>` | 否 | string | `"1"` | 页码，从 1 开始 |
| `--page_size <number>` | 否 | string | `"20"` | 每页数量，上限 100 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

### `--alert_type` 取值

| 取值 | 含义 |
|------|------|
| `all` | 全部人员（默认，不做预警过滤） |
| `unbound` | 未绑定飞书 |
| `no_team` | 有系统角色但不属于任何团队 |
| `no_system_role` | 有团队但没有系统角色 |
| `contacts_without_role_or_team` | 有人脉但既无系统角色也无团队 |

> **权限**：需要 `apply:teams:read` 权限。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "total": 1674,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "7029",
      "name": "郑诚",
      "phone": "13556136684",
      "employment_status": "employed",
      "feishu_bound": true,
      "identity_statuses": ["system_role", "team", "contact"],
      "system_roles": [
        { "id": "4", "name": "apply_admin", "label": "管理员" },
        { "id": "5", "name": "apply_partner", "label": "员工" }
      ],
      "teams": [
        {
          "id": "12",
          "name": "工程团队",
          "node_type": "department",
          "role": "member",
          "role_label": "成员"
        }
      ],
      "contact_count": 128,
      "created_at": "2021-03-15T02:11:07Z"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `total` | number | 符合条件的总人数 |
| `page` / `page_size` | number | 当前页码 / 每页数量 |
| `items[].id` | string | 用户 ID |
| `items[].name` | string | 姓名 |
| `items[].phone` | string | 手机号 |
| `items[].employment_status` | string | 任职状态（`employed` / `resigned` / `unknown`） |
| `items[].feishu_bound` | boolean | 是否已绑定飞书 |
| `items[].identity_statuses` | array | 当前具备的身份，可同时含多项（`system_role` / `team` / `contact`） |
| `items[].system_roles[].id` | string | 角色 ID |
| `items[].system_roles[].name` | string | 角色标识（如 `apply_admin`） |
| `items[].system_roles[].label` | string | 角色显示名（如"管理员"） |
| `items[].teams[].id` | string | 团队 ID |
| `items[].teams[].name` | string | 团队名称 |
| `items[].teams[].node_type` | string | 团队节点类型：`department`（部门）/ `grp`（组） |
| `items[].teams[].role` | string | 团队内角色：`manager` / `leader` / `member` |
| `items[].teams[].role_label` | string | 团队内角色显示名 |
| `items[].contact_count` | number | 名下去重人脉数量 |
| `items[].created_at` | string | 加入系统时间（ISO 8601 UTC） |

## AI 使用建议

1. **`identity_statuses` 是数组**：一个人可以同时有系统角色、团队和人脉，判断时用包含关系，不要当单值处理。
2. **`system_roles` / `teams` 可能是空数组**：离职或仅有人脉的人常见两者都为空，取值前先判空。
3. **权限盘点场景**：查"谁还有管理员权限"用 `--identity_status system_role` 拉全量后按 `system_roles[].name` 过滤；查交接遗漏用 `--employment_status resigned` 配合 `system_roles` 非空。
4. **`name` 是角色标识、`label` 是中文名**：写筛选逻辑用 `name`（稳定），给人看用 `label`。

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-teams-report](apply-teams-report.md) — 系统角色变化报表
