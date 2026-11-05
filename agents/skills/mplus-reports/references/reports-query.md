# DS 报告：取数命令 + 归类聚合算法 + 周期换算 + 归属规则

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md)（认证、全局参数）与 [`../SKILL.md`](../SKILL.md)（reports 概览、报告生成流程）。

DS 报告数据来自两个接口（均为**管理员命令**，需 `apply_admin` 角色，经 API Gateway 访问 apply 主站 open_api）：

- 手机号人脉 → `GET /apply/open_api/v2/reports/contacts`（只返回有手机号的人脉）
- 企微好友 → `GET /apply/open_api/v2/reports/soc_channel_users`

接口本身**只做「区间查询 + 计数/分组」，不含业务语义**。CLI 不再有聚合命令（原 `mplus reports summary` 及其归类逻辑已移除）——**归类到 13 渠道、跨源聚合、6 时段周期日历，全部由你（AI）按本文件执行**：对每个区间调两条 `mplus apply reports … --mode count`，再按下方算法归类聚合。

## 一、取数命令（每个区间两条 count）

```bash
# ① 手机号人脉：按渠道字段组合分组计数（group_by 必须照抄，归类规则依赖这些字段）
mplus apply reports contacts --start_date 2026-01-13 --end_date 2026-06-16 \
  --mode count --group_by s_channel,s_product,utm_source,utm_campaign,source_other --json

# ② 企微好友：按最早托管账号分组计数（别名 qywechat）
mplus apply reports soc-channel-users --start_date 2026-01-13 --end_date 2026-06-16 \
  --mode count --group_by add_juzi_follow_user_earliest_name --json
```

- 参数用**下划线名**：`--start_date` / `--end_date`（`YYYY-MM-DD`，可省，省则用服务端默认 = 当期起始日 ~ 今天）、`--mode count`、`--group_by`、`--profile`、`--json`。
- 批量数据（`s_channel=sj`）默认已剥离，正常不出现；`--exclude_batch` 开关已移除，不再可通过参数包含批量数据。若 `groups` 里仍出现 `s_channel=sj`，按归属规则跳过不计。
- mode=count，**秒级**；大区间也不超时、不返 PII。
- **一次只算一个区间**；6 段报告 = 按第三节算出 6 个区间，每段各跑这两条再聚合。

**响应结构**（count 模式，扁平、无 `{code,message,data}` 信封）：

```json
{
  "start_date": "2026-01-13",
  "end_date": "2026-06-16",
  "mode": "count",
  "group_by": ["s_channel", "s_product", "utm_source", "utm_campaign", "source_other"],
  "total": 7766,
  "groups": [
    { "s_channel": "ib", "s_product": "ls", "utm_source": "gzh", "utm_campaign": "", "source_other": "", "count": 320 },
    { "s_channel": "ob", "s_product": "", "utm_source": "gx", "utm_campaign": "", "source_other": "", "count": 88 }
  ]
}
```

soc 同理，`groups` 项形如 `{ "add_juzi_follow_user_earliest_name": "潜空间小助手", "count": 130 }`。

## 二、归类聚合算法（你来执行，等价于原 summary）

对一个区间 `[S, E]`，跑完 ①② 两条命令后：

1. **contacts**：遍历 `groups`，对每项按 [§五 classifyContact](#五归属规则把原始字段归到-13-个报告渠道) 用**原始代码**归到某渠道，把 `count` 累加进该渠道的 `phone`。
   - `phone_total = contacts.total`（`exclude_batch` 默认已剔除 `s_channel=sj`，正常 groups 里不会有批量数据）。
2. **soc**：遍历 `groups`，对每项按 [§五 classifySoc](#五归属规则把原始字段归到-13-个报告渠道) 按**账号原名**归类。
   - 账号 = **奇绩投资人小助手** → 标记「非线索」：**不计入任何渠道**，其 `count` 从总数扣除（投资人不算获客线索，李晓冉 2026-06-09 确认）。
   - 其余 `count` 累加进对应渠道的 `qy`。
   - `qy_total = soc.total − 非线索计数`。
3. **合并**：每个渠道 `total = phone + qy`；区间 `total = phone_total + qy_total`。
4. **回显核对**：用接口返回的 `start_date`/`end_date`（权威）对你算的区间做自检，报告里写明每段实际区间。

聚合结果（在内存里组织，等价于旧 summary 的 `--json`）：

```json
{
  "start_date": "2026-01-13",
  "end_date": "2026-06-16",
  "phone_total": 7766,
  "qy_total": 3200,
  "total": 10966,
  "channels": {
    "自然流量": { "phone": 1200, "qy": 0,   "total": 1200 },
    "创业社区": { "phone": 1010, "qy": 980, "total": 1990 },
    "潜空间":   { "phone": 0,    "qy": 130, "total": 130 }
  }
}
```

（`channels` 实际含 13 渠道 + `其他/未归类`，每个均为 `{phone, qy, total}`。）

## 三、6 个时间段的日期换算（你来算）

业务周期半年一期（26 周）：**上半年 1/13–7/12、下半年 7/13–次年1/12**（7/13 起算下半年，7/12 仍属上半年）。**先定今天 `N`**，再算 6 段：

| 时段 | start_date | end_date |
|---|---|---|
| 本期累计 | 本期周期起始日 | `N` |
| 上期同日累计 | 上期周期起始日 | `N − 182 天`（26 周） |
| 上上期累计 | 上上期周期起始日 | `N − 364 天`（52 周） |
| 本周 | 本周一 | `N` |
| 上期同周 | 本周一 `− 182 天` | `N − 182 天` |
| 上上期同周 | 本周一 `− 364 天` | `N − 364 天` |

换算口径（**逐日相减，勿凑整**）：

1. **本期周期起始日**：不晚于今天的最近一个 `1/13` 或 `7/13`；今天若是 `1/1–1/12`，则取**去年 `7/13`**。
2. **上期周期起始日**：本期起始日往前一个半年边界（本期 `7/13/Y`→上期 `1/13/Y`；本期 `1/13/Y`→上期 `7/13/(Y−1)`）。**上上期**再往前一个。
3. **本周一**：今天所在自然周的周一。
4. **平移**：`26 周 = 182 天`，`52 周 = 364 天`，按天相减（跨月/跨年逐日数）。

**示例**（今天 `N = 2026-06-16` 周二 —— 实际请用你上下文的当前日期重算）：

| 时段 | 区间 |
|---|---|
| 本期累计 | `2026-01-13 ~ 2026-06-16` |
| 上期同日累计 | `2025-07-13 ~ 2025-12-16` |
| 上上期累计 | `2025-01-13 ~ 2025-06-17` |
| 本周 | `2026-06-15 ~ 2026-06-16` |
| 上期同周 | `2025-12-15 ~ 2025-12-16` |
| 上上期同周 | `2025-06-16 ~ 2025-06-17` |

口径已按刘绍栋 prompt 定稿：周期边界 7/13 起算下半年；同日/同周用 26/52 周整体平移近似半年/一年。**算完务必用命令回显的 `start_date`/`end_date` 自检。**

## 四、字段说明 + 明细复核

**字段值**：detail 与 count **均返回原始代码**（`s_channel="ib"`、`s_product="ba"`、`utm_source="gzh"`），不做中文映射。归类到 13 渠道按 §五 用**代码 / 账号原名**匹配。

**contacts 字段（21）**：`id, wechat_unionid, phone, email, wechat, msg_active, contact_method, created_at(录入), revisit_at(最新跟进), confirm_meeting_at, meeting_at, successful_contact_at, contact_at, meeting_success, s_product(来源产品), s_channel(渠道大类), utm_source(一级渠道), utm_campaign(二级渠道), utm_content(三级渠道), source_other(来源备注), s_referral(分享人)`

**soc_channel_users 字段（11）**：`id, unionid, add_juzi_follow_user_earliest_name(最早托管账号), qy_tag_names(企微标签,逗号分隔), created_at, revisit_at, successful_contact_at, contact_at, confirm_meeting_at, meeting_at, meeting_success`

**复核**：count 数对不上时，换字段单独分组（如只 `--group_by s_channel`）核对；要看逐条用 `--mode detail`（小区间，含 PII，聚合后呈现勿直接回显）：

```bash
# 小区间看明细，过滤值用原始代码 ib（非中文 inbound）
mplus apply reports contacts --start_date 2026-06-08 --end_date 2026-06-16 \
  --s_channel ib --fields id,phone,s_channel --json
```

> 完整参数表见 mplus-apply：[`apply-reports-contacts.md`](../../mplus-apply/references/apply-reports-contacts.md)、[`apply-reports-soc-channel-users.md`](../../mplus-apply/references/apply-reports-soc-channel-users.md)。

## 五、归属规则（把原始字段归到 13 个报告渠道）

> 本节是渠道归类的**权威口径**（原 `src/commands/reports/attribution.ts` 已移除，规则搬到这里，改规则不再需要发版 CLI）。来源：飞书「提交归属原则」表（sheet `JSXSspfcvhYhE2tzisxc4zUenCg`），最终以该表为准；运营调整账号 / 渠道映射时同步更新本节。

报告拆分渠道：自然流量、创业社区、潜空间、SS、前沿信号、算力、outbound汇总（外部活动/学术活动/政府活动/Github）、大厂、高校、广告投放、北美、mapping、校友。

### classifyContact —— 手机号（contacts），按 `s_channel`/`s_product`/`utm_source`(一级)/`utm_campaign`(二级)/`source_other`(备注) 代码

**按顺序判断**（先匹配先归类）：

| 优先级 | 条件（代码） | 归属 |
|---|---|---|
| 1 | `s_channel=sj` | 批量数据（接口默认 `exclude_batch` 已剥离，正常不出现；出现则跳过不计） |
| 2 | `s_channel=ib` + `s_product=ls` | 潜空间 |
| 3 | `s_channel=ib` + `s_product=ss` | SS |
| 4 | `s_channel=ib` + `s_product=qyxh` | 前沿信号 |
| 5 | `s_channel=ib` + `s_product=gpu` | 算力 |
| 6 | `s_channel=ib` + 产品∉{ls,ss,qyxh,gpu} + (一级∈社媒\* **或** 备注含「奇绩主编」/「PRteam」) | 创业社区 |
| 7 | `s_channel=ib` + 产品∉{ls,ss,qyxh,gpu} + 一级∉社媒\* + 备注∉{奇绩主编,PRteam} | 自然流量 |
| 8 | `s_channel=ob` + `utm_source=gx` | 高校 |
| 9 | `s_channel=ob` + `utm_campaign` 含「大厂」或「媒体活动」 | 大厂 |
| 10 | `s_channel=ob` 其余 | outbound汇总 |
| 11 | `s_channel=ad` | 广告投放 |
| 12 | `s_channel=rf` + `s_product=ls` + `utm_source=re` | mapping |
| 13 | `s_channel=rf` 其余 | 北美 |
| 14 | `s_channel=al` | 校友 |
| 15 | 其余（含 `e2e`、空值等） | 其他/未归类 |

> \* **社媒代码集**（`utm_source`）：`gzh, bili, sph, xhs, xyz, dy, jike, x, ins, github, linkedin, zhihu, youtube`
> 备注子串匹配（`source_other` 自由文本含子串即命中）：`奇绩主编`、`PRteam` → 创业社区。

### classifySoc —— 企微（soc_channel_users），按 `add_juzi_follow_user_earliest_name`(托管账号原名)

| 归属 | 账号 |
|---|---|
| 创业社区 | 大模型空间站小助手1号/2号/3号、奇绩创业社区助手1号/2号/6号、奇绩社区推荐助手、奇绩社区助手 MPComm Assistant |
| 潜空间 | 潜空间小助手 |
| SS | 创业公开课小助手、创业公开课小助手④、创业公开课小助手⑤、高校巡讲小助手 |
| 前沿信号 | 前沿信号小助手 |
| 算力 | 刘婷婷 |
| 高校 | 高校创业社区助手 |
| 北美 | 奇绩海外创业者社区小助手 |
| 校友 | 产品日小助手 |
| mapping | Researcher Founder 助手、Mark |
| 广告投放 | 奇绩创业社区助手4号、张晓微、蒋瑶瑶、李佳冉、张小微、张晓薇 |
| 大厂 | 李思睿 |
| outbound汇总 | 吴冰冰、陈知微、奇绩创业营申请助手、Olivia、Leo（标签细分降级） |
| 其他/未归类 | 未覆盖账号（如李金阳，量极小） |
| （剔除·非线索） | **奇绩投资人小助手** → 投资人不算获客线索，从总数中剔除（不计入总量与渠道） |

> count 模式不返 `qy_tag_names`，故 Olivia/Leo 的「外部活动/学术/政府/大厂」标签细分会降级（统归 outbound汇总）。需精确细分时用 `--mode detail --json` 看 `qy_tag_names` 自行细分。

### 已知未覆盖（2026-06-09 实测，归属原则表本身也未收录，待运营补表后同步）

- contacts `s_channel=e2e`（E2E）：归属表未给渠道，暂归「其他/未归类」（量小）。
- soc 账号「李金阳」等其他未覆盖账号：归属表未覆盖，暂归「其他/未归类」。
- count 已支持 `group_by source_other`（后端 Q6② 2026-06-09 验证），inbound 的「奇绩主编/PRteam→创业社区」已精确归类；但仍不含 `qy_tag_names`，soc 的 Olivia/Leo 标签细分仍降级。

## 六、已知限制

- **detail 大区间会超时**：detail 返回全量明细，半年级累计区间服务端扫描慢（易 60s 超时）。统计大区间一律 `--mode count`（不返明细、秒级），或缩小区间。
- **批量数据**：工商导入的批量数据（`s_channel=sj`）默认已剥离，正常不出现；`--exclude_batch` 开关已移除，不再可通过参数包含批量数据。
- **PII**：detail 含手机号/微信/unionid，聚合后再呈现勿直接回显；count 只返计数，无 PII。

## 七、常见错误

| 现象 | 原因 | 解决 |
|------|------|------|
| `错误：未知命令：apply` | 当前账号非管理员（admin 命令对非 admin 隐藏） | 用 `apply_admin` 账号登录 |
| `认证失败，请重新登录` | token 失效 | `mplus login` |
| 某渠道数对不上 | 归类近似（qy_tag 降级、未覆盖账号等） | 换字段单独 `--group_by` 复核，或 `--mode detail` 看明细 |
| detail 请求超时 | 大区间明细量大 | 改 `--mode count`，或缩小区间 |

## 参考

- [mplus-reports](../SKILL.md) — reports 概览、取数聚合链路、6 时间段换算、报告生成流程
- [mplus-apply](../../mplus-apply/SKILL.md) — `apply reports contacts / soc-channel-users` 原始查询的完整参数
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
- `doc/8-reports接口与CLI.md`（仓库内）— 接口契约
