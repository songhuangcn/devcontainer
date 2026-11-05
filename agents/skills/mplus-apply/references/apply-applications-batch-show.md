# apply applications batch-show

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

按申请 ID 或申请者用户 ID 批量获取申请表详情，返回完整字段集：Markdown 全文、评审记录（evaluations）、创始团队信息（founders，含出生日期、手机区号、籍贯）、问答分组数据（answer_sections）。返回结构与 `applications list` 的列表项一致，额外补充 `markdown` 和 `evaluations`。

对应命令：`mplus apply applications batch-show`（内部调用 `GET /apply/open_api/v2/applications/batch_show`，通过 API Gateway）。

## 命令示例

```bash
# 按申请 ID 批量获取
mplus apply applications batch-show --ids 1001,1002,1003 --json

# 按申请者用户 ID 批量获取
mplus apply applications batch-show --ids "" --user_ids 4567,4568 --json
# 注意：--ids 与 --user_ids 至少传一个

# 同时传 ids 和 user_ids（取并集）
mplus apply applications batch-show --ids 1001 --user_ids 4568 --json

# 按关联的人脉 ID 反查其关联的申请
mplus apply applications batch-show --contact_ids 7,8,9 --json

# 使用指定 profile
mplus apply applications batch-show --ids 1001,1002 --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--ids <value>` | 否* | string | 申请 ID 列表，英文逗号分隔，每次最多 100 个，如 `1001,1002,1003` |
| `--user_ids <value>` | 否* | string | 申请者用户 ID 列表，英文逗号分隔，每次最多 100 个 |
| `--contact_ids <value>` | 否* | string | 关联的人脉 ID 列表，英文逗号分隔，每次最多 100 个；经 contact_relations 反查其关联的申请，如 `7,8,9` |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> \* `--ids`、`--user_ids`、`--contact_ids` 至少传一个，同时传时取并集，各自每次最多 100 个。
>
> **权限**：需要 `apply:applications:read:all`。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "applications": [
    {
      "id": "1001",
      "user_id": "4567",
      "product_name": "智能制造项目",
      "company_name": "某某科技",
      "name": "张三",
      "submitted_at": "2026-03-15 10:30",
      "stage_name": "second_review",
      "decision_status": "pending",
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
          "answers": [{ "question": "产品简介", "answer": "我们正在..." }]
        }
      ],
      "markdown": "# 申请表全文...\n\n## 项目简介\n...",
      "evaluations": [
        {
          "id": "201",
          "stage_key": "first_review",
          "rating_key": "y",
          "rating_human": "优秀",
          "rating_thing": "可行",
          "comment": "团队背景强...",
          "user_id": "42",
          "user_name": "李评委",
          "scored_at": "2026-03-20T08:00:00Z",
          "submitted": true
        }
      ],
      "error": null
    }
  ],
  "missing_ids": [],
  "missing_user_ids": []
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `applications[].id` | string | 申请 ID |
| `applications[].user_id` | string | 申请者用户 ID |
| `applications[].product_name` | string | 项目名称 |
| `applications[].company_name` | string | 公司名称 |
| `applications[].name` | string | 申请者姓名 |
| `applications[].submitted_at` | string | 提交时间（`YYYY-MM-DD HH:MM`） |
| `applications[].stage_name` | string | 当前阶段 |
| `applications[].decision_status` | string | 当前轮次审阅结果 |
| `applications[].founders` | array | 创始团队列表（含姓名、手机、区号、邮箱、微信、出生日期、籍贯、问答） |
| `applications[].answer_sections` | array | 问答分组数据（不含创始团队分类） |
| `applications[].markdown` | string\|null | 申请表 Markdown 全文，生成失败时为 null |
| `applications[].evaluations` | array | 所有评审记录（含各轮次、各评委） |
| `applications[].error` | string\|null | Markdown 生成失败时的错误说明，成功为 null |
| `missing_ids` | array | 请求了但未找到的申请 ID 列表 |
| `missing_user_ids` | array | 请求了但未找到的用户 ID 列表 |

### evaluations 字段结构

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 评价 ID |
| `stage_key` | string | 打分轮次（`first_review`/`second_review`/`interview`） |
| `rating_key` | string | 打分结果 key（如 `y`/`n`/`m` 等） |
| `rating_human` | string | 对「人」的打分（可读文案） |
| `rating_thing` | string | 对「事」的打分（可读文案） |
| `comment` | string | 评审备注 |
| `user_id` | string | 打分人 ID |
| `user_name` | string | 打分人姓名 |
| `scored_at` | string | 打分时间（ISO 8601 UTC） |
| `submitted` | boolean | 该评价是否已提交 |

## 注意事项

- 按 `user_ids` 查询时，一个用户可能有多份申请，返回条数可能多于传入的用户 ID 数
- 单条申请生成失败不影响其他申请，失败时对应 `error` 字段有说明
- `missing_ids` / `missing_user_ids` 中列出请求了但未找到的 ID

## AI 使用建议

1. **优先用此接口读申请内容**：而非自行翻页列表再逐条读取，`markdown` 字段即完整申请全文
2. **配合 list 使用**：先用 `applications list` 获取 `id` 或 `user_id`，再批量 batch-show
3. **单次 100 条上限**：超过 100 个 ID 需分批请求
4. **评审记录**：`evaluations` 包含所有轮次和评委，自行按 `stage_key` 过滤所需轮次

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-applications-list](apply-applications-list.md) — 获取申请 ID
