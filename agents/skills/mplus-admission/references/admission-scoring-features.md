# admission scoring-features

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

按 Feature 名称和分数阈值查询项目，或批量导出项目的 Feature 分数矩阵。是 Admission 系统中最常用的分析工具。

## 三个子命令

### 1. catalog — 查询 Feature 目录

```bash
mplus admission scoring-features catalog --json
```

返回所有已知 Feature 名称列表，用于了解有哪些 feature 可用于过滤。

### 2. matches — 按 Feature 查询项目

对应命令：`mplus admission scoring-features matches`（内部调用 `POST /admission/api/v1/scoring-features/matches`）。

按指定 feature 名称和分数阈值，查询满足条件的项目列表（按 project 聚合平均分）。

```bash
# 查询"创始人毕业于名校"评分 >= 0.7 的项目
mplus admission scoring-features matches --features "创始人毕业于名校" --json

# 多个 feature（同时满足）
mplus admission scoring-features matches --features "创始人毕业于名校,团队有连续创业经历" --json

# 自定义阈值
mplus admission scoring-features matches --features "创始人毕业于名校" --threshold 0.8 --json

# 返回 feature 的 reason 说明
mplus admission scoring-features matches --features "创始人毕业于名校" --include-reason --json

# 返回贡献该分数的 session 明细
mplus admission scoring-features matches --features "创始人毕业于名校" --include-sessions --json

# 按打分批次代码过滤 session（如只看某批模型跑出的结果）
mplus admission scoring-features matches --features "创始人毕业于名校" --filter-batch-code a --json

# 按模型名称过滤
mplus admission scoring-features matches --features "创始人毕业于名校" --filter-model-name gpt-4.1 --json

# 按申请批次过滤（项目所属批次）
mplus admission scoring-features matches --features "创始人毕业于名校" --filter-batch-id 15 --json

# 分页
mplus admission scoring-features matches --features "创始人毕业于名校" --page 2 --page-size 50 --json
```

#### 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--features <features>` | **是** | string | — | feature 名称列表，**逗号分隔**，如 `"创始人毕业于名校,团队有连续创业经历"` |
| `--threshold <value>` | 否 | string | `0.7` | 分数阈值 0-1，平均分 >= 阈值才返回 |
| `--include-reason` | 否 | flag | false | 返回每个 feature 的 reason 列表 |
| `--include-sessions` | 否 | flag | false | 返回贡献该分数的 session 明细 |
| `--page <value>` | 否 | string | `1` | 页码 |
| `--page-size <value>` | 否 | string | `20` | 每页数量，上限 100 |
| `--filter-project-id <value>` | 否 | string | — | 按项目 ID 过滤 |
| `--filter-batch-id <value>` | 否 | string | — | 按申请批次 ID 过滤 |
| `--filter-batch-code <value>` | 否 | string | — | 按打分批次代码过滤（如 `a`/`b`/`c`） |
| `--filter-model-name <value>` | 否 | string | — | 按模型名称过滤（如 `gpt-4.1`） |
| `--filter-scoring-method <value>` | 否 | string | — | 按打分方法过滤（如 `cfgm`） |
| `--filter-status <value>` | 否 | string | — | 按 session 状态过滤（如 `completed`） |
| `--profile <name>` | 否 | string | — | 临时使用指定 profile |
| `--json` | 否 | boolean | false | 以 JSON 格式输出 |

#### 返回结构

```json
{
  "total": 150,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "project_id": 87575,
      "batch_name": "26s",
      "features": {
        "创始人毕业于名校": {
          "avg_score": 0.95,
          "reasons": ["创始人毕业于清华大学"],
          "sessions": [{ "session_id": 501, "score": 1.0 }]
        }
      }
    }
  ]
}
```

### 3. matrix — 批量导出 Feature 矩阵

对应命令：`mplus admission scoring-features matrix`（内部调用 `POST /admission/api/v1/scoring-features/matrix`）。

对已知的一批项目（最多 500 个），一次性导出所有 feature 的聚合平均分矩阵。

```bash
# 为一批项目导出所有 feature 的分数矩阵
mplus admission scoring-features matrix --project-ids "87575,87576,87577" --json

# 只导出指定 feature 的矩阵
mplus admission scoring-features matrix --project-ids "87575,87576,87577" --features "创始人毕业于名校,团队有连续创业经历" --json

# 同时返回每个 feature 的 session 数量
mplus admission scoring-features matrix --project-ids "87575,87576" --include-session-counts --json

# 按模型名称过滤 session
mplus admission scoring-features matrix --project-ids "87575,87576" --filter-model-name gpt-4.1 --json
```

#### 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--project-ids <ids>` | **是** | string | 项目 ID 列表，**逗号分隔**，**最多 500 个**，如 `"87575,87576"` |
| `--features <features>` | 否 | string | feature 名称列表，逗号分隔；不传时返回所有观察到的 feature |
| `--include-session-counts` | 否 | flag | 返回每个 feature 的 session 数量 |
| `--filter-batch-id <value>` | 否 | string | 按申请批次 ID 过滤 |
| `--filter-batch-code <value>` | 否 | string | 按打分批次代码过滤 |
| `--filter-model-name <value>` | 否 | string | 按模型名称过滤 |
| `--filter-scoring-method <value>` | 否 | string | 按打分方法过滤 |
| `--filter-status <value>` | 否 | string | 按 session 状态过滤 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

#### 返回结构

```json
{
  "projects": [
    {
      "project_id": 87575,
      "batch_name": "26s",
      "features": {
        "创始人毕业于名校": { "avg_score": 0.95, "session_count": 3 },
        "团队有连续创业经历": { "avg_score": 0.33, "session_count": 3 }
      }
    }
  ]
}
```

## 使用策略

| 场景 | 推荐命令 |
|------|---------|
| 按 feature 条件找项目 | `matches` |
| 对已知项目列表做横向 feature 比较 | `matrix` |
| 查某项目每次打分的原始输出 | `scoring-sessions get` |
| 了解有哪些 feature 可用 | `catalog` |

> **避免**: 逐 project 循环调用 `scoring-sessions list` 再解析 `feature_scores`，效率极低；请改用 `matrix`。

## 参考

- [mplus-admission SKILL.md](../SKILL.md) — admission 领域概览
- [admission-scoring-sessions](admission-scoring-sessions.md) — 查原始 scoring session
- [admission-scoring-batches](admission-scoring-batches.md) — 查打分批次（获取 batch_code）
