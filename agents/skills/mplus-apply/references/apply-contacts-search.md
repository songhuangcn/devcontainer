# apply contacts search

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

按关键词和高级筛选条件（filters）搜索人脉记录，支持复杂 AND/OR 组合过滤和排序。

对应命令：`mplus apply contacts search`（内部调用 `GET /apply/open_api/v2/contacts/search`，通过 API Gateway）。

## 命令示例

```bash
# 关键词搜索
mplus apply contacts search --q "张三" --json

# 高级筛选：身份画像=投资人
mplus apply contacts search --filters '{"g|eq|category|investor":""}' --json

# 高级筛选：身份画像=投资人 AND 标签包含 VIP
mplus apply contacts search --filters '{"g|eq|category|investor":"","g|contains|tags|VIP":""}' --json

# 跨组 OR：投资人 OR 教授
mplus apply contacts search --filters '{"g1|eq|category|investor":"","g2|eq|category|professor":""}' --json

# 日期范围过滤
mplus apply contacts search --filters '{"g|date_range|created_at|2026-01-01,2026-06-30":""}' --json

# 关键词 + 筛选 + 排序
mplus apply contacts search --q "AI" --filters '{"g|eq|category|researcher_founder":""}' --sort '{"field":"quality_score","order":"descend"}' --json

# 分页
mplus apply contacts search --q "李" --page 2 --page_size 50 --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--q <value>` | 否 | string | 搜索关键词，对姓名、项目、公司、邮箱、微信等做模糊匹配；纯数字时额外匹配手机号 |
| `--filters <value>` | 否 | JSON string | 高级筛选条件 JSON 字符串，详见下方「filters 格式」 |
| `--sort <value>` | 否 | JSON string | 排序条件 JSON 字符串，如 `{"field":"created_at","order":"descend"}` |
| `--page <value>` | 否 | string | 页码，默认 1 |
| `--page_size <value>` | 否 | string | 每页数量，默认 20，上限 100 |
| `--output_schema <value>` | 否 | JSON string | 稀疏字段集，只返回指定字段，格式 `{"contact": ["id", "phone", "category"]}`（key 固定为 `contact`）。不传则返回全量字段。**v0.5.3 起从 `--output-schema` 改名** |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **权限**：`apply:contacts:read:all`（全部人脉）或 `apply:contacts:read:self`（仅自己名下人脉）。

## filters 格式

`--filters` 接受 JSON 字符串，每个筛选条件是对象的一个 key，**value 固定为空字符串 `""`**。

**Key 格式**：`"<group>|<operator>|<field>|<value>"`

- **group**: 分组名，**同组 AND、不同组 OR**（最常用：所有条件都写 `g`，即全部 AND）
- **operator**: 运算符（见下表）
- **field**: 筛选字段（见下表）
- **value**: 取值（多值用英文逗号分隔；`null`/`not_null`/`true`/`false` 类运算符无需值留空）

### 常用运算符

| operator | 含义 | 适用 |
|----------|------|------|
| `eq` | 等于 | 字符串/数字/枚举 |
| `not_eq` | 不等于（含为空） | 同上 |
| `in` | 在列表中 | 同上（逗号分隔多值） |
| `not_in` | 不在列表中 | 同上 |
| `cont` | 模糊包含（ILIKE） | 字符串 |
| `null` / `not_null` | 为 NULL / 不为 NULL | 任意 |
| `true` / `false` | 为真 / 为假 | 布尔 |
| `gt` / `lt` / `gteq` / `lteq` | 大于/小于/大于等于/小于等于 | 数字/日期 |
| `date_range` | 日期范围（`起,止` 格式） | 日期 |
| `contains` | 数组包含某值 | 数组（如 tags） |
| `contains_any` | 数组包含任一 | 数组（逗号分隔） |
| `contains_all` | 数组包含全部 | 数组（逗号分隔） |

### 常用字段

| field | 类型 | 含义 |
|-------|------|------|
| `category` | 枚举 | 身份画像：`alumni`/`business_started`/`investor`/`professor`/`researcher_founder`/`student`/`tech_giants_employee`/`others` 等 |
| `communication` | 枚举 | 接触状态：`unaware`/`reaching`/`aware`/`success`/`finish` 等 |
| `apply_intent` | 枚举 | 申请意愿：`willing_to_apply`/`long_term_follow_up`/`explicit_rejection` 等 |
| `tags` | 数组 | 标签（用 `contains`/`contains_any` 系列） |
| `clue_tags` | 数组 | 线索标签：`young`/`not_young`/`technical`/`non_technical` |
| `s_channel` | 枚举 | 渠道大类：`ib`/`ob`/`ad`/`al`/`sj` 等 |
| `s_product` | 枚举 | 来源产品：`ba`/`ls`/`ss`/`gpu` 等 |
| `utm_source` | 枚举 | 一级渠道：`ob`/`gzh`/`xhs`/`zhihu` 等 |
| `quality_score` | 数字 | 质量评分（用 `gteq`/`lteq`/`eq`） |
| `created_at` | 日期 | 录入时间（用 `date_range`） |
| `wechat_added_at` | 日期 | 加微信时间 |
| `meeting_success` | 枚举 | 是否成功开会：`success`/`fail`/`second_time_meeting` |
| `clue_user_id` | number | 线索人用户 ID |
| `contact_user_id` | number | 触达人用户 ID |
| `application_progress` | 枚举 | 申请进度：`not_register`/`registered`/`not_submitted`/`submitted` |

### filters 示例

```bash
# 身份画像=投资人 且 录入时间在 2026 上半年 且 质量评分 >= 4
'{"g|eq|category|investor":"","g|date_range|created_at|2026-01-01,2026-06-30":"","g|gteq|quality_score|4":""}'

# 接触状态为「沟通说服中」
'{"g|eq|communication|aware":""}'

# 已成功开会（且标签包含 VIP 或 重点）
'{"g|eq|meeting_success|success":"","g1|contains|tags|VIP":"","g2|contains|tags|重点":""}'

# 已提交申请
'{"g|eq|application_progress|submitted":""}'
```

## 返回字段

```json
{
  "total": 200,
  "page": 1,
  "page_size": 20,
  "items": [
    {
      "id": "123",
      "name": "张三",
      "phone": "138****0000",
      "email": "zhangsan@example.com",
      "category": "researcher_founder",
      "communication": "aware",
      "quality_score": 4.5,
      "tags": ["VIP", "重点跟进"],
      "s_channel": "ib",
      "created_at": "2026-02-01T08:00:00Z",
      "application_ids": ["1001", "1002"],
      "founder_ids": ["50"],
      "...": "其余字段见 contacts get"
    }
  ]
}
```

- 顶层 `id` 为字符串
- 每条 item 的结构对应 `ContactWithRelations`：在人脉字段基础上额外含 `application_ids`（关联申请 ID 数组）和 `founder_ids`（关联创始人 ID 数组），均为字符串数组，无关联时为空数组
- 手机号/邮箱/微信：持 `read:all` 权限可见完整值，仅持 `read:self` 时显示为 `***1234` / `******`
- 完整字段列表见 [apply-contacts-get.md](apply-contacts-get.md)

## AI 使用建议

1. **filters JSON 必须是字符串**：在命令行中用单引号包裹整个 JSON，避免 shell 解析问题
2. **同组为 AND，不同组为 OR**：绝大多数情况下所有条件写同一个 group（如 `g`），即全部 AND
3. **枚举值用英文 key**：`category` 传 `investor` 不传 `投资人`
4. **未知字段静默忽略**：field 名拼错时不会报错，只是过滤无效

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-contacts-get](apply-contacts-get.md) — 获取完整人脉字段
- [apply-contacts-create](apply-contacts-create.md) — 新建人脉
- [apply-contacts-update](apply-contacts-update.md) — 更新人脉
