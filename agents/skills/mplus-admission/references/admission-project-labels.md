# admission project-labels

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询项目的事后确认标签（project_labels），覆盖面试结论、MOIC、Tier、财务表现等沉淀数据。

## 三个子命令

### 1. schema — 获取标签 Schema

```bash
mplus admission project-labels schema --json
```

返回所有可用的 `label_key` 列表及其类型定义，用于了解有哪些标签维度可查。

### 2. list — 查询标签列表

对应命令：`mplus admission project-labels list`（内部调用 `GET /admission/api/v1/project-labels`）。

```bash
# 查询某项目的所有标签
mplus admission project-labels list --project_id 87575 --json

# 查询某批次的所有标签
mplus admission project-labels list --batch_name 26s --json

# 按标签类型过滤
mplus admission project-labels list --batch_name 26s --label_key interview_conclusion --json

# 按多个标签类型过滤（逗号分隔）
mplus admission project-labels list --batch_name 26s --label_keys "interview_conclusion,moic" --json

# 分页
mplus admission project-labels list --batch_name 26s --page 2 --page_size 50 --json
```

#### 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--project_id <value>` | 否 | string | 按项目 ID 过滤 |
| `--project_ids <value>` | 否 | string | 按多个项目 ID 过滤（逗号分隔） |
| `--batch_name <value>` | 否 | string | 按批次名过滤（如 `26s`） |
| `--label_key <value>` | 否 | string | 按标签类型过滤（单个） |
| `--label_value <value>` | 否 | string | 按标签值过滤 |
| `--label_keys <value>` | 否 | string | 按多个标签类型过滤（逗号分隔） |
| `--page <value>` | 否 | string | 页码，默认 1 |
| `--page_size <value>` | 否 | string | 每页数量，默认 20，上限 100 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

#### 返回字段

```json
{
  "total": 50,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "101",
      "project_id": "87575",
      "batch_name": "26s",
      "label_key": "interview_conclusion",
      "label": "3Y2y1n",
      "created_at": "2026-04-01T08:00:00Z"
    }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `label_key` | 标签类型（如 `interview_conclusion`/`moic`/`tier`） |
| `label` | 标签值（如 `3Y2y1n` 表示面试结论汇总投票） |

### 3. get — 查询单个标签

```bash
mplus admission project-labels get <id> --json
```

## 重要说明

- `project_labels` 是**事后沉淀的确认结论**（如面试汇总投票、MOIC、Tier），不是评委当时的个人 vote
- 如果要查"某评委当时判断"，需查 Apply `evaluations` 中该评委的 `rating_key`
- `interview_conclusion` 格式如 `3Y2y1n`：大写=强烈支持，小写=支持，`n`=反对

## 参考

- [mplus-admission SKILL.md](../SKILL.md) — admission 领域概览
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
- [admission-startup-projects-list](admission-startup-projects-list.md) — 项目列表
