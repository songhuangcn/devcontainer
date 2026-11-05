# admission scoring-batches

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询模型打分批次（scoring batch），了解有哪些批次的打分任务、使用了哪些模型、运行状态如何。

## 两个子命令

### 1. list — 查询打分批次列表

对应命令：`mplus admission scoring-batches list`（内部调用 `GET /admission/api/v1/scoring-batches`）。

```bash
# 查询所有打分批次
mplus admission scoring-batches list --json

# 按批次代码过滤
mplus admission scoring-batches list --batch_code a --json

# 按模型名称过滤
mplus admission scoring-batches list --model_name gpt-4.1 --json

# 按状态过滤（只看已完成的）
mplus admission scoring-batches list --status completed --json

# 按打分方法过滤
mplus admission scoring-batches list --scoring_method cfgm --json

# 分页
mplus admission scoring-batches list --page 2 --page_size 50 --json
```

#### 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--batch_code <value>` | 否 | string | 按批次代码过滤（如 `a`/`b`/`c`） |
| `--model_name <value>` | 否 | string | 按模型名称过滤（如 `gpt-4.1`） |
| `--scoring_method <value>` | 否 | string | 按打分方法过滤（如 `cfgm`） |
| `--status <value>` | 否 | string | 按状态过滤：`pending`/`running`/`completed`/`failed` |
| `--page <value>` | 否 | string | 页码，默认 1 |
| `--page_size <value>` | 否 | string | 每页数量，默认 20，上限 100 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

#### 返回字段

```json
{
  "total": 5,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "10",
      "batch_code": "a",
      "model_name": "gpt-4.1",
      "scoring_method": "cfgm",
      "status": "completed",
      "created_at": "2026-04-20T08:00:00Z",
      "completed_at": "2026-04-21T10:00:00Z"
    }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `id` | 打分批次 ID（用于 `scoring-sessions --batch_id` 过滤） |
| `batch_code` | 批次代码（用于 `scoring-features matches/matrix --filter-batch-code` 过滤） |
| `model_name` | 使用的模型名称 |
| `scoring_method` | 打分方法 |
| `status` | 批次状态 |

### 2. get — 查询单个打分批次

```bash
mplus admission scoring-batches get <id> --json
```

## 使用场景

- 在用 `scoring-features matches/matrix` 时，需要通过 `--filter-batch-code` 限定使用某次打分的结果，先用此命令确认 `batch_code`
- 了解模型打分任务的整体进度和状态

## 参考

- [mplus-admission SKILL.md](../SKILL.md) — admission 领域概览
- [admission-scoring-features](admission-scoring-features.md) — 使用 batch_code 过滤 feature 查询
- [admission-scoring-sessions](admission-scoring-sessions.md) — 使用 batch_id 过滤 session 查询
