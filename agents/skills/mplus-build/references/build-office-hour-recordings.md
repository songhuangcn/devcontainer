# build office_hour_recordings

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取指定公司的 Office Hour 录音转文字列表及详情。`list` 不含正文（节省体积），`show` 含完整转写内容。

对应命令：
- `mplus build office_hour_recordings list <companyId>`（`GET /build/open_api/v2/companies/{company_id}/office_hour_recordings`）
- `mplus build office_hour_recordings show <companyId> <id>`（`GET /build/open_api/v2/companies/{company_id}/office_hour_recordings/{id}`）

## 命令示例

```bash
# 列出公司 420 的全部 OH 录音（不含正文）
mplus build office_hour_recordings list 420 --json

# 查看某条录音详情（含转写正文）
mplus build office_hour_recordings show 420 88 --json
```

## 参数

### list

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<companyId>` | 是 | integer | 公司 ID 或 slug |
| `--page <value>` | 否 | string | 页码，默认 1 |
| `--page_size <value>` | 否 | string | 每页数量，默认 20，上限 100 |
| `--profile <name>` / `--json` | 否 | — | 通用参数 |

### show

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<companyId>` | 是 | integer | 公司 ID 或 slug |
| `<id>` | 是 | integer | 录音 ID |
| `--profile <name>` / `--json` | 否 | — | 通用参数 |

> **注意位置参数顺序**：`show` 命令是 `<companyId>` 在前、`<id>` 在后，两者都来自 URL 路径，不能省略或颠倒。

## 返回字段

```json
{
  "id": "88",
  "title": "Office Hour 2026-01",
  "recorded_at": "2026-01-15T10:00:00Z",
  "content_format": "markdown",
  "cached_at": "2026-01-15T12:00:00Z",
  "content": "..."
}
```

| 字段 | 说明 |
|------|------|
| `content_format` | 转写正文格式，通常为 `markdown` |
| `cached_at` | 缓存抓取时间，非录音发生时间 |
| `content` | 仅 `show` 返回，转写全文 |

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `403 forbidden` | 缺少 `accelerator:office_hour_recordings:read` 权限 | 确认账号角色 |
| `404 not_found` | 公司或录音 ID 不存在 | 先用 `list` 确认 `id` |
| 返回 `total: 0` | 该公司暂无 OH 录音转写记录 | 非错误，正常空结果 |

## AI 使用建议

1. 先 `list` 拿到 `id`，再用 `show <companyId> <id>` 查看正文，避免一次性拉取全部正文
2. `<companyId>` 在 `list` 和 `show` 中含义相同，均为路径参数

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
