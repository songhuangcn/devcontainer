# build fund_investors

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

搜索/查看投资人个体（大力点评系统的"人"维度，与 `mplus build funds` 的"机构"维度互补）。联系方式脱敏，评价人信息按角色可见。

对应命令：
- `mplus build fund_investors list`（`GET /build/open_api/v2/fund_investors`）
- `mplus build fund_investors show <id>`（`GET /build/open_api/v2/fund_investors/{id}`）
- `mplus build fund_investors create`（`POST /build/open_api/v2/fund_investors`）

## 命令示例

```bash
# 按姓名/所属机构模糊搜索
mplus build fund_investors list --q 陈于思 --json

# 按所属机构过滤（fund_id 对应 funds 的 id）
mplus build fund_investors list --fund_id 2524 --json

# 按评分过滤 + 排序
mplus build fund_investors list --reviews_score 4 --order_by score_desc --json

# 查看详情
mplus build fund_investors show 1393 --json

# 创建投资人（先用 funds list --q 拿到 fund_id）
mplus build fund_investors create --fund_id 2524 --name "张三" --job_title "投资总监" --json
```

## 参数

### list

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--q <value>` | 否 | string | 搜索关键词，同时匹配投资人姓名和所属机构名 |
| `--fund_id <value>` | 否 | string | 按所属投资机构 ID 过滤 |
| `--reviews_score <value>` | 否 | string | 按评分过滤，数值 1-4（4=S、3=A、2=B、1=C） |
| `--order_by <value>` | 否 | string | `score_desc` / `updated_at_desc` / `created_at_desc`；不传默认按评价数倒序 |
| `--profile <name>` / `--json` | 否 | — | 通用参数 |

### show

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | integer | 投资人 ID |

### create

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--fund_id <value>` | 是 | string | 所属投资机构的数据库 ID（不是机构名），来自 `funds list/show` 的 `id` |
| `--name <value>` | 是 | string | 投资人姓名，同一机构下不区分大小写唯一 |
| `--job_title <value>` | 否 | string | 职位 |
| `--field <value>` | 否 | string | 关注领域 |
| `--phone <value>` / `--email <value>` / `--residence <value>` | 否 | string | 联系方式 |

## 返回字段

```json
{
  "id": "1393",
  "name": "陈于思",
  "organization": "纪源资本",
  "job_title": "投资人",
  "field": "",
  "reviews_count": 17,
  "score": "B",
  "created_at": "2020-11-30T16:45:32Z",
  "updated_at": "2026-01-28T12:42:23Z",
  "fund": {
    "id": "2524",
    "chinese_name": "纪源资本",
    "english_name": null
  }
}
```

| 字段 | 说明 |
|------|------|
| `score` | 字母评分（S/A/B/C），由 `reviews_score`（1-4）转换而来；**`--reviews_score` 过滤要传数字，不是字母** |
| `reviews_count` | 累计评价数 |
| `fund` | 所属机构（嵌套对象） |

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `403 forbidden` | 缺少 `accelerator:fund_investors:read` / `:write` | 确认账号角色 |
| `--reviews_score` 过滤不到预期结果 | 传了字母（如 `'s'`）而不是数字 | 传 1-4 的数字，字母会被后端当成 0 处理 |
| `404 not_found` | `fund_id` 用了 `funds` 的中文名而非数据库 ID | `fund_id` 必须是 `funds show`/`list` 返回的整数 `id` |
| `409 conflict` | 创建时同机构下已有同名投资人 | 创建前用 `list --q <name>` 确认是否已存在 |

## AI 使用建议

1. 评分过滤永远传数字 1-4，不要传字母
2. `fund_id` 来自 `mplus build funds list/show` 的 `id`，不是机构名称

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
- [build-funds](build-funds.md) — 投资机构
- [build-fund-investor-reviews](build-fund-investor-reviews.md) — 投资人评价
