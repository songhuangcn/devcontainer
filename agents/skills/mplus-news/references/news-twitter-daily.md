# news twitter daily

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取齐思（HackerNews 后端）每日 Twitter 爬取内容，按 Asia/Shanghai 自然日分页返回。

对应命令：`mplus news twitter daily`（内部调用 `GET /news/open_api/v1/twitter/daily`，通过 API Gateway）。

## 命令示例

```bash
# 获取今天内容（默认，Asia/Shanghai 时区）
mplus news twitter daily --json

# 获取指定日期内容
mplus news twitter daily --date 2026-06-10 --json

# 指定每页数量（最多 100）
mplus news twitter daily --date 2026-06-10 --page-size 100 --json

# 翻页
mplus news twitter daily --date 2026-06-10 --page 2 --page-size 100 --json

# 使用指定 profile
mplus news twitter daily --date 2026-06-10 --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--date <YYYY-MM-DD>` | 否 | string | 今天（Asia/Shanghai） | 按 `published_at` 过滤的上海时区自然日 |
| `--page <number>` | 否 | string | `"1"` | 页码，从 1 开始 |
| `--page-size <number>` | 否 | string | `"20"` | 每页数量，上限 100 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

## 返回字段

### JSON 格式（`--json`）

```json
{
  "date": "2026-06-10",
  "timezone": "Asia/Shanghai",
  "total": 85,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "12345",
      "content_type": "scraped_content",
      "source": "twitter",
      "title": "Elon Musk(@elonmusk)",
      "content": "推文原文...",
      "content_en": null,
      "source_account": "Elon Musk(@elonmusk)",
      "source_url": "https://twitter.com/elonmusk/status/12345",
      "published_at": "2026-06-10T14:30:00Z",
      "crawled_at": "2026-06-10T14:35:00Z",
      "status": "generated",
      "source_meta": {
        "like": 1000,
        "retweet": 200
      },
      "share_link_id": null,
      "share_link_url": null,
      "topics": [],
      "insight": {
        "score": 85,
        "summary": "洞见摘要...",
        "content_zh": "中文深度分析..."
      }
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `date` | string | 查询的日期（YYYY-MM-DD） |
| `timezone` | string | 固定为 `Asia/Shanghai` |
| `total` | number | 该日期符合条件的总条数 |
| `page` | number | 当前页码 |
| `page_size` | number | 每页数量 |
| `items[].id` | string | 内容唯一标识 |
| `items[].source` | string | `twitter` 或 `twitter_founder` |
| `items[].content` | string | 推文原文 |
| `items[].source_account` | string | 发推账号（含括号内的用户名） |
| `items[].source_url` | string | 原始推文链接 |
| `items[].published_at` | string | 发布时间（ISO 8601 UTC） |
| `items[].status` | string | `pending`（待处理）/ `generated`（已生成洞见）/ `disuse`（废弃） |
| `items[].source_meta` | object | 互动数据（like、retweet），不含评论原文 |
| `items[].insight` | object\|null | GPT 洞见，仅 `status=generated` 的内容才有；含 `score`（0-100）、`summary`、`content_zh` |
| `items[].topics` | array | 若已关联 ShareLink，返回 GPT/人工话题标签，否则为空数组 |
| `items[].share_link_id` | string\|null | 已发布为齐思 ShareLink 时的 ID |

## 排序规则

固定为 `published_at DESC, id DESC`，同一 `date` 下翻页结果稳定、不重叠。

## 分页策略

接口每次最多返回 100 条，如需全天数据：

```bash
# 第 1 步：先拿 100 条，查看 total
mplus news twitter daily --date 2026-06-10 --page 1 --page-size 100 --json

# 如果 total > 100，继续翻页
mplus news twitter daily --date 2026-06-10 --page 2 --page-size 100 --json

# 以此类推，直到 len(items) < page_size 或 page * page_size >= total
```

- 总页数 = `Math.ceil(total / page_size)`
- 当 `page * page_size >= total` 或返回条数 `< page_size` 时，已到最后一页

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `401 unauthorized` | token 缺失或无效 | 执行 `mplus login` |
| `403 forbidden` | 缺少 `news:twitter:read` 权限 | 用 `mplus whoami --json` 确认账号角色 |
| `400 bad_request` | `date` 格式错误 | 使用 `YYYY-MM-DD` 格式 |

## AI 使用建议

1. **先查 total 再决定是否翻页**：第一次请求 `page_size=100`，根据 `total` 判断还需几页
2. **status 过滤**：`status=generated` 的内容有 `insight`，`pending` 的没有；可在结果中自行过滤
3. **时间换算**：`published_at` 为 UTC，比上海时间早 8 小时；查某天内容时按 `date` 参数（上海时区）过滤即可

## 参考

- [mplus-news](../SKILL.md) — news 领域概览
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
