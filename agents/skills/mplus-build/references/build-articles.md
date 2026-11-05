# build articles

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取指定公司的资料（company article）列表及详情。**仅限内部用户**，创始人无权访问。

对应命令：
- `mplus build articles list <companyId>`（`GET /build/open_api/v2/companies/{company_id}/articles`）
- `mplus build articles show <companyId> <id>`（`GET /build/open_api/v2/companies/{company_id}/articles/{id}`）

## 命令示例

```bash
# 列出公司 420 的资料列表（不含正文）
mplus build articles list 420 --json

# 查看某条资料详情（含正文）
mplus build articles show 420 12 --json
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
| `<id>` | 是 | integer | 资料 ID |
| `--profile <name>` / `--json` | 否 | — | 通用参数 |

## 返回字段

```json
{
  "id": "12",
  "title": "公司资料标题",
  "published_at": "2026-01-10T00:00:00Z",
  "content_format": "markdown",
  "created_at": "2026-01-10T08:00:00Z",
  "content": "..."
}
```

| 字段 | 说明 |
|------|------|
| `content` | 仅 `show` 返回，资料正文 |

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `403 forbidden` | 缺少 `accelerator:company_articles:read` 权限，**创始人账号会始终被拒绝** | 仅内部用户（partner/admin）可调用 |
| `404 not_found` | 公司或资料 ID 不存在 | 先用 `list` 确认 `id` |

## AI 使用建议

1. **创始人 token 调用必然 403**，这是设计行为，不是 bug，不要重试
2. 先 `list` 拿到 `id`，再 `show <companyId> <id>` 看正文

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
