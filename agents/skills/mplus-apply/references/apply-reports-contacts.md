# apply reports contacts

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

获取手机号人脉统计数据，支持明细（detail）和计数（count）两种模式，支持按时间范围、渠道、来源等多维度过滤。

对应命令：`mplus apply reports contacts`（内部调用 `GET /apply/open_api/v2/reports/contacts`，通过 API Gateway）。

> **DS 报告聚合用法**：本命令是「线索来源周期对比报告」(DS 报告) 的数据源之一。CLI 只出原始计数，渠道归类（13 渠道）、跨源聚合（手机号+企微）、6 时段周期换算全部由 AI 按 [mplus-reports skill](../../../skills/mplus-reports/SKILL.md) 的规则完成——对每个区间调本命令的 `--mode count --group_by …` 再归类聚合。

## 命令示例

```bash
# 获取当期（默认）数据，明细模式
mplus apply reports contacts --json

# 自定义日期范围
mplus apply reports contacts --start_date 2026-01-13 --end_date 2026-06-15 --json

# 计数模式，按渠道大类分组
mplus apply reports contacts --start_date 2026-01-13 --end_date 2026-06-15 --mode count --group_by s_channel --json

# 按多个渠道大类过滤
mplus apply reports contacts --start_date 2026-01-13 --end_date 2026-06-15 --s_channel ib,al --json

# 仅有手机号
mplus apply reports contacts --start_date 2026-01-13 --end_date 2026-06-15 --has_phone true --json

# 分页
mplus apply reports contacts --start_date 2026-01-13 --end_date 2026-06-15 --page 2 --page_size 100 --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--start_date <value>` | 否 | string | 当期起始日 | 开始日期（YYYY-MM-DD）。当期：第一期 1/13～7/13，第二期 7/14～次年1/12 |
| `--end_date <value>` | 否 | string | 今天 | 结束日期（YYYY-MM-DD） |
| `--date_field <value>` | 否 | string | `created_at` | 过滤用时间字段：`created_at`/`revisit_at`/`contact_at`/`successful_contact_at`/`confirm_meeting_at`/`meeting_at` |
| `--output-schema <value>` | 否 | JSON string | — | 稀疏字段集，只返回明细对象的部分字段，格式 `{"contact": ["id", ...]}`（key 固定为 `contact`）。仅 `mode=detail` 生效 |
| `--mode <value>` | 否 | string | `detail` | 输出模式：`detail`（明细）或 `count`（计数统计） |
| `--group_by <value>` | 否 | string | — | 仅 `mode=count` 时生效，分组字段（CSV）：`s_channel`/`s_product`/`utm_source`/`utm_campaign`/`utm_content`/`s_referral`/`source_other`/`category`/`communication` |
| `--page <value>` | 否 | string | `1` | 页码（仅 detail 模式） |
| `--page_size <value>` | 否 | string | `20` | 每页数量（仅 detail 模式），上限 100 |
| `--has_phone <value>` | 否 | string | — | 是否只返回有手机号的：`true`/`false` |
| `--s_channel <value>` | 否 | string | — | 按渠道大类过滤（CSV 多值 OR），如 `ib,ad,al` |
| `--s_product <value>` | 否 | string | — | 按来源产品过滤（CSV 多值 OR） |
| `--utm_source <value>` | 否 | string | — | 按一级渠道过滤（CSV 多值 OR） |
| `--utm_campaign <value>` | 否 | string | — | 按二级渠道过滤（CSV 多值 OR） |
| `--utm_content <value>` | 否 | string | — | 按三级渠道过滤（CSV 多值 OR） |
| `--s_referral <value>` | 否 | string | — | 按分享人过滤 |
| `--source_other <value>` | 否 | string | — | 按来源渠道备注模糊过滤（CSV 多值 OR，LIKE 查询） |
| `--category <value>` | 否 | string | — | 按身份画像过滤（CSV 多值 OR）。可选值：`tech_giants_employee`(在职员工)、`researcher_founder`(Researcher Founder)、`professor`(科研学者)、`student`(学生)、`investor`(投资人)、`colleague`(奇绩同事) 等 |
| `--communication <value>` | 否 | string | — | 按接触状态过滤（CSV 多值 OR）。可选值：`unaware`(待接触)、`reaching`(触达过程中)、`aware`(沟通说服中)、`success`(说服催填)、`finish`(说服填完)、`active_pending_meeting`(激活待约会)、`lead_meeting_scheduled` 等 |
| `--meeting_success <value>` | 否 | string | — | 是否成功开会（null 视为 false） |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> **权限**：需要 `apply:contacts:read:all`。

## 返回结构

### detail 模式

```json
{
  "start_date": "2026-01-13",
  "end_date": "2026-06-15",
  "date_field": "created_at",
  "mode": "detail",
  "page": 1,
  "page_size": 20,
  "total": 1200,
  "items": [
    {
      "id": "123",
      "phone": "138****0000",
      "s_channel": "ib",
      "s_product": "ba",
      "utm_source": "ob",
      "created_at": "2026-02-01T08:00:00Z"
    }
  ]
}
```

### count 模式（group_by）

```json
{
  "start_date": "2026-01-13",
  "end_date": "2026-06-15",
  "date_field": "created_at",
  "mode": "count",
  "group_by": ["s_channel"],
  "total": 1200,
  "groups": [
    { "s_channel": "ib", "count": 800 },
    { "s_channel": "ob", "count": 200 }
  ]
}
```

## AI 使用建议

1. **明细 vs 计数**：统计用 `--mode count --group_by <field>`（秒级，不超时）；读明细数据用默认 `detail` 模式
2. **大区间用 count**：半年级别累计区间下明细数据量大，请求可能超时；改用 count 模式
3. **渠道代码**：返回字段中 `s_channel`/`s_product` 等为原始代码（如 `ib`/`ba`），需自行映射到业务渠道名称
4. **PII 保护**：明细含手机号，不要直接回显给用户，应聚合后呈现

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-reports-soc-channel-users](apply-reports-soc-channel-users.md) — 企微用户统计
- [mplus-reports SKILL.md](../../../skills/mplus-reports/SKILL.md) — DS 报告：归类聚合算法、6 时段周期换算、归属规则
