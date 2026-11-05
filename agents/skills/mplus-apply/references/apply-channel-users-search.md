# apply channel-users search

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

搜索企业微信渠道用户汇总（`Soc::ChannelUser`），与后台「微信用户汇总」页面共用同一套筛选逻辑。支持关键词模糊搜索、企微标签/负责员工/触达人/申请进度等多维筛选，以及自定义排序。

与 `reports soc-channel-users` 的区别：reports 接口做时间段统计/明细导出（有 start_date/end_date）；本接口侧重灵活的页面级搜索（filters + sort），不限制时间区间。

对应命令：`mplus apply channel-users search`（内部调用 `GET /apply/open_api/v2/channel_users/search`，通过 API Gateway）。

**权限要求：** `apply:channel_users:read`

## 命令示例

```bash
# 关键词搜索（模糊匹配姓名/昵称/手机/邮箱/unionid 等）
mplus apply channel-users search --q "张三" --json

# 按渠道类型筛选（企微来源）
mplus apply channel-users search --filters '{"0|eq|channel_type|qywechat":""}' --json

# 按企微标签筛选
mplus apply channel-users search --filters '{"0|includes|qy_tag_names|一级渠道":""}' --json

# 按负责员工筛选
mplus apply channel-users search --filters '{"0|eq|follow_user_names|张三":""}' --json

# 按申请进度筛选（已提交，指定批次）
mplus apply channel-users search --filters '{"0|eq|application_progress|submitted|123":""}' --json

# 组合条件：企微来源 AND 手机号包含 138
mplus apply channel-users search --filters '{"0|eq|channel_type|qywechat":"","0|cont|phone|138":""}' --json

# 跨组 OR：一级渠道 OR 二级渠道（不同 group 取 OR）
mplus apply channel-users search --filters '{"g1|includes|qy_tag_names|一级渠道":"","g2|includes|qy_tag_names|二级渠道":""}' --json

# 自定义排序（按更新时间降序）
mplus apply channel-users search --sort '{"soc_channel_users.updated_at":"desc"}' --json

# 只返回部分字段（稀疏字段集）
mplus apply channel-users search --q "李" --output_schema '{"soc_channel_user":["id","name","phone"]}' --json

# 分页
mplus apply channel-users search --q "李" --page 2 --page-size 50 --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--q <value>` | 否 | string | 关键词，模糊匹配 name / nickname / phone / email / channel_type / unionid / external_userid / openid |
| `--filters <value>` | 否 | JSON string | 高级筛选条件，详见下方「filters 格式」 |
| `--sort <value>` | 否 | JSON string | 排序条件，如 `{"soc_channel_users.updated_at":"desc"}` |
| `--output_schema <value>` | 否 | JSON string | 稀疏字段集（sparse fieldset）。格式 `{"soc_channel_user": ["id", ...]}`（key 固定为 `soc_channel_user`，value 为字段名数组）。不传则返回全量字段 |
| `--page <value>` | 否 | integer | 页码，默认 1 |
| `--page-size <value>` | 否 | integer | 每页条数，默认 20，上限 100 |
| `--profile <name>` | 否 | string | 临时使用指定 profile，不改 current_profile |
| `--json` | 否 | flag | 以 JSON 格式输出，AI 调用必须加此参数 |

## filters 格式

`filters` 是一个 JSON 对象，每个 key 格式为：

```
"<group>|<operator>|<field>|<value>[|<batch_id>]"
```

- **group**：同一 group 内条件取 AND，不同 group 之间取 OR
- **operator**：运算符，见下表
- **field**：筛选字段，见下表
- **value**：留空字符串 `""`（条件在 key 里）

### 常用字段

| 字段 | 说明 | 常用 operator |
|------|------|--------------|
| `follow_user_names` | 负责员工（添加过该用户的托管账号） | eq / not_eq / in / not_in / null / not_null |
| `contact_user_id` | 触达人 ID | eq |
| `add_juzi_follow_user_earliest_name` | 最早添加的托管账号 | eq / null / not_null |
| `channel_type` | 来源类型：`apply` / `qywechat` / `wechat_service` | eq |
| `phone` | 手机号 | cont / eq / blank / present |
| `qy_tag_names` | 企微标签（模糊匹配） | includes / cont |
| `contact_tags` | 人脉标签（精确数组包含） | contains / contains_any |
| `add_juzi_follow_user_earliest_time` | 最早添加托管账号时间 | lt / gteq / date_eq / date_range / null / not_null |
| `application_progress` | 申请进度：`not_register` / `registered` / `not_submitted` / `submitted`，可附加第5段 `batch_id` | eq |

## 返回字段

```json
{
  "total": 128,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "456789",
      "channel_type": "qywechat",
      "unionid": "xxx",
      "openid": "yyy",
      "external_userid": "wmXxx",
      "name": "张三",
      "nickname": "小张",
      "phone": "13800138000",
      "email": "zhangsan@example.com",
      "gender": "male",
      "qy_tag_names": "一级渠道,重点跟进",
      "contact_tags_text": "VIP,投资人",
      "early_follower": "托管账号A",
      "created_at": "2026-01-15T08:00:00Z",
      "follow_user_names": "托管账号A,托管账号B",
      "custom_source": "朋友推荐"
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `total` | integer | 总记录数 |
| `page` | integer | 当前页码 |
| `page_size` | integer | 每页条数 |
| `items` | array | 当前页用户列表 |
| `items[].id` | string | 记录 ID |
| `items[].channel_type` | string | 渠道类型（qywechat / apply / wechat_service） |
| `items[].unionid` | string \| null | 微信 unionid |
| `items[].external_userid` | string \| null | 企微外部联系人 ID |
| `items[].name` | string \| null | 姓名 |
| `items[].phone` | string \| null | 手机号 |
| `items[].qy_tag_names` | string | 企微标签（CSV 格式） |
| `items[].contact_tags_text` | string \| null | 人脉标签文本 |
| `items[].early_follower` | string \| null | 最早添加的托管账号 |
| `items[].follow_user_names` | string \| null | 添加过的托管账号列表 |

## 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|---------|
| `403 Forbidden` | 缺少 `apply:channel_users:read` 权限 | 用 `mplus whoami --json` 确认账号权限 |
| `400 Bad Request` | filters JSON 格式非法 | 检查 JSON 转义，确保 key 格式正确 |
| 结果为空但确有数据 | filters 条件过严或 group 逻辑错误 | 去掉部分条件缩小范围排查 |

## AI 使用建议

1. **与 contacts search 的区别**：本命令针对企微/微信渠道用户（`Soc::ChannelUser`），适合查「通过企微添加的用户」；`contacts search` 针对通用人脉，适合查「线索/CRM 数据」
2. **与 reports soc-channel-users 的区别**：本命令做灵活搜索，reports 做时段统计汇总
3. **filters 多条件**：同 group 的条件自动 AND，不同 group 自动 OR
4. **企微标签搜索**：`qy_tag_names` 用 `includes` operator 做模糊匹配，不需要完整标签名
5. **申请进度 + 批次**：`application_progress` 可带第5段 batch_id，如 `"0|eq|application_progress|submitted|123":""`
6. **始终加 `--json`**：解析数据必须使用 JSON 格式

## 参考链接

- 权限映射：`apply:channel_users:read`
- 上游 API：`GET /open_api/v2/channel_users/search`（通过 mp-gateway 转发）
