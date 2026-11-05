# apply channel-users batch-show

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

根据微信用户 ID（`channel_user_ids`）或微信 unionid（`unionids`）批量获取微信渠道用户详情。

对应命令：`mplus apply channel-users batch-show`（内部调用 `GET /apply/open_api/v2/channel_users/batch_show`，通过 API Gateway）。

## 命令示例

```bash
# 按微信用户 ID 批量查询
mplus apply channel-users batch-show --channel-user-ids 123,456,789 --json

# 按 unionid 批量查询（一个 unionid 可能对应多条记录）
mplus apply channel-users batch-show --unionids o6_bmjrPTlm6_2sgVt7hMZOPfL2M,oUBYTs1234567890 --json

# 混合查询（取并集）
mplus apply channel-users batch-show --channel-user-ids 123 --unionids o6_bmjrPTlm6_2sgVt7hMZOPfL2M --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--channel-user-ids <value>` | 否* | string | 微信用户 ID 列表（`Soc::ChannelUser.id`），英文逗号分隔，每次最多 100 个。例如：`1,2,3` |
| `--unionids <value>` | 否* | string | 微信 unionid 列表，英文逗号分隔，每次最多 100 个；一个 unionid 可能对应多个 channel_type 的记录，会全部返回 |
| `--output_schema <value>` | 否 | JSON string | 稀疏字段集（sparse fieldset）。格式 `{"soc_channel_user": ["id", ...]}`（key 固定为 `soc_channel_user`，value 为字段名数组）。不传则返回全量字段 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **注意：** 两类入参（`--channel-user-ids` / `--unionids`）**至少传一个**，同时传时取并集。

> **权限**：`apply:channel_users:read`

## 返回结构

```json
{
  "items": [
    {
      "id": "123",
      "name": "张三",
      "unionid": "o6_bmjrPTlm6_2sgVt7hMZOPfL2M",
      "channel_type": "qywechat",
      "phone": "13812345678",
      "email": "zhangsan@example.com",
      "qy_tag_names": ["一级渠道", "VIP"],
      "follow_user_names": ["李四"],
      "contact_tags": ["潜在创始人"],
      "contact_user_id": "456",
      "contact_user_name": "王五",
      "application_progress": "submitted",
      "created_at": "2025-01-15T08:30:00.000Z",
      "updated_at": "2025-06-20T12:00:00.000Z"
    }
  ],
  "missing_channel_user_ids": [999],
  "missing_unionids": ["invalid_unionid"]
}
```

## 主要返回字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `items` | array | 微信渠道用户列表，结构与 `GET /channel_users/search` 的 items 完全一致 |
| `missing_channel_user_ids` | array | 请求了但未命中的微信用户 ID 列表 |
| `missing_unionids` | array | 请求了但未命中的 unionid 列表 |

### items 中每条记录的关键字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 微信用户 ID（`Soc::ChannelUser.id`） |
| `unionid` | string | 微信 UnionID，同一用户在不同应用间的唯一标识 |
| `channel_type` | string | 来源类型：`apply`（申请端）/ `qywechat`（企业微信）/ `wechat_service`（服务号） |
| `name` | string | 用户昵称 |
| `phone` | string | 手机号 |
| `email` | string | 邮箱 |
| `qy_tag_names` | array | 企业微信标签列表 |
| `follow_user_names` | array | 负责员工（企业微信的"跟进人"） |
| `contact_tags` | array | 人脉标签 |
| `contact_user_id` / `contact_user_name` | string | 触达人 ID / 姓名 |
| `application_progress` | string | 申请进度：`not_register`（未注册）/ `registered`（已注册）/ `not_submitted`（未提交）/ `submitted`（已提交） |
| `external_userid` | string | 企业微信外部联系人 ID |
| `openid` | string | 特定应用下的 OpenID |
| `created_at` | string | 创建时间（ISO 8601 UTC） |
| `updated_at` | string | 最后更新时间（ISO 8601 UTC） |

## 常见错误

- **400 Bad Request** — 未传任何 ID 参数，或单个参数超过 100 个
- **403 Forbidden** — 用户无 `apply:channel_users:read` 权限
- **404 Not Found** — 所有请求的 ID 都不存在（items 为空）

## AI 使用建议

1. **批量查询优先**：需要查询多个微信用户时，优先使用此命令而非循环调用 search
2. **unionid 多对多**：一个 unionid 可能对应多条记录（不同 channel_type），返回时会全部包含
3. **分页控制**：单次最多 100 个 ID，超过时需分批调用
4. **未命中处理**：检查 `missing_channel_user_ids` / `missing_unionids` 字段判断哪些 ID 未命中

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-channel-users-search](apply-channel-users-search.md) — 搜索微信渠道用户
