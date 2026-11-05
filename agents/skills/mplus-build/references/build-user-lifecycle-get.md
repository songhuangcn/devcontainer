# build user_lifecycle get

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取指定用户在奇绩 Batch 系统中的完整生命周期数据，按"人"为维度聚合申请、入营、财务、融资等全链路数据。

对应命令：`mplus build user_lifecycle get <id>`（内部调用 `GET /build/open_api/v2/user_lifecycle/{user_id}`，通过 API Gateway）。

## 命令示例

```bash
# 获取用户 123 的完整生命周期数据
mplus build user_lifecycle get 123 --json

# 使用指定 profile
mplus build user_lifecycle get 123 --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | integer | 用户 ID（整数）|
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **注意**：`<id>` 是奇绩用户整数 ID，不是申请 ID、contact ID 或 startup project ID。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "contact": { "...": "人脉阶段数据" },
  "application": { "...": "申请阶段数据" },
  "due_diligence": { "...": "尽调阶段数据" },
  "evaluation": { "...": "评估阶段数据" },
  "camp": { "...": "入营阶段数据" },
  "wechat": { "...": "微信相关数据" },
  "recommendation": { "...": "推荐相关数据" },
  "finance": { "...": "财务相关数据" },
  "round": { "...": "融资轮次数据" }
}
```

| 字段 | 说明 |
|------|------|
| `contact` | 人脉阶段：线索来源、联系方式、跟进状态等 |
| `application` | 申请阶段：申请表状态、提交时间、审阅结论等 |
| `due_diligence` | 尽调阶段：尽调记录和结论 |
| `evaluation` | 评估阶段：项目评估结果 |
| `camp` | 入营阶段：入营时间、批次、项目进展等 |
| `wechat` | 微信相关：企微/个微添加状态等 |
| `recommendation` | 推荐相关：推荐人和推荐情况 |
| `finance` | 财务相关：财务数据、融资条件等 |
| `round` | 融资轮次：历史融资轮次数据 |

> 各字段的具体子字段会随后端变动，使用 `--json` 输出后自行解析。

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `401 unauthorized` | token 无效或过期 | 执行 `mplus login` |
| `403 forbidden` | 缺少 `accelerator:user_lifecycle:read` 权限，或使用了 client_credentials token | 确认账号权限；注意 client_credentials token 不支持此接口，必须用 user token |
| `404 not_found` | 用户不存在 | 确认 user_id 正确，该接口只接受整数用户 ID |

## AI 使用建议

1. **确认 user_id 来源**：user_id 来自奇绩系统，可通过 `mplus apply contacts search` 或 `mplus apply applications list` 中的 `user_id` 字段获取
2. **与 Apply 的区别**：`mplus apply applications batch-show` 以申请为单位，返回申请 Markdown；本命令以用户为单位，返回全链路状态聚合
3. **字段为 null**：某阶段数据为 null 表示该用户尚未进入该阶段

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
- [mplus-apply](../../mplus-apply/SKILL.md) — 申请系统数据
