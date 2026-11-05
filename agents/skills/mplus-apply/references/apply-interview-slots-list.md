# apply interview-slots list

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

分页获取面试安排（interview slot）列表，支持按日期区间、申请、类别、预约状态和标签筛选。

对应命令：`mplus apply interview-slots list`（内部调用 `GET /apply/open_api/v2/interview_slots`，通过 API Gateway）。

## 命令示例

```bash
# 获取面试安排列表（默认第 1 页，每页 20 条）
mplus apply interview-slots list --json

# 查某段时间的面试安排
mplus apply interview-slots list --start_date 2026-07-01 --end_date 2026-07-31 --json

# 查还可以预约的空闲 slot
mplus apply interview-slots list --available true --json

# 查已被预约的 slot（含申请信息）
mplus apply interview-slots list --booked true --page_size 50 --json

# 查某个申请预约的面试
mplus apply interview-slots list --application_id 95747 --json

# 只查算力项目的面试
mplus apply interview-slots list --category gpu_resource --json

# 只返回需要的字段，减少输出体积
mplus apply interview-slots list \
  --output_schema '{"interview_slot":["id","time","location","interviewer_name","booked","available"]}' --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--start_date <date>` | 否 | string | 无 | 面试开始日期（YYYY-MM-DD），按 `time` 字段过滤 |
| `--end_date <date>` | 否 | string | 无 | 面试结束日期（YYYY-MM-DD） |
| `--application_id <id>` | 否 | string | 无 | 申请 ID，查该申请预约的面试 |
| `--category <value>` | 否 | string | 无 | 申请类别：`normal`（普通）/ `gpu_resource`（算力资源） |
| `--available <bool>` | 否 | string | 无 | 是否可预约。`true`/`1`：`application_id` 为空**且**面试尚未开始；`false`/`0`：不可预约 |
| `--booked <bool>` | 否 | string | 无 | 是否已预约。`true`/`1`：`application_id` 不为空；`false`/`0`：`application_id` 为空 |
| `--tag <value>` | 否 | string | 无 | 面试 slot 标签 |
| `--output_schema <json>` | 否 | string | 全量字段 | 稀疏字段集，格式 `{"interview_slot": ["id", "time", ...]}` |
| `--page <number>` | 否 | string | `"1"` | 页码，从 1 开始 |
| `--page_size <number>` | 否 | string | `"20"` | 每页数量，上限 100 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> **权限**：需要 `apply:interview_slots:read` 权限。

> **`available` 与 `booked` 的区别**：`booked=false` 只表示没人预约，可能是已经过去的历史 slot；`available=true` 额外要求面试时间在未来。找"还能约的时段"用 `--available true`。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "total": 8060,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "8241",
      "time": "2026-07-29T13:40:00+08:00",
      "location": "深圳，G2",
      "notes": "地址：深圳市宝安区西乡街道……",
      "tag": "",
      "method": "offline",
      "method_label": "线下",
      "preferred_method": "offline",
      "preferred_method_label": "线下",
      "slot_duration_minutes": 20,
      "application_id": "95747",
      "creator_id": "324345",
      "creator_name": "冯乐萌",
      "interviewer_id": null,
      "interviewer_name": null,
      "booked": true,
      "available": false,
      "application": {
        "id": "95747",
        "batch_id": "16",
        "batch_name": "2026春季创业营",
        "user_id": "428854",
        "user_name": "汤嘉斌",
        "category": "gpu_resource",
        "product_name": "AI-Researcher",
        "company_name": null,
        "product_introduction": "全链路的 AI Co-Scientist",
        "tags": ["算力项目"]
      },
      "created_at": "2025-11-20T07:22:58Z",
      "updated_at": "2025-11-26T03:11:02Z"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `total` | number | 符合条件的总记录数 |
| `page` / `page_size` | number | 当前页码 / 每页数量 |
| `items[].id` | string | 面试 slot ID（字符串整数，传给 `get` 用此值） |
| `items[].time` | string | 面试时间（ISO 8601，带东八区时区） |
| `items[].location` | string | 面试地点 |
| `items[].notes` | string | 备注 |
| `items[].tag` | string | 面试 slot 标签 |
| `items[].method` / `method_label` | string | 会面方式 key / 中文名（如 `offline` / 线下） |
| `items[].preferred_method` / `preferred_method_label` | string | 申请方偏好的面试方式 key / 中文名 |
| `items[].slot_duration_minutes` | number | 面试时长（分钟） |
| `items[].application_id` | string | 已预约的申请 ID；为 `null` 表示无人预约 |
| `items[].creator_id` / `creator_name` | string | 创建人 ID / 姓名 |
| `items[].interviewer_id` / `interviewer_name` | string | 面试官 ID / 姓名 |
| `items[].booked` | boolean | 是否已被预约 |
| `items[].available` | boolean | 是否可预约（未被预约且面试未开始） |
| `items[].application` | object | 已预约申请的摘要信息，未预约时为 `null` |
| `items[].application.batch_id` / `batch_name` | string | 批次 ID / 名称 |
| `items[].application.user_id` / `user_name` | string | 申请人 ID / 姓名 |
| `items[].application.category` | string | 申请类别（`normal` / `gpu_resource`） |
| `items[].application.product_name` | string | 项目名称 |
| `items[].application.company_name` | string | 公司名称 |
| `items[].application.product_introduction` | string | 项目一句话介绍 |
| `items[].application.tags` | array | 申请标签 |
| `items[].created_at` / `updated_at` | string | 创建 / 更新时间（ISO 8601 UTC） |

## AI 使用建议

1. **先窄后宽**：总量有 8000+ 条历史 slot，直接 `list` 会翻到 2020 年的数据。查当期安排务必带 `--start_date` / `--end_date`。
2. **控制输出体积**：默认返回内嵌的 `application` 对象，字段很多。做统计时用 `--output_schema` 只取需要的字段。
3. **排期场景**：找空档用 `--available true`；核对某个项目约到哪天用 `--application_id`。
4. **交叉引用**：`application.id` 可以直接传给 `mplus apply applications batch-show --ids <id>` 拿申请全文。

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-interview-slots-get](apply-interview-slots-get.md) — 面试安排详情
- [apply-applications-batch-show](apply-applications-batch-show.md) — 按申请 ID 拿申请全文
