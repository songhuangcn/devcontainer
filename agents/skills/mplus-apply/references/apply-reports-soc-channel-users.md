# apply reports soc-channel-users

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取企业微信用户统计数据，支持明细（detail）和计数（count）两种模式，支持按时间范围、企微标签、跟进人等多维度过滤。

对应命令：`mplus apply reports soc-channel-users`（内部调用 `GET /apply/open_api/v2/reports/soc_channel_users`，通过 API Gateway）。

> **别名**：CLI 也支持 `mplus apply reports qywechat`（同一接口）。

> **DS 报告聚合用法**：本命令是 DS 报告的企微侧数据源。CLI 只出原始计数，渠道归类、跨源聚合、6 时段周期换算由 AI 按 [mplus-reports skill](../../../skills/mplus-reports/SKILL.md) 完成——对每个区间调本命令的 `--mode count --group_by add_juzi_follow_user_earliest_name` 再归类聚合。

## 命令示例

```bash
# 获取当期数据（默认日期范围）
mplus apply reports soc-channel-users --json

# 自定义日期范围
mplus apply reports soc-channel-users --start_date 2026-01-13 --end_date 2026-06-15 --json

# 计数模式，按添加托管账号分组
mplus apply reports soc-channel-users --start_date 2026-01-13 --end_date 2026-06-15 --mode count --group_by add_juzi_follow_user_earliest_name --json

# 按企微标签过滤（包含任一）
mplus apply reports soc-channel-users --start_date 2026-01-13 --end_date 2026-06-15 --qy_tag "VIP,重点" --qy_tag_match any --json

# 按添加托管账号过滤（归属渠道的主依据）
mplus apply reports soc-channel-users --start_date 2026-01-13 --end_date 2026-06-15 --early_follower "张三,李四" --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--start_date <value>` | 否 | string | 当期起始日 | 开始日期（YYYY-MM-DD） |
| `--end_date <value>` | 否 | string | 今天 | 结束日期（YYYY-MM-DD） |
| `--channel_type <value>` | 否 | string | `qywechat` | 渠道类型 |
| `--date_field <value>` | 否 | string | `created_at` | 过滤用时间字段：`created_at`/`revisit_at`/`contact_at`/`successful_contact_at`/`confirm_meeting_at`/`meeting_at` |
| `--output-schema <value>` | 否 | JSON string | — | 稀疏字段集，只返回明细对象的部分字段，格式 `{"soc_channel_user": ["id", ...]}`（key 固定为 `soc_channel_user`）。仅 `mode=detail` 生效 |
| `--mode <value>` | 否 | string | `detail` | 输出模式：`detail`（明细）或 `count`（计数统计） |
| `--group_by <value>` | 否 | string | — | 仅 `mode=count` 时生效，分组字段（CSV）：`add_juzi_follow_user_earliest_name`/`qy_tag_names`/`channel_type` |
| `--page <value>` | 否 | string | `1` | 页码（仅 detail 模式） |
| `--page_size <value>` | 否 | string | `20` | 每页数量（仅 detail 模式），上限 100 |
| `--early_follower <value>` | 否 | string | — | 按最早添加托管账号过滤（渠道归属的主依据，对应 API 字段 `add_juzi_follow_user_earliest_name`），CSV 格式多值 OR |
| `--qy_tag <value>` | 否 | string | — | 按企微标签过滤（CSV 格式） |
| `--qy_tag_match <value>` | 否 | string | `any` | 企微标签匹配模式：`any`/`all`/`none` |
| `--meeting_success <value>` | 否 | string | — | 是否成功开会（null 视为 false） |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> **权限**：需要 `apply:contacts:read:all`。

## 返回结构

### detail 模式

```json
{
  "start_date": "2026-01-13",
  "end_date": "2026-06-15",
  "date_field": "created_at",
  "mode": "detail",
  "page": 1,
  "page_size": 20,
  "total": 800,
  "items": [
    {
      "id": "1",
      "channel_type": "qywechat",
      "unionid": "...",
      "add_juzi_follow_user_earliest_name": "张三",
      "qy_tag_names": ["VIP"],
      "created_at": "2026-02-01T08:00:00Z"
    }
  ]
}
```

### count + group_by 模式

```json
{
  "start_date": "2026-01-13",
  "end_date": "2026-06-15",
  "date_field": "created_at",
  "mode": "count",
  "group_by": ["add_juzi_follow_user_earliest_name"],
  "total": 800,
  "groups": [
    { "add_juzi_follow_user_earliest_name": "张三", "count": 300 },
    { "add_juzi_follow_user_earliest_name": "李四", "count": 200 }
  ]
}
```

## AI 使用建议

1. **渠道归属主依据是 `early_follower`**：`add_juzi_follow_user_earliest_name` 是最早添加托管账号的人名，是判断企微用户归属哪个运营人员的主要依据
2. **qy_tag_names 过滤精度**：企微标签匹配仅用于明细过滤，count 模式中 `group_by=qy_tag_names` 按标签展开分组
3. **PII 保护**：明细含 `unionid` 等敏感字段，不要直接回显给用户

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-reports-contacts](apply-reports-contacts.md) — 手机号人脉统计
- [mplus-reports SKILL.md](../../../skills/mplus-reports/SKILL.md) — DS 报告：归类聚合算法、6 时段周期换算、归属规则
