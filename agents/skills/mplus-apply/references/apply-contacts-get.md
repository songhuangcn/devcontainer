# apply contacts get

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取单条人脉的完整详情。

对应命令：`mplus apply contacts get <id>`（内部调用 `GET /apply/open_api/v2/contacts/{id}`，通过 API Gateway）。

## 命令示例

```bash
# 获取人脉 ID 为 123 的详情
mplus apply contacts get 123 --json

# 使用指定 profile
mplus apply contacts get 123 --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | string | 人脉 ID（字符串整数） |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **权限**：`apply:contacts:read:all`（全部人脉）或 `apply:contacts:read:self`（仅自己名下）。
> **敏感字段**：管理员/合伙人可见完整手机号、邮箱、微信；其他用户手机号显示为 `***1234`，邮箱和微信显示为 `******`。

## 主要返回字段

响应为顶层人脉对象（直接返回，无 `data` 包裹），`id` 为字符串。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 人脉 ID（字符串） |
| `name` | string | 姓名 |
| `phone` / `phone_2` / `phone_3` | string | 手机号 1/2/3 |
| `email` ~ `email_4` | string | 邮箱 1~4 |
| `wechat` | string | 微信号 |
| `wechat_unionid` | string | 微信 UnionID |
| `qq` | string | QQ 号 |
| `organization` | string | 所在组织/公司 |
| `project` | string | 项目名称 |
| `introduction` | string | 个人简介 |
| `field` | string | 研究方向/专业领域 |
| `category` | string | 身份画像（枚举 key） |
| `communication` | string | 接触状态（枚举 key） |
| `apply_intent` | string | 申请意愿（枚举 key） |
| `entrepreneurial_intent` | string | 创业意愿（枚举 key） |
| `quality_score` | number | 质量评分 |
| `willingness_score` | number | 意愿评分 |
| `tags` | array | 标签列表 |
| `clue_tags` | array | 线索标签列表 |
| `s_channel` / `latest_s_channel` | string | 原始/最新渠道大类 |
| `s_product` / `latest_s_product` | string | 原始/最新来源产品 |
| `utm_source` | string | 原始一级渠道 |
| `utm_campaign` | string | 原始二级渠道 |
| `utm_content` | string | 原始三级渠道 |
| `s_referral` | string | 分享人 |
| `clue_user_id` / `clue_user_name` | string | 线索人 ID / 姓名 |
| `operator_id` / `operator_name` | string | 转化人 ID / 姓名 |
| `contact_user_id` / `contact_user_name` | string | 触达人 ID / 姓名 |
| `revisit_at` | string | 人工最新跟进时间 |
| `contact_at` | string | 首次触达时间 |
| `wechat_added_at` | string | 加微信时间 |
| `meeting_success` | string | 是否成功开会（枚举 key） |
| `application_progress` | string | 申请进度 |
| `applications_number` | number | 申请次数 |
| `submitted_at` | string | 申请提交时间 |
| `can_operate` | boolean | 是否有操作权限 |
| `application_ids` | array | 经 contact_relations 关联、且仍存在（未软删除）的申请 ID 列表（字符串）。无关联时为空数组 |
| `founder_ids` | array | 经 contact_relations 关联、且仍存在（未软删除）的创始人 ID 列表（字符串）。无关联时为空数组 |
| `created_at` | string | 录入时间（ISO 8601 UTC） |
| `updated_at` | string | 最后更新时间（ISO 8601 UTC） |

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-contacts-search](apply-contacts-search.md) — 搜索人脉（获取 ID）
- [apply-contacts-update](apply-contacts-update.md) — 更新人脉
