# admission scoring-sessions

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询模型打分 Session，每个 Session 对应一次模型对某项目的完整打分运行，包含所有 feature 的分数。

## feature_scores 格式

```json
{
  "创始人毕业于名校": ["创始人毕业于清华大学", 1.0],
  "创始人是否辍学": ["材料没有明确说明", 0.5]
}
```

- 值为 `[reason, score]` 数组
- `score` 含义：`1.0`=是/同意，`0.0`=否/不同意，`0.5`=不确定

## 两个子命令

### 1. list — 查询 Session 列表

对应命令：`mplus admission scoring-sessions list`（内部调用 `GET /admission/api/v1/scoring-sessions`）。

```bash
# 查询某项目的所有打分 Session
mplus admission scoring-sessions list --project_id 87575 --json

# 按批次代码过滤
mplus admission scoring-sessions list --batch_code a --json

# 按模型名称过滤
mplus admission scoring-sessions list --model_name gpt-4.1 --json

# 按状态过滤
mplus admission scoring-sessions list --status completed --json

# 组合过滤
mplus admission scoring-sessions list --project_id 87575 --model_name gpt-4.1 --status completed --json
```

#### 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--project_id <value>` | 否 | string | 按项目 ID 过滤 |
| `--batch_id <value>` | 否 | string | 按打分批次 ID 过滤 |
| `--batch_code <value>` | 否 | string | 按打分批次代码过滤（如 `a`/`b`/`c`） |
| `--model_name <value>` | 否 | string | 按模型名称过滤 |
| `--scoring_method <value>` | 否 | string | 按打分方法过滤 |
| `--status <value>` | 否 | string | 按状态过滤：`pending`/`running`/`completed`/`failed` |
| `--feature_name <value>` | 否 | string | 按 feature 名称过滤（含该 feature 的 Session） |
| `--page <value>` | 否 | string | 页码，默认 1 |
| `--page_size <value>` | 否 | string | 每页数量，默认 20，上限 100 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

#### 返回字段（列表，不含 feature_scores）

```json
{
  "total": 30,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "501",
      "project_id": "87575",
      "batch_id": "10",
      "batch_code": "a",
      "model_name": "gpt-4.1",
      "scoring_method": "cfgm",
      "status": "completed",
      "created_at": "2026-05-01T08:00:00Z"
    }
  ]
}
```

### 2. get — 查询单个 Session（含 feature_scores）

```bash
mplus admission scoring-sessions get 501 --json
```

单个 Session 响应包含完整 `feature_scores` 对象。

## 使用建议

- **仅查项目满足哪些 feature 条件**：优先用 `scoring-features matches`，效率更高
- **对一批项目做 feature 矩阵分析**：优先用 `scoring-features matrix`
- **scoring-sessions** 适合查询某项目的原始打分历史，或对比不同模型/批次的打分差异
- 同一项目可能有多个 Session（不同模型、不同时间），API 不合并，调用方自行判断

## 参考

- [mplus-admission SKILL.md](../SKILL.md) — admission 领域概览
- [admission-scoring-features](admission-scoring-features.md) — 按 feature 查项目（更高效）
- [admission-scoring-batches](admission-scoring-batches.md) — 查打分批次
