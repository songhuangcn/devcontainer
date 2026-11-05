# build camp_documents show

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取单篇创业营作业文档的完整内容（Markdown 快照）。内容来自定期同步的飞书文档快照，非实时拉取，包含文档元信息、所属作业、所属公司和缓存时间等。

对应命令：`mplus build camp_documents show <id>`（内部调用 `GET /build/open_api/v2/camp_documents/{id}`，通过 API Gateway）。

## 命令示例

```bash
# 获取作业文档 456 的内容
mplus build camp_documents show 456 --json

# 使用指定 profile
mplus build camp_documents show 456 --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | integer | 作业文档 ID（整数）|
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **重要限制**：`internal` 类型的作业文档不可通过 API 获取，会返回错误。
> **权限**：需要对该文档的 read 权限（`accelerator:camp_documents:read`）。

## 返回字段

响应为单篇文档对象，包含文档元信息、Markdown 内容快照、所属作业/公司、缓存时间等。各子字段随后端变动，使用 `--json` 输出后自行解析。

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `401 unauthorized` | token 无效或过期 | 执行 `mplus login` |
| `403 forbidden` | 缺少 `accelerator:camp_documents:read` 权限，或文档为 `internal` 类型 | 确认账号权限；internal 文档不支持 API 获取 |
| `404 not_found` | 文档不存在 | 确认文档 ID 正确 |

## AI 使用建议

1. **内容为离线快照**：来自定期同步的飞书文档快照，可能与飞书实时内容存在延迟
2. **internal 文档不可取**：遇到 internal 类型直接报错，不要重试

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
