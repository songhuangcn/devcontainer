# apply applications list

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

分页检索申请表列表，按提交时间倒序排列，支持关键词搜索、批次/轮次/状态筛选、评分和标签筛选等多维度过滤。每条申请包含完整的创始团队信息（`founders`，含手机号、出生日期、籍贯等）和问答分组数据（`answer_sections`）。

对应命令：`mplus apply applications list`（内部调用 `GET /apply/open_api/v2/applications`，通过 API Gateway）。

## 命令示例

```bash
# 获取所有申请（默认第 1 页，每页 20 条）
mplus apply applications list --json

# 关键词搜索
mplus apply applications list --q "AI" --json

# 按批次过滤（批次 ID，用 batches list 获取）
mplus apply applications list --batch 15 --json

# 按审阅轮次和状态过滤（需要 filter_by_stage_and_status 权限）
mplus apply applications list --application_stage_key first_review --decision_status pending --json

# 按提交时间范围过滤
mplus apply applications list --submitted_at_start 2026-01-01 --submitted_at_end 2026-06-30 --json

# 查看我在一面打了"y"（同意）的申请
mplus apply applications list --rating first_review:y --json

# 查看指定用户的所有评分记录（需要 filter_by_stage_and_status 权限）
mplus apply applications list --rating_user_id 42 --json

# 分页
mplus apply applications list --page 2 --page_size 50 --json

# 组合过滤
mplus apply applications list --batch 15 --q "区块链" --page 1 --page_size 20 --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--q <value>` | 否 | string | 关键词搜索（项目名、申请者、答案等） |
| `--batch <value>` | 否 | string | 批次 ID（整数字符串，从 `batches list` 获取） |
| `--application_stage_key <value>` | 否 | string | 审阅轮次：`first_review` / `second_review` / `interview`。⚠️ 需 `filter_by_stage_and_status` 权限 |
| `--decision_status <value>` | 否 | string | 审阅结果：`pending` / `accepted` / `rejected`。⚠️ 需 `filter_by_stage_and_status` 权限 |
| `--status <value>` | 否 | string | 申请状态：`draft` / `submitted`。⚠️ 需 `filter_by_stage_and_status` 权限 |
| `--category <value>` | 否 | string | 业务类别 key |
| `--company_category_key <value>` | 否 | string | 申请类别 key |
| `--rating <value>` | 否 | string | 我的评分，格式 `stage_key:rating_key`，如 `first_review:y` |
| `--rating_user_id <value>` | 否 | string | 评分人用户 ID。⚠️ 需 `filter_by_stage_and_status` 权限 |
| `--tag_search <value>` | 否 | string | 标签搜索 |
| `--investment <value>` | 否 | string | 融资历史筛选 |
| `--career_stage <value>` | 否 | string | 团队画像筛选 |
| `--submitted_at_start <value>` | 否 | string | 提交开始时间（YYYY-MM-DD） |
| `--submitted_at_end <value>` | 否 | string | 提交结束时间（YYYY-MM-DD） |
| `--page <value>` | 否 | string | 页码，默认 1 |
| `--page_size <value>` | 否 | string | 每页条数，默认 20，上限 100 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **权限**：需要 `apply:applications:read:all`；轮次/状态/评分人相关筛选参数额外需要 `apply:applications:filter_by_stage_and_status`。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "total": 500,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "1001",
      "user_id": "4567",
      "product_name": "智能制造项目",
      "company_name": "某某科技",
      "name": "张三",
      "application_introducer_name": "李四",
      "submitted_at": "2026-03-15 10:30",
      "stage_name": "second_review",
      "decision_status": "pending",
      "product_introduction": "我们正在...",
      "application_status": "submitted",
      "first_review": "2 maybe",
      "second_review": null,
      "interview": null,
      "founders": [
        {
          "id": "789",
          "name": "张三",
          "phone": "13800138000",
          "phone_country_code": "86",
          "email": "zhangsan@example.com",
          "wechat_id": "zhangsan_wx",
          "date_of_birth": "1995-06-15",
          "hometown": "上海",
          "answers": []
        }
      ],
      "answer_sections": [
        {
          "category": "项目信息",
          "answers": [
            { "question": "产品简介", "answer": "我们正在..." }
          ]
        }
      ]
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 申请 ID（字符串，传给 `batch-show --ids` 时用此值） |
| `user_id` | string | 申请者用户 ID（字符串，传给 `batch-show --user_ids` 时用此值） |
| `product_name` | string | 项目名称 |
| `company_name` | string | 公司名称 |
| `name` | string | 申请者姓名 |
| `submitted_at` | string | 提交时间（格式 `YYYY-MM-DD HH:MM`） |
| `stage_name` | string | 当前阶段（`first_review`/`second_review`/`interview`/`draft`） |
| `decision_status` | string | 当前轮次审阅结果（`pending`/`accepted`/`rejected`） |
| `first_review` | string\|null | 一面结果摘要（如 `2 maybe`），无权限时为 null |
| `second_review` | string\|null | 二面结果摘要，无权限时为 null |
| `interview` | string\|null | 面试摘要，无权限时为 null |
| `founders` | array | 创始团队列表，每位创始人含联系方式和创始人问答 |
| `founders[].id` | string | 创始人记录 ID |
| `founders[].name` | string | 创始人姓名 |
| `founders[].phone` | string | 手机号（仅数字，不含区号） |
| `founders[].phone_country_code` | string\|null | 国家区号（如 `86`），未填为 null |
| `founders[].email` | string | 邮箱 |
| `founders[].wechat_id` | string | 微信号 |
| `founders[].date_of_birth` | string\|null | 出生日期（`YYYY-MM-DD`），未填为 null |
| `founders[].hometown` | string\|null | 籍贯，未填为 null |
| `founders[].answers` | array | 该创始人的创始人类问题答案 |
| `answer_sections` | array | 申请表问答，按问题分类分组（不含创始团队分类） |
| `answer_sections[].category` | string | 问题分类名称 |
| `answer_sections[].answers` | array | 该分类下的问答列表（含未作答题目，answer 为空） |

## AI 使用建议

1. **要读申请全文**：用 `applications batch-show --ids <id>` 获取 Markdown；list 只有摘要信息
2. **批次 ID 先获取**：`--batch` 参数传的是整数 ID（不是批次名称），需先用 `batches list` 获取
3. **权限不足时筛选静默失效**：缺少 `filter_by_stage_and_status` 时，`application_stage_key`、`decision_status`、`status`、`rating_user_id` 参数被忽略，不会报错
4. **翻页判断**：`page * page_size < total` 时还有更多数据

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-batches-list](apply-batches-list.md) — 获取批次 ID
- [apply-applications-batch-show](apply-applications-batch-show.md) — 批量获取申请表详情（Markdown）
