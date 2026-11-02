---
name: mplus-reports
description: "奇绩创坛 DS 报告数据源：按日期区间拉「13 渠道」线索聚合（手机号 contacts + 企微 soc_channel_users）。当用户要统计奇绩线索来源、做周期/同比分析、或生成「线索来源周期对比报告」(DS 报告) 时使用。CLI 只出原始计数——渠道归类、跨源聚合、6 时段周期日历全部由你（AI）按本 skill 规则完成：对每个区间调 `mplus apply reports contacts/soc-channel-users --mode count --group_by …`，再归类聚合。"
metadata:
  requires:
    bins: ["mplus"]
---

# reports（DS 报告数据源）

**CRITICAL — 开始前 MUST 先用 Read 工具读取 [`../mplus-shared/SKILL.md`](../mplus-shared/SKILL.md)（认证、登录、错误处理、`--json`）**

## 这是什么

reports 提供「线索来源周期对比分析报告」(DS 报告) 的**聚合数据源**。

> **重要：没有现成的聚合命令。** CLI 侧只有两个**原始计数接口**（`mplus apply reports …`），它们只做「区间查询 + 计数/分组」，**不含任何业务语义**。「归类到 13 渠道」「手机号+企微跨源合并」「6 时段周期日历」**全部由你（AI）按本 skill 的规则完成**：

整条链路（你来驱动）：

```
对每个区间 [S, E]：
  ① mplus apply reports contacts        --mode count --group_by <CONTACTS_GROUP_BY> → 原始分组计数
  ② mplus apply reports soc-channel-users --mode count --group_by <SOC_GROUP_BY>      → 原始分组计数
  ③ 按「归属规则」把每个分组归到 13 渠道之一（或「其他/未归类」/「非线索·剔除」）
  ④ 聚合：phone_total = contacts 计数；qy_total = soc 计数 − 非线索；逐渠道 {phone, qy, total}
一份 DS 报告 = 6 个区间各跑一遍 ①–④ 再组合成文
```

两个底层命令（均为**管理员命令**，需 `apply_admin`；详见 [mplus-apply skill](../mplus-apply/SKILL.md)）：

| 数据 | 命令 | 接口 |
|---|---|---|
| 手机号人脉 | `mplus apply reports contacts` | `GET /apply/open_api/v2/reports/contacts`（只返有手机号的人脉） |
| 企微好友 | `mplus apply reports soc-channel-users`（别名 `qywechat`） | `GET /apply/open_api/v2/reports/soc_channel_users` |

> 参数用**下划线名**（`--start_date`/`--end_date`/`--mode`/`--group_by`），完整参数表见 mplus-apply 的 references。统计**一律 `--mode count`**（秒级、不超时、不返 PII）；`detail` 仅用于小区间逐条复核。

## 取数与聚合（你来算）—— 单区间

对一个区间 `[S, E]` 跑以下两条命令，再按 §归属规则归类聚合。**group_by 字段必须照抄**（归类规则依赖这些字段）：

```bash
# ① 手机号人脉：按渠道字段组合分组计数
mplus apply reports contacts --start_date <S> --end_date <E> \
  --mode count --group_by s_channel,s_product,utm_source,utm_campaign,source_other --json

# ② 企微好友：按最早托管账号分组计数
mplus apply reports soc-channel-users --start_date <S> --end_date <E> \
  --mode count --group_by add_juzi_follow_user_earliest_name --json
```

两条命令均返回扁平结构 `{ start_date, end_date, total, groups: [ {分组字段…, count} ] }`。聚合算法（等价于原 `mplus reports summary`，现由你执行）：

1. **contacts**：对 `groups` 每一项按 `classifyContact`（见 §归属规则）归到某渠道，`count` 累加到该渠道的 `phone`。`phone_total = contacts.total`（接口默认 `exclude_batch`，批量数据 `s_channel=sj` 已剔除，正常不出现）。
2. **soc**：对 `groups` 每一项按 `classifySoc` 归类。账号 = **奇绩投资人小助手** → 标记「非线索」**不计入任何渠道，并从总数扣除**；其余 `count` 累加到对应渠道的 `qy`。`qy_total = soc.total − 非线索计数`。
3. **合并**：每个渠道 `total = phone + qy`；区间 `total = phone_total + qy_total`。
4. **区间回显**：用接口返回的 `start_date`/`end_date`（权威）和你算的区间核对，报告里写明每段实际区间。

> 结果结构（你在内存里组织，等价于旧 summary 的 `--json`）：`{ start_date, end_date, phone_total, qy_total, total, channels: { <渠道>: {phone, qy, total} } }`，channels 含 13 渠道 + `其他/未归类`。

## 业务周期与 6 个时间段（你来换算日期）

奇绩按**半年一期**（26 周）：**上半年 1/13–7/12、下半年 7/13–次年1/12**（7/13 起算下半年，7/12 仍属上半年）。报告对比 6 个时段。**先确定「今天」`N`**（见你上下文里的当前日期），再按下表算出每段的 `start`/`end`（`YYYY-MM-DD`）：

| 时段 | start_date | end_date |
|---|---|---|
| 本期累计 | 本期周期起始日 | `N`（今天） |
| 上期同日累计 | 上期周期起始日 | `N − 26 周` |
| 上上期累计 | 上上期周期起始日 | `N − 52 周` |
| 本周 | 本周一 | `N`（今天） |
| 上期同周 | 本周一 `− 26 周` | `N − 26 周` |
| 上上期同周 | 本周一 `− 52 周` | `N − 52 周` |

换算口径（**严格照此算，逐日相减，别凑整**）：
- **本期周期起始日** = 不晚于今天的最近一个 `1/13` 或 `7/13`；若今天是 `1/1–1/12`，则为**去年的 `7/13`**。
- **上期周期起始日** = 本期起始日往前推半年的那个边界（本期 `7/13/Y` → 上期 `1/13/Y`；本期 `1/13/Y` → 上期 `7/13/(Y−1)`）。**上上期**再往前推一个半年。
- **本周一** = 今天所在自然周的周一。
- **26 周 = 182 天，52 周 = 364 天**（按天相减，跨月/跨年逐日数，勿用「减半年」近似）。

> **示例**（假设今天 `N = 2026-06-16`，星期二 —— 实际请用你上下文的当前日期重算）：
> 本期累计 `2026-01-13 ~ 2026-06-16`；上期同日累计 `2025-07-13 ~ 2025-12-16`；上上期累计 `2025-01-13 ~ 2025-06-17`；本周 `2026-06-15 ~ 2026-06-16`；上期同周 `2025-12-15 ~ 2025-12-16`；上上期同周 `2025-06-16 ~ 2025-06-17`。

> **务必核对**：每条命令输出会回显接口实际查询的 `start_date`/`end_date`，把它和你算的区间对一眼；并在报告里写明每段区间，便于用户复核。

## 认证要求

`apply reports` 都是**管理员命令**，需 `apply_admin` 角色并通过 `mplus login` 完成 OAuth 登录。非管理员看不到该命令（会报「未知命令：apply」）。详见 mplus-shared。

## 命令速查

| 命令 | 说明 | 参考 |
|---|---|---|
| `mplus apply reports contacts --mode count --group_by s_channel,s_product,utm_source,utm_campaign,source_other --json` | 手机号人脉**分组计数**（聚合的左半边） | [references/reports-query.md](references/reports-query.md) |
| `mplus apply reports soc-channel-users --mode count --group_by add_juzi_follow_user_earliest_name --json` | 企微好友**分组计数**（聚合的右半边，别名 `qywechat`） | [references/reports-query.md](references/reports-query.md) |
| `mplus apply reports … --mode detail --fields … --json` | 小区间**逐条复核**（含 PII，勿直接回显） | [mplus-apply](../mplus-apply/SKILL.md) |

均接 `--start_date`/`--end_date`/`--profile`/`--json`（不传日期 = 服务端默认：start = 当期业务周期起始日、end = 今天）。

## 自然语言 → 命令

| 用户说 | 怎么做 |
|---|---|
| 看**本期累计**线索来源渠道分布 | 算出本期起始日 `S` → 用 `[S, 今天]` 跑两条 count 命令 → 归类聚合 |
| 看**本周**新增 | 算出本周一 `M` → 用 `[M, 今天]` 跑两条 count 命令 → 归类聚合 |
| 生成 / 更新完整 **DS 报告**（6 段对比） | 按上表算 6 段区间 → 对每段跑两条 count 命令并聚合 → 组合（见下方流程） |
| 某个**自定义区间** | 用该区间跑两条 count 命令 → 归类聚合 |
| **复核**某渠道明细 | 用该段区间调 `mplus apply reports contacts/soc-channel-users --mode detail --fields … --json` |

## 生成 DS 报告的流程

1. **定今天 `N`**：取你上下文里的当前日期。
2. **算 6 段区间**：按上方「业务周期」规则算出 6 个 `start`/`end`（逐日相减，26周=182天、52周=364天）。
3. **逐段取数 + 聚合**：对 6 段**各跑一遍** ①contacts count + ②soc count 两条命令，按 §归属规则归类聚合，得每段 `{start_date, end_date, phone_total, qy_total, total, channels}`（每段 13 渠道，各 `{phone, qy, total}`）。
4. **成文**：套报告 prompt（角色 = 销售数据分析助手），按 prompt 的**四段结构**：① 整体总结（本周结构与关键变化）；② 本期累计/本周 vs 上期同日累计/上期同周；③ 本期累计/本周 vs 上上期累计/上上期同周；④ 管理层可关注的判断。②③ 用 `total`/`phone_total`/`qy_total` 做总量对比、`channels` 做 13 渠道逐条原因分析（表格）；④ 给管理视角的判断与建议。**每段标注实际区间**（来自命令回显的 `start_date`/`end_date`）。
5. **存疑复核**（可选）：某渠道数对不上时，用该段区间换字段调 count（如单独 `--group_by s_channel`）核对，或缩小区间用 `detail` 看明细。

13 渠道：自然流量 / 创业社区 / 潜空间 / SS / 前沿信号 / 算力 / outbound汇总 / 大厂 / 高校 / 广告投放 / 北美 / mapping / 校友。

> 归类是程序化近似的口径（见 §归属规则，原 `attribution.ts` 的规则已搬入本 skill）。count 现已纳入 `source_other`（「奇绩主编/PRteam→创业社区」已精确归类）；但**仍不含 `qy_tag_names`**，故 soc 的「Olivia/Leo 标签细分」会降级（归 outbound汇总）。存疑渠道用 `--mode detail` 复核。

## AI 使用建议

1. **没有聚合命令**：归类 + 聚合 + 6 段周期全是你的活。对每个区间各跑 ①+② 两条 `apply reports … --mode count` 命令，自己按 §归属规则归类、累加、合并。
2. **group_by 照抄**：contacts 用 `s_channel,s_product,utm_source,utm_campaign,source_other`，soc 用 `add_juzi_follow_user_earliest_name`——归类规则依赖这些字段，少一个就归不准。
3. **日期是你算的**：6 段区间按规则逐日换算，**别用现成 key**，算完用命令回显的 `start_date`/`end_date` 自检，并在报告里写明区间。
4. **统计用 count，复核才 detail**：count 秒级、不超时、无 PII；`detail` 大区间易超时且含手机号/微信。
5. **响应结构**：**扁平、无 `{code,message,data}` 信封**——字段在顶层；count 分组在 `groups`、`total` 在顶层、detail 明细在 `items`。**均返回原始代码**（ib/ba/gzh），归类用代码。
6. **保护 PII**：detail 含手机号 / 微信，不要直接回显；count 只返计数，无 PII。
7. **归属规则会随运营变动**：规则现内嵌在本 skill（不再发版 CLI 即可改），来源是飞书「提交归属原则」表；运营调整托管账号 / 渠道映射时，同步更新 [references/reports-query.md](references/reports-query.md) 的归属表。
