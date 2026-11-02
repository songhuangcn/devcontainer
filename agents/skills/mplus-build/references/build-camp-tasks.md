# build camp_tasks

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取指定公司的作业列表（`public` + `privacy` 类型，不暴露 `internal` 类型），含每个作业关联的文档和物料。

对应命令：`mplus build camp_tasks list <companyId>`（内部调用 `GET /build/open_api/v2/companies/{company_id}/camp_tasks`）。

## 命令示例

```bash
# 获取公司 420 的全部作业（public + privacy）
mplus build camp_tasks list 420 --json

# 只看 public 类型
mplus build camp_tasks list 420 --task_type public --json

# 分页
mplus build camp_tasks list 420 --page 2 --page_size 50 --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<companyId>` | 是 | integer | 公司 ID 或 slug |
| `--task_type <value>` | 否 | string | 过滤作业类型：`public` / `privacy` |
| `--page <value>` | 否 | string | 页码，默认 1 |
| `--page_size <value>` | 否 | string | 每页数量，默认 20，上限 100 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

## 返回字段

```json
{
  "total": 83,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "task_id": "506",
      "task_name": "GOH Assignment1",
      "task_type": "public",
      "description": "",
      "start_at": "2023-08-31T14:00:00Z",
      "end_at": "2023-08-31T14:00:00Z",
      "documents": [
        {
          "document_id": "5676",
          "name": "GOH Assignment1-GOH作业1-adapgpt",
          "url": "https://miracleplus.feishu.cn/docs/...",
          "last_updated_at": "2023-08-31T13:35:10Z"
        }
      ],
      "materials": [
        { "id": "12", "name": "参考资料标题" }
      ]
    }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `task_type` | `public`（公开）/ `privacy`（私有，仅该公司可见）；`internal` 类型不会出现 |
| `documents` | 该公司在此作业下提交的文档，`document_id` 可配合 `mplus build camp_documents show` 查看正文 |
| `materials` | 作业关联的参考物料 |

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `401 unauthorized` | token 无效或过期 | 执行 `mplus login` |
| `403 forbidden` | 缺少 `accelerator:camp_tasks:read` 权限 | 确认账号角色 |
| `404 not_found` | 公司 ID 不存在 | 确认 `<companyId>` 正确，可用 `mplus company list` 查找 |

## AI 使用建议

1. **`<companyId>` 是必填位置参数**，不是 query 参数，命令格式固定为 `camp_tasks list <companyId>`
2. 拿到 `document_id` 后可用 `mplus build camp_documents show <document_id>` 查看文档正文

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
- [build-camp-documents-show](build-camp-documents-show.md) — 作业文档正文
