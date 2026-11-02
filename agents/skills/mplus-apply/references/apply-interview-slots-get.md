# apply interview-slots get

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取单条面试安排（interview slot）的完整详情。

对应命令：`mplus apply interview-slots get <id>`（内部调用 `GET /apply/open_api/v2/interview_slots/{id}`，通过 API Gateway）。

## 命令示例

```bash
# 获取 slot ID 为 8241 的面试安排详情
mplus apply interview-slots get 8241 --json

# 只取部分字段
mplus apply interview-slots get 8241 \
  --output_schema '{"interview_slot":["id","time","location","application"]}' --json

# 使用指定 profile
mplus apply interview-slots get 8241 --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | string | 面试 slot ID（字符串整数），从 `interview-slots list` 的 `items[].id` 获取 |
| `--output_schema <json>` | 否 | string | 稀疏字段集，格式 `{"interview_slot": ["id", "time", ...]}`，不传返回全量字段 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **权限**：需要 `apply:interview_slots:read` 权限。
> **ID 不存在**：命令输出 `错误：资源不存在` 并以退出码 1 结束。

## 返回字段

响应为顶层面试安排对象（直接返回，无 `data` 包裹），字段与 `interview-slots list` 的 `items[]` 元素完全一致：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 面试 slot ID |
| `time` | string | 面试时间（ISO 8601，带东八区时区） |
| `location` | string | 面试地点 |
| `notes` | string | 备注 |
| `tag` | string | 面试 slot 标签 |
| `method` / `method_label` | string | 会面方式 key / 中文名（如 `offline` / 线下） |
| `preferred_method` / `preferred_method_label` | string | 申请方偏好的面试方式 key / 中文名 |
| `slot_duration_minutes` | number | 面试时长（分钟） |
| `application_id` | string | 已预约的申请 ID；为 `null` 表示无人预约 |
| `creator_id` / `creator_name` | string | 创建人 ID / 姓名 |
| `interviewer_id` / `interviewer_name` | string | 面试官 ID / 姓名 |
| `booked` | boolean | 是否已被预约 |
| `available` | boolean | 是否可预约（未被预约且面试未开始） |
| `application` | object | 已预约申请的摘要（`id` / `batch_id` / `batch_name` / `user_id` / `user_name` / `category` / `product_name` / `company_name` / `product_introduction` / `tags`），未预约时为 `null` |
| `created_at` / `updated_at` | string | 创建 / 更新时间（ISO 8601 UTC） |

## AI 使用建议

1. **批量场景别用 get**：要看多条 slot 时直接用 `list` 加筛选参数，`list` 返回的字段和 `get` 一样全，不需要逐条 get。
2. **拿申请全文**：`application.id` 可以传给 `mplus apply applications batch-show --ids <id>`。

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-interview-slots-list](apply-interview-slots-list.md) — 面试安排列表（获取 ID）
