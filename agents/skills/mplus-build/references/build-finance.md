# build finance

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询 Build / Accelerator 财务数据。需要 `accelerator:finance:read` 权限。

对应命令：`mplus build finance [resource] [action]`，内部调用 `/build/open_api/v2/finance/**`。

## 公司财务汇总

```bash
mplus build finance summary <companyId> \
  --finance_code MP_A00001 \
  --fund_name all \
  --day 2026-06-30 \
  --currency RMB \
  --usd_rate 7.2 \
  --json
```

可选参数：

- `--finance_code <value>`：财务公司记录编码，传入时优先通过编码定位公司
- `--fund_name <value>`：所属基金过滤；`all` 表示不过滤基金
- `--day <value>`：业务日期精确匹配，格式 `YYYY-MM-DD`
- `--currency <value>`：展示币种上下文参数
- `--usd_rate <value>`：美元汇率上下文参数

## 列表与详情资源

每个资源都支持：

```bash
mplus build finance <resource> list [filters] --json
mplus build finance <resource> show <id> --json
```

资源列表：

| resource | 说明 | 路径 |
|------|------|------|
| `cashflows` | 财务现金流 | `/finance/cashflows` |
| `company-records` | 公司财务基础信息 | `/finance/company_records` |
| `funding-rounds` | 融资轮次 | `/finance/funding_rounds` |
| `investment-infos` | 投资信息 | `/finance/investment_infos` |
| `investment-progresses` | 投资进展 | `/finance/investment_progresses` |
| `quarter-reports` | 财务季度报告 | `/finance/quarter_reports` |
| `sync-records` | 财务同步记录 | `/finance/sync_records` |
| `team-tags` | 公司团队标签 | `/finance/team_tags` |

通用列表参数：

- `--page <value>`：页码，从 1 开始
- `--page_size <value>`：每页数量，默认 20，最大 100
- `--company_id <value>`：按公司 ID 过滤，适用于多数公司相关资源
- `--day <value>` / `--day_gte <value>` / `--day_lte <value>`：业务日期过滤，适用于现金流、融资轮次、投资进展
- `--belonging_fund <value>` / `--fund_name <value>`：基金过滤，适用于现金流、投资信息、投资进展
- `--status <value>`：同步状态过滤，适用于 `sync-records`

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
- [build-companies](build-companies.md) — 公司列表、详情和追加投资投票快照
