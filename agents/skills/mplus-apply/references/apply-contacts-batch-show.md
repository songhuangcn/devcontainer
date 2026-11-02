# apply contacts batch-show

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

根据人脉 ID、关联的用户 ID、申请 ID 或创始人 ID 批量获取人脉详情。

对应命令：`mplus apply contacts batch-show`（内部调用 `GET /apply/open_api/v2/contacts/batch_show`，通过 API Gateway）。

## 命令示例

```bash
# 按人脉 ID 批量查询
mplus apply contacts batch-show --contact_ids 123,456,789 --json

# 按关联的用户 ID 批量查询
mplus apply contacts batch-show --user_ids 1,2,3 --json

# 按申请 ID 批量查询
mplus apply contacts batch-show --application_ids 100,200 --json

# 按创始人 ID 批量查询
mplus apply contacts batch-show --founder_ids 50,51 --json

# 多种 ID 混合查询（取并集）
mplus apply contacts batch-show --contact_ids 123 --user_ids 1,2 --application_ids 100 --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--contact_ids <value>` | 否* | string | 人脉 ID 列表，英文逗号分隔，每次最多 100 个。例如：`1,2,3` |
| `--user_ids <value>` | 否* | string | 关联的注册用户 ID 列表，英文逗号分隔，每次最多 100 个；经 contact_relations 反查其关联的人脉 |
| `--application_ids <value>` | 否* | string | 关联的申请 ID 列表，英文逗号分隔，每次最多 100 个；经 contact_relations 反查其关联的人脉 |
| `--founder_ids <value>` | 否* | string | 关联的创始人 ID 列表，英文逗号分隔，每次最多 100 个；经 contact_relations 反查其关联的人脉 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **注意：** 四类入参（`--contact_ids` / `--user_ids` / `--application_ids` / `--founder_ids`）**至少传一个**，同时传时取并集。

> **权限**：`apply:contacts:read:all`（全部人脉）或 `apply:contacts:read:self`（仅自己名下）。
> **敏感字段**：管理员/合伙人可见完整手机号、邮箱、微信；其他用户手机号显示为 `***1234`，邮箱和微信显示为 `******`。

## 返回结构

```json
{
  "items": [
    {
      "id": "123",
      "name": "张三",
      "phone": "13812345678",
      "email": "zhangsan@example.com",
      "category": "investor",
      "tags": ["VIP", "AI"],
      "application_ids": [100, 200],
      "founder_ids": [50],
      "activities": [...],
      "created_at": "2025-01-15T08:30:00.000Z",
      "updated_at": "2025-06-20T12:00:00.000Z"
    }
  ],
  "missing_contact_ids": [999],
  "missing_user_ids": [],
  "missing_application_ids": [888],
  "missing_founder_ids": []
}
```

## 主要返回字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `items` | array | 人脉详情列表，每条结构与 `GET /contacts/{id}` 一致 |
| `missing_contact_ids` | array | 请求了但未命中的人脉 ID 列表 |
| `missing_user_ids` | array | 请求了但未命中的用户 ID 列表 |
| `missing_application_ids` | array | 请求了但未命中的申请 ID 列表 |
| `missing_founder_ids` | array | 请求了但未命中的创始人 ID 列表 |

每条人脉对象的字段说明参考 [apply-contacts-get](apply-contacts-get.md)。

## 常见错误

- **400 Bad Request** — 未传任何 ID 参数，或单个参数超过 100 个
- **403 Forbidden** — 用户仅持 `apply:contacts:read:self` 权限，但查询的人脉不归属自己
- **404 Not Found** — 所有请求的 ID 都不存在（items 为空）

## AI 使用建议

1. **批量查询优先**：需要查询多条人脉时，优先使用此命令而非循环调用 `get <id>`
2. **反查场景**：已知用户 ID / 申请 ID / 创始人 ID 时，无需先查 contact_relations，直接用此命令反查
3. **分页控制**：单次最多 100 个 ID，超过时需分批调用
4. **未命中处理**：检查 `missing_*` 字段判断哪些 ID 未命中，决定是否需要补充操作

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-contacts-get](apply-contacts-get.md) — 单条人脉详情
- [apply-contacts-search](apply-contacts-search.md) — 搜索人脉
