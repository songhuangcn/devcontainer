# admission startup-projects list

> **前置条件：** 先用 Read 工具读取 [`../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询 startup_projects 列表，支持按批次、补充材料、项目 ID 过滤，支持分页。

对应命令：`mplus admission startup-projects list`（内部调用 `GET /admission/api/v1/startup-projects`，通过 API Gateway）。

## 命令示例

```bash
# 查询所有项目（默认第 1 页，每页 20 条）
mplus admission startup-projects list

# JSON 格式输出（AI Agent 推荐）
mplus admission startup-projects list --json

# 按批次过滤
mplus admission startup-projects list --batch-name "26s"

# 只看补充材料
mplus admission startup-projects list --addition true

# 只看初始提交
mplus admission startup-projects list --addition false

# 按项目 ID 精确查询
mplus admission startup-projects list --project-id "87575"

# 分页：第 2 页，每页 50 条
mplus admission startup-projects list --page 2 --page-size 50

# 组合过滤 + 分页 + JSON
mplus admission startup-projects list --batch-name "25a" --addition false --page 1 --page-size 10 --json

# 使用指定 profile
mplus admission startup-projects list --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--batch-name <name>` | 否 | string | — | 按批次名过滤（精确匹配，格式 `<YY><季节>` 小写，季节：`s`=春、`a`=秋，如 `"25a"`、`"26s"`） |
| `--addition <bool>` | 否 | string | — | 按补充材料过滤：`true` 只返回补充提交，`false` 只返回初始提交 |
| `--project-id <id>` | 否 | string | — | 按 project_id 精确过滤 |
| `--page <number>` | 否 | string | `"1"` | 页码，从 1 开始 |
| `--page-size <number>` | 否 | string | `"20"` | 每页数量 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> **`--addition` 取值规则**：接受 `true`/`1`/`yes`/`y` 或 `false`/`0`/`no`/`n`（不区分大小写）。其他值会报错。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "total": 156,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "project_id": "87575",
      "batch_name": "26s",
      "application_content": "完整的申请材料文本...",
      "interview_content": "完整的面试材料文本...",
      "addition": false
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `total` | number | 符合条件的总记录数 |
| `page` | number | 当前页码 |
| `page_size` | number | 每页数量 |
| `items` | array | 项目列表 |
| `items[].project_id` | string | 项目唯一标识 |
| `items[].batch_name` | string | 所属批次名 |
| `items[].application_content` | string \| null | 申请材料全文（可能为 null） |
| `items[].interview_content` | string \| null | 面试材料全文（可能为 null） |
| `items[].addition` | boolean | 是否为补充材料 |

### 默认文本格式

文本格式只显示摘要信息（材料长度而非全文）：

```
共 156 条，当前第 1 页，每页 20 条

项目 ID：87575
批次：26s
补充材料：否
申请材料长度：3456
面试材料长度：2100

项目 ID：87611
批次：26s
补充材料：是
申请材料长度：0
面试材料长度：1800
```

## 分页

服务端分页，通过 `--page` 和 `--page-size` 控制：

- `total` 表示符合过滤条件的总记录数
- 总页数 = `Math.ceil(total / page_size)`
- 翻页：递增 `--page` 值

```bash
# 第 1 页
mplus admission startup-projects list --json --page 1 --page-size 20

# 第 2 页
mplus admission startup-projects list --json --page 2 --page-size 20

# 第 3 页
mplus admission startup-projects list --json --page 3 --page-size 20
```

**判断是否还有下一页**：当 `page * page_size < total` 时，还有更多数据。

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `OAuth 鉴权失败，请运行 mplus login 重新登录` | token 过期且刷新失败 | 执行 `mplus login` |
| `未找到 OAuth session，请先运行 mplus login` | 从未登录 | 执行 `mplus login` |
| `--addition 只能是 true 或 false` | `--addition` 传了非法值 | 使用 `true`/`false`/`1`/`0`/`yes`/`no` |
| `你没有访问该资源的权限` | 当前用户无 admission 数据权限 | 确认账户权限 |
| `资源不存在` | API 路径错误或服务未部署 | 检查 API Gateway 状态 |

## AI 使用建议

1. **获取完整材料内容**：必须加 `--json`。默认文本格式只显示材料长度（字符数），不显示实际内容
2. **大批量数据**：先查一次不带过滤条件看 `total`，再决定分页策略。如果 total 很大，优先加过滤条件缩小范围
3. **查找特定项目**：如果知道 project_id，直接用 `--project-id` 过滤（或用 `get` 子命令）
4. **批次名格式**：`<YY><季节>` 小写，年份在前。季节字母：`s`=春季批、`a`=秋季批。例如 `26s`=2026 春季批、`25a`=2025 秋季批。已观察到 `20a`、`22s`/`22a`、`23s`/`23a`、`24s`/`24a`、`25s`/`25a`、`26s`。`--batch-name` 精确匹配，注意大小写
5. **材料为 null 的情况**：`application_content` 或 `interview_content` 为 null 表示该阶段材料尚未提交

## 参考

- [mplus-admission](../SKILL.md) — admission 领域概览
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
- [admission-startup-projects-get](admission-startup-projects-get.md) — 查询单个项目
