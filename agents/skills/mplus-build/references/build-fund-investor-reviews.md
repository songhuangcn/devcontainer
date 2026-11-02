# build fund_investor_reviews

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

创业者对投资人的评价（大力点评系统的"评价"维度）。用户只能更新/删除自己创建的评价。

对应命令：

| 命令 | 说明 |
|------|------|
| `mplus build fund_investor_reviews list` | 查询评价列表（传 `fund_investor_id` 看某投资人的全部公开评价；不传看自己创建的） |
| `mplus build fund_investor_reviews my` | 查询当前用户创建的全部评价 |
| `mplus build fund_investor_reviews schema` | 获取评价问题定义及必填规则 |
| `mplus build fund_investor_reviews show <id>` | 查询单条评价详情 |
| `mplus build fund_investor_reviews create` | 创建评价 |
| `mplus build fund_investor_reviews update <id>` | 更新自己创建的评价 |
| `mplus build fund_investor_reviews delete <id>` | 删除自己创建的评价 |

## 命令示例

```bash
# 先看问题定义，了解必填规则
mplus build fund_investor_reviews schema --json

# 查看某投资人的全部公开评价
mplus build fund_investor_reviews list --fund_investor_id 1393 --json

# 查看自己创建的评价
mplus build fund_investor_reviews my --json

# 查看单条详情
mplus build fund_investor_reviews show 99 --json

# 创建评价（got_invested=false 这条路径需要这些必填项；answers_attributes 整体传一个 JSON 字符串）
mplus build fund_investor_reviews create --fund_investor_id 1393 --answers_attributes '[
  {"question_key":"got_invested","value_boolean":false},
  {"question_key":"professional","value_string":"s"},
  {"question_key":"helpful","value_string":"s"},
  {"question_key":"friendly","value_string":"s"},
  {"question_key":"style_and_communication","value_string":"沟通很顺畅"}
]' --json

# 更新评价（只传要改的 answers）
mplus build fund_investor_reviews update 99 --answers_attributes '[{"question_key":"comment","value_string":"补充说明"}]' --json

# 删除自己创建的评价
mplus build fund_investor_reviews delete 99 --json
```

## 参数

### list

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--fund_investor_id <value>` | 否 | string | 按被评价投资人 ID 过滤；传入返回该投资人全部已提交评价（公开口碑），不传返回当前用户自己创建的评价 |
| `--page <value>` / `--page_size <value>` | 否 | string | 分页 |

### my

| 参数 | 必填 | 说明 |
|------|------|------|
| `--page <value>` / `--page_size <value>` | 否 | 分页 |

### show / update / delete

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | integer | 评价 ID |

### create

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--fund_investor_id <value>` | 是 | string | 被评价的投资人 ID，对应数据模型 `invest_contact_id` |
| `--answers_attributes <value>` | 否* | JSON 字符串 | 答案数组，每项 `{question_key, value_boolean/value_string/value_integer}`；必填项由 `schema` 的 `rules` 按 `got_invested` 取值决定 |

### update

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--answers_attributes <value>` | 否 | JSON 字符串 | 同 create，传哪些 `question_key` 就更新哪些，会校验合并后是否满足必填规则 |

## 返回字段

`schema` 返回的问题定义（决定必填规则）：

```json
{
  "questions": [
    { "key": "got_invested", "text": "是否已经获得这个投资人投资", "type": "boolean", "required": true, "category": "special" },
    { "key": "recommand_or_not", "text": "是否应该拿这位投资人的钱", "type": "select", "required": true, "category": "yes", "options": [...] }
  ],
  "rules": {
    "when_got_invested_true": { "required": ["got_invested", "professional", "helpful", "friendly", "recommand_or_not"], "optional": ["comment"] },
    "when_got_invested_false": { "required": ["got_invested", "professional", "helpful", "friendly", "style_and_communication"], "optional": ["comment"] }
  }
}
```

`list` / `show` / `my` 返回的评价对象：

```json
{
  "id": "99",
  "fund_investor_id": "1393",
  "status": "submitted",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "answers": [
    { "id": "1", "question_key": "got_invested", "question_text": "...", "value_boolean": true }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `category` (schema 中) | `special`（总检查）/ `yes`（仅 got_invested=true 时必填）/ `no`（仅 false 时必填）/ `all`（总是必填） |
| `user` / `user_id` | 仅 admin（`can?(:manage, :internal)`）调用 `list`/`show` 时附带评价人信息，普通用户看不到他人评价人身份 |

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `403 forbidden`（update/delete） | 试图操作非本人创建的评价 | 只能操作自己创建的评价，先用 `my` 确认归属 |
| `422` 必填问题未回答 | `answers_attributes` 缺少 `schema` 要求的必填项 | 先调 `schema` 确认 `got_invested` 取值对应的必填字段 |
| `404 fund investor not found`（create） | `fund_investor_id` 不存在 | 先用 `mplus build fund_investors list/show` 确认 ID |

**`got_invested=false` 是合法值，不是"未填写"**——后端用 `!nil?` 而非 `present?` 判断是否已提供该字段，`--answers_attributes` 的 JSON 里传递时务必显式传 `false` 而不是省略这一项。

## AI 使用建议

1. **先 `schema` 再 `create`/`update`**：必填规则依赖 `got_invested` 的值分叉，不看 schema 容易漏填
2. `delete`/`update` 前先 `my` 确认这条评价确实是自己创建的，否则会 403

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
- [build-fund-investors](build-fund-investors.md) — 投资人个体
