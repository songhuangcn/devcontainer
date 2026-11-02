# build wechat_activities / wechat_activity_signups

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

管理微信小程序活动（对应 build 后台「微信小程序 → 活动」），以及审核活动报名申请（对应后台「审核活动申请」页）。典型场景：产品日嘉宾初筛自动化——拉取报名记录 → 逐条判断 → 写备注 → 高置信度的执行通过/拒绝 → 明确拒绝的确认锁定；信息不足的只写备注留给人工。

对应命令：
- `mplus build wechat_activities list`（`GET /build/open_api/v2/wechat_activities`）
- `mplus build wechat_activities show <id>`（`GET /build/open_api/v2/wechat_activities/{id}`）
- `mplus build wechat_activities create`（`POST /build/open_api/v2/wechat_activities`）
- `mplus build wechat_activities update <id>`（`PATCH /build/open_api/v2/wechat_activities/{id}`）
- `mplus build wechat_activities signups <id>`（`GET /build/open_api/v2/wechat_activities/{id}/signups`）
- `mplus build wechat_activity_signups show <id>`（`GET /build/open_api/v2/wechat_activity_signups/{id}`）
- `mplus build wechat_activity_signups accept <id>`（`POST .../accept`）
- `mplus build wechat_activity_signups reject <id>`（`POST .../reject`）
- `mplus build wechat_activity_signups reset <id>`（`POST .../reset`，把通过/拒绝重置为审核中）
- `mplus build wechat_activity_signups confirm <id>`（`POST .../confirm`）
- `mplus build wechat_activity_signups remark <id> --remark <文本>`（`PATCH .../remark`）
- `mplus build wechat_startups list <activityId>` / `show <id>` / `create <activityId>` / `update <id>` / `delete <id>`（活动里的「项目」增删改查）

全部命令需要 `accelerator:wechat_activities:manage` 权限（build 管理员默认拥有）。

## 命令示例

```bash
# 活动列表（外部活动，含报名总数 signups_count）
mplus build wechat_activities list --tab external --json

# 新建活动
mplus build wechat_activities create --title "2026 秋季路演日" --need_signup true --sort 110 --roles wechat_investor --json

# 编辑活动（只更新传入的字段）
mplus build wechat_activities update 30 --location "上海" --allow_signup false --json

# 拉取活动 30 的待审核报名（默认 20 条/页）
mplus build wechat_activities signups 30 --status pending --page 1 --json

# 按机构类型 + VIP 筛选
mplus build wechat_activities signups 30 --institution "产业资本" --vip_svip vip --json

# 查看单条申请详情（含该申请人在其他活动的历史申请 history）
mplus build wechat_activity_signups show 46462 --json

# 初筛流程：先写备注，再操作状态
mplus build wechat_activity_signups remark 46462 --remark "AI初筛：建议通过。机构类型：CVC。判断依据：……"
mplus build wechat_activity_signups accept 46462
# 明确拒绝 = 拒绝 + 确认两步
mplus build wechat_activity_signups reject 46463
mplus build wechat_activity_signups confirm 46463
# 撤回误操作的通过/拒绝（确认之前都可以）
mplus build wechat_activity_signups reset 46463
```

## 参数

### wechat_activities list

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--tab <value>` | 否 | enum | `external` 外部活动 / `founder` 校友活动 / `all` 全部（默认） |
| `--page` / `--page_size` | 否 | int | 分页，默认 1 / 20，page_size 上限 100 |

### wechat_activities create / update —— 字段填写指南

均为 `--字段 <value>`，布尔传 `true`/`false`。每个字段的完整业务语义以 OpenAPI（Apifox build 目录）为准，下面是填写时必须知道的联动关系：

**基础文案（面向不同状态的用户，别混用）**

| 字段 | 谁能看到 | 说明 |
|------|---------|------|
| `title` / `description` | 所有能看到活动的人 | 小程序「全部活动」列表卡片的标题和简短说明 |
| `content` | **还没通过**申请的用户 | 报名表单上方的补充文案（如「通过后将短信/邮件通知，建议用公司邮箱注册」） |
| `start_time` / `end_time` / `location` / `meeting_link` | **通过并确认**的用户（等待页） | 对未通过者保密；end_time 过期 = 活动结束 |
| `main_event_title` / `main_event_description` | 所有登录用户 | 「正在发生」Tab 大卡片专用文案，与 title/description 完全独立 |

**关键开关**

- `need_signup`：true = 要申请且审核通过才能看内容；false = 直接看项目列表。产品日/路演日都是 true。
- `is_main_event`：「正在发生」Tab（小程序第一屏）。**全局只能有一个**，设 true 自动取消其他活动的标记；且**不受 roles 限制**，谁都能看到。
- `waiting_page_opening`：等待页开关。开着时通过+确认的用户只看到带签到二维码的等待页；活动当天开场前把它改成 false 即"放闸"看项目列表。
- `display_startups_for_common` / `display_startups_for_vip`：等待页开着时的例外通道——前者=所有人免签到可看项目，后者=仅 VIP/SVIP 免签到可看。前提都是"通过+确认+等待页开启"。
- `founder_view_startup`：让本届项目创始人跳过等待页预览自己项目。
- `hidden`：整个活动在小程序隐身。`allow_signup`：false = 暂停接新报名。
- `allow_like`：项目点赞按钮（还需用户是投资人角色才显示）。

**其他**

- `--roles`：可见角色，逗号分隔（`wechat_investor` 投资人 / `wechat_founder` 校友 / `wechat_entrepreneur` 外部创业者 / `wechat_staff` 工作人员 / `wechat_enterprise_user` 企业客户）。不传 = 不修改（create 默认所有角色可见）；update 整体替换，传空字符串 = 改回所有角色可见。只影响「全部活动」列表，不影响「正在发生」。
- `sort`：数字越大越靠前；不填按创建时间新的在前。
- `custom_text`（+ `custom_text_navigate_to_activity_id`）：填了后「审核中」「拒绝」状态页会显示这段文字，可点击跳转到指定活动。
- `activity_type`：定制跳转，格式 `#小程序<shortlink>` 或 `#腾讯会议：xxx-xxx-xxx`，一般活动留空。
- `feishu_base_url`（校友签到）/ `feishu_base_url_for_vip`（VIP/非小程序人员签到）：飞书多维表格 URL，**必须带 table 参数**（指定数据表）。
- `allow_founder_access` / `health_promise`：已弃用/停用，不要填。
- **API 不覆盖**：内容图（通过后展示的大图，存在时替代项目列表）和会议资料（结束后展示的富文本）要去 build 后台补充。

**新建一场典型「产品日/路演日」的参考配置**

```bash
mplus build wechat_activities create \
  --title "2026年秋季路演日" \
  --description "点击报名参加路演日" \
  --content "具体时间、地点将在申请通过后通过短信/邮件通知，建议使用公司邮箱注册" \
  --need_signup true --allow_signup true --waiting_page_opening true \
  --sort 110 --onsite true --json
# 时间地点临近活动再 update（对未通过者保密，不怕提前填）；
# 活动当天开场前：mplus build wechat_activities update <id> --waiting_page_opening false
```

### wechat_activities signups <id>（审核列表筛选，AND 叠加）

| 参数 | 说明 |
|------|------|
| `--status` | `pending` / `accepted` / `rejected`（三者均指**还未确认**）/ `accepted_and_confirmed` / `rejected_and_confirmed` |
| `--second_status` | 申诉状态：`pending` / `accepted` / `rejected` |
| `--institution` / `--currency` / `--job_title` | 机构类型 / 币种 / 职位（精确匹配） |
| `--company_size` | `small_medium`(<500人) / `large`(500-1000人) / `super_large`(>1000人) |
| `--signup_type` | `investor` / `founder` / `entrepreneur` / `enterprise_user` |
| `--vip_svip` | `vip` / `svip` |
| `--white_and_blacklist` | `whitelist` / `blacklist` |
| `--option_id` / `--batch_id` | 报名选项 id / 批次 id |
| `--checked_in` | `true` 已签到 / `false` 未签到 |
| `--ids` | 按申请 id 列表查询（逗号分隔），传此参数时忽略其他筛选 |
| `--q` | 搜索姓名/邮箱/手机/公司/职位/所在地 |
| `--order` | `created_at_desc`（默认）/ `created_at_asc` |

### wechat_activity_signups remark

| 参数 | 必填 | 说明 |
|------|------|------|
| `--remark <value>` | 是 | 备注内容，整体覆盖旧值；空字符串清空。备注挂在**申请人**上，跨活动共享 |

### wechat_startups（活动里的项目）

项目 = 小程序活动里展示的一条条内容（如路演日里的各家公司），对应后台活动编辑页「项目」区块。

| 参数 | 说明 |
|------|------|
| `--title` | 项目标题（create 必填） |
| `--description` | 项目描述 |
| `--custom_id` | 自定义 id（整数）：兼做排序（小的在前，空排最后）与对外标识，同一活动内唯一（重复 422） |
| `--video_url` / `--video_poster_url` | 介绍视频（.mp4）与海报（.jpg）的 S3 链接，路演日结束后填入供小程序回看 |
| `--company_id` | 关联公司 id（关联后仅该公司创始人能编辑此项目的一页纸）；update 传空字符串 `--company_id ""` 解除关联 |

```bash
# 在活动 30 里新建项目并关联公司 123
mplus build wechat_startups create 30 --title "鳄梨科技" --description "视频结构化检索" --custom_id 10 --company_id 123 --json

# 列表 / 编辑 / 解除公司关联 / 删除
mplus build wechat_startups list 30 --json
mplus build wechat_startups update 456 --video_url "https://x.amazonaws.com.cn/xxx.mp4" --video_poster_url "https://x.amazonaws.com.cn/xxx.jpg"
mplus build wechat_startups update 456 --company_id ""
mplus build wechat_startups delete 456
```

内容图片上传不在 API 范围（后台操作）。返回字段含 `company {id,name}`、`likes_count`（点赞数）、`content_as_image`（只读）。

## 返回字段（申请）

```json
{
  "id": 46462,
  "wechat_activity_id": 30,
  "user_id": 12345,
  "status": "pending",
  "second_status": null,
  "appeal_content": null,
  "confirmed_at": null,
  "checked_in_at": null,
  "operator": null,
  "option": null,
  "answers": [
    { "question_id": 1372, "question": "咱们企业/单位正在AI方向寻求什么样的合作？", "required": true, "value": "ai infra投资" }
  ],
  "applicant": {
    "name": "张三",
    "signup_type": "investor",
    "company": "某某资本",
    "institution": "产业资本",
    "job_title": "投资总监",
    "currency": "CNY",
    "company_size": null,
    "location": "上海",
    "phone": "138…",
    "email": "…",
    "vip": false,
    "svip": false,
    "whitelist": false,
    "blacklist": false,
    "remark": null,
    "business_card_url": null
  },
  "created_at": "2026-07-01T02:00:00Z",
  "updated_at": "2026-07-01T02:00:00Z"
}
```

`wechat_activity_signups show` 额外返回 `history`（该申请人在其他活动的历史申请，含 activity_title / status / confirmed_at / checked_in_at）。

`answers` 是活动**动态配置**的申请问题的回答（每个活动问题不同，不是固定字段），按问题 sort 降序；问题定义可用 `mplus build wechat_activities show <activityId>` 的 `questions` 字段查看，二者用 question_id 对应。初筛判断时 answers 通常是最重要的输入之一。

## 审核语义与注意事项

1. 审核两步走：accept/reject 可反复改判（也可用 reset 改回审核中）；confirm 写入 `confirmed_at` 锁定，之后不可再改（409），并会给申请人发微信通知，不可撤销。
2. pending 的申请不能 confirm（409）；已确认的不能重复 confirm（409）。
3. accept/reject 会把当前账号记录为 `operator`——Agent 自动初筛请用专门的服务账号登录，方便后台区分人工/Agent 操作。
4. VIP/白名单用户报名会被系统自动置为通过、黑名单自动拒绝（此时 `operator` 为 null）；对这类用户 reset 后也会被立即自动改回，不会停留在审核中。
5. `phone` / `email` 原样返回，写入外部文档前自行脱敏。

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `403 forbidden` | 缺少 `accelerator:wechat_activities:manage` 权限 | 确认账号是 build 管理员，或给角色配置该权限 |
| `409 conflict` | 申请已确认（锁定）后再改状态；或 confirm 了 pending / 已确认的申请 | 已锁定的结果不可修改 |
| `422 validation_error` | 枚举参数取值非法（如 `--vip_svip xxx`）或 roles 含非法角色 | 按上表取值 |
| `400 bad_request` | create 缺少 `--title` | 补上必填参数 |
