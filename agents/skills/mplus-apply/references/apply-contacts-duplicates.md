# apply contacts duplicates

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

批量检查待导入或待创建的人脉是否已存在。接口会按手机号、邮箱、微信号匹配已有 contacts，并在命中的人脉上返回 `duplicate_reason`。

对应命令：`mplus apply contacts duplicates --contacts <json>`（内部调用 `POST /apply/open_api/v2/contacts/duplicates`，通过 API Gateway）。

## 命令示例

```bash
# 按手机号 / 邮箱 / 微信号批量查重
mplus apply contacts duplicates --contacts '[
  {"phone":"13800138000"},
  {"email":"founder@example.com"},
  {"wechat":"wechat_id"}
]' --json

# 只返回指定字段；duplicate_reason 会额外返回
mplus apply contacts duplicates \
  --contacts '[{"phone":"13800138000","email":"founder@example.com"}]' \
  --output_schema '{"contact":["id","name","phone","email"]}' \
  --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--contacts <value>` | 是 | JSON string | 待查重人脉数组，最多 100 条；每条可包含 `phone`、`email`、`wechat` |
| `--output_schema <value>` | 否 | JSON string | 字段过滤配置，格式 `{"contact":["id","name","phone"]}`；`duplicate_reason` 会额外返回 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

## 匹配规则

| 入参字段 | 匹配范围 |
|------|------|
| `phone` | `phone` / `phone_2` / `phone_3` |
| `email` | `email` / `email_2` / `email_3` / `email_4` |
| `wechat` | `wechat` |

## 权限

需要 `apply:contacts:read:all` 或 `apply:contacts:read:self` 权限。敏感字段可见性与人脉详情接口一致。

## 返回结构

```json
[
  {
    "phone": "13800138000",
    "email": null,
    "wechat": null,
    "contacts": [
      {
        "id": "123",
        "duplicate_reason": "手机号匹配(phone: 13800138000)",
        "name": "张三",
        "phone": "13800138000"
      }
    ]
  }
]
```

## 常见错误

- **401 Unauthorized** — token 无效或已过期
- **422 Unprocessable Entity** — 单次请求超过 100 条，或请求体格式不符合要求

## AI 使用建议

1. 批量导入、新建人脉前，先用此命令查重，避免直接 `create` 后收到冲突错误
2. 单次最多 100 条，超过时按 100 条分批调用
3. 需要减少响应体时传 `--output_schema`，但不要依赖它过滤掉 `duplicate_reason`

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-contacts-create](apply-contacts-create.md) — 新建人脉
- [apply-contacts-search](apply-contacts-search.md) — 搜索人脉
