# admission company-invests list

> **前置条件：** 先用 Read 工具读取 [`../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询项目融资信息列表（`apply_company_invests` 表）。该表按 `application_id` 关联 Apply 申请/项目，顶层 `invest_*` 字段代表最近一次融资信息，`invests` 数组保存历史融资记录。支持按单个或批量 `application_id` 过滤，支持分页。

对应命令：`mplus admission company-invests list`（内部调用 `GET /admission/api/v1/company-invests`，通过 API Gateway）。

## 命令示例

```bash
# 查询所有项目融资信息（默认第 1 页，每页 20 条）
mplus admission company-invests list

# JSON 格式输出（AI Agent 推荐）
mplus admission company-invests list --json

# 按单个项目 ID 过滤
mplus admission company-invests list --application_id 60298

# 批量按多个项目 ID 过滤（逗号分隔）
mplus admission company-invests list --application_ids 60298,64872

# 分页：第 2 页，每页 50 条
mplus admission company-invests list --page 2 --page_size 50

# 组合过滤 + 分页 + JSON
mplus admission company-invests list --application_ids 60298,64872 --page 1 --page_size 10 --json

# 使用指定 profile
mplus admission company-invests list --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--application_id <id>` | 否 | string | — | 按单个 Apply application_id / 项目 ID 过滤。响应中 `application_id` 会序列化为 string，避免大整数精度问题 |
| `--application_ids <ids>` | 否 | string | — | 批量 Apply application_id / 项目 ID 过滤，英文逗号分隔（如 `60298,64872`）。重复 ID 会去重，非整数会返回 422 invalid_request |
| `--page <number>` | 否 | string | `"1"` | 1-based 页码，小于 1 会被服务端归一化为 1 |
| `--page_size <number>` | 否 | string | `"20"` | 每页数量，小于 1 归一化为 1，大于 100 限制为 100 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> `--application_id` 与 `--application_ids` 同时传时取并集；二者至少传一个以缩小范围，都不传则返回全量分页。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "total": 42,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "12345",
      "application_id": "60298",
      "company_name": "某某科技有限公司",
      "product_name": "某某产品",
      "legal_representative": "张三",
      "invest_date": "2026-03-15",
      "invest_round": "A轮",
      "invest_amount": "5000万人民币",
      "invest_proportion": "10%",
      "invest_investor": "某某资本,某某基金",
      "invest_news_source": "https://...",
      "invests": [
        {
          "date": "2026-03-15",
          "round": "A轮",
          "amount": "5000万人民币",
          "investor": "某某资本",
          "valuation": "5亿",
          "proportion": "10%",
          "news_source": "https://..."
        }
      ],
      "created_at": "2026-03-16T10:00:00Z",
      "updated_at": "2026-03-16T10:00:00Z"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `total` | number | 符合条件的总记录数 |
| `page` | number | 当前页码 |
| `page_size` | number | 每页数量 |
| `items` | array | 项目融资信息列表 |
| `items[].id` | string | `apply_company_invests` 主键，序列化为 string |
| `items[].application_id` | string | Apply application_id / 项目 ID，序列化为 string |
| `items[].company_name` | string \| null | 公司名称 |
| `items[].product_name` | string \| null | 项目名称（来自 apply_answers.product_name） |
| `items[].legal_representative` | string \| null | 法定代表人 |
| `items[].invest_date` | string(date) \| null | 最近一次融资日期 |
| `items[].invest_round` | string \| null | 最近一次融资轮次 |
| `items[].invest_amount` | string \| null | 最近一次融资金额 |
| `items[].invest_proportion` | string \| null | 最近一次融资比例 |
| `items[].invest_investor` | string \| null | 最近一次融资投资方 |
| `items[].invest_news_source` | string \| null | 最近一次融资新闻来源 |
| `items[].invests` | array | 历史融资记录数组，元素含 `date`/`round`/`amount`/`investor`/`valuation`/`proportion`/`news_source` |
| `items[].created_at` | string(date-time) | 记录创建时间 |
| `items[].updated_at` | string(date-time) | 记录更新时间 |

## 分页

服务端分页，通过 `--page` 和 `--page_size` 控制：

- `total` 表示符合过滤条件的总记录数
- 总页数 = `Math.ceil(total / page_size)`
- 翻页：递增 `--page` 值

```bash
mplus admission company-invests list --json --page 1 --page_size 20
mplus admission company-invests list --json --page 2 --page_size 20
```

**判断是否还有下一页**：当 `page * page_size < total` 时，还有更多数据。

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `OAuth 鉴权失败，请运行 mplus login 重新登录` | token 过期且刷新失败 | 执行 `mplus login` |
| `未找到 OAuth session，请先运行 mplus login` | 从未登录 | 执行 `mplus login` |
| `422 invalid_request` | `--application_ids` 含非整数 | 只传整数 ID，逗号分隔 |
| `你没有访问该资源的权限` | 当前用户无 admission 数据权限 | 确认账户权限 |

## AI 使用建议

1. **ID 序列化为 string**：`id` 和 `application_id` 在响应中都是 string（避免大整数精度丢失），比较时按字符串处理
2. **顶层 vs 数组**：顶层 `invest_*` 是最近一次融资的快照，`invests` 数组是完整历史。只需要最新一轮看顶层字段即可
3. **批量查询**：知道多个项目 ID 时用 `--application_ids` 一次性查回，比循环单个查更高效（最多 100 个/页）
4. **关联 Apply**：`application_id` 可与 `mplus apply applications batch-show --ids` 的返回对应，组合查询项目申请材料 + 融资信息

## 参考

- [mplus-admission](../SKILL.md) — admission 领域概览
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
- [admission-startup-projects-list](admission-startup-projects-list.md) — 创业项目列表
