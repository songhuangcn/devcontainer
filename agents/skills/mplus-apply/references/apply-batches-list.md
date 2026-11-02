# apply batches list

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

分页获取所有申请批次及各轮次统计数据，按批次开始日期倒序排列。

对应命令：`mplus apply batches list`（内部调用 `GET /apply/open_api/v2/batches`，通过 API Gateway）。

## 命令示例

```bash
# 获取批次列表（默认第 1 页，每页 20 条）
mplus apply batches list --json

# 分页
mplus apply batches list --page 2 --page_size 50 --json

# 使用指定 profile
mplus apply batches list --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--page <number>` | 否 | string | `"1"` | 页码，从 1 开始 |
| `--page_size <number>` | 否 | string | `"20"` | 每页数量，上限 100 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> **权限**：需要 `apply:batches:read` 权限。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "total": 12,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "15",
      "name": "2026春季批",
      "abbreviation": "26s",
      "start_date": "2026-02-01",
      "end_date": "2026-07-31",
      "applications": 500,
      "submitted": 430,
      "not_submitted": 70,
      "round1": {
        "pending": 10,
        "rejected": 200
      },
      "round2": {
        "passed": 80,
        "pending": 5,
        "rejected": 140
      }
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 批次 ID（字符串，传给 `applications list --batch` 时用此值） |
| `name` | string | 批次名称（如"2026春季批"） |
| `abbreviation` | string | 批次简称（如"26s"，与 admission batch_name 对应） |
| `start_date` | string | 批次开始日期（YYYY-MM-DD） |
| `end_date` | string | 批次结束日期（YYYY-MM-DD） |
| `applications` | number | 申请表总数 |
| `submitted` | number | 已提交申请数 |
| `not_submitted` | number | 草稿（未提交）申请数 |
| `round1.pending` | number | 一面待审阅数 |
| `round1.rejected` | number | 一面未通过数 |
| `round2.passed` | number | 二面通过数（已进入面试轮） |
| `round2.pending` | number | 二面待审阅数 |
| `round2.rejected` | number | 二面未通过数 |

## AI 使用建议

1. **获取批次 ID**：`applications list --batch <id>` 需要批次整数 ID（`items[].id` 字段），不是 `abbreviation`
2. **abbreviation 与 admission batch_name**：`abbreviation`（如 `26s`）对应 admission 中的 `batch_name`，可以交叉引用
3. **统计口径**：`applications` = `submitted` + `not_submitted`；各轮次的 pending + accepted + rejected ≈ 进入该轮次的总数

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-applications-list](apply-applications-list.md) — 申请表列表（需要批次 ID）
