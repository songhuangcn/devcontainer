# build funds

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

搜索/查看投资机构（大力点评系统的"机构"维度）。

对应命令：
- `mplus build funds list`（`GET /build/open_api/v2/funds`）
- `mplus build funds show <id>`（`GET /build/open_api/v2/funds/{id}`）
- `mplus build funds create`（`POST /build/open_api/v2/funds`）

## 命令示例

```bash
# 按名称模糊搜索机构（含别名）
mplus build funds list --q 纪源资本 --json

# 查看机构详情（含 fund_investors_count）
mplus build funds show 2524 --json

# 创建机构（chinese_name 必填，全表唯一）
mplus build funds create --chinese_name "光速中国" --english_name "Lightspeed China" --json
```

## 参数

### list

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--q <value>` | 否 | string | 按机构名模糊搜索（含别名） |
| `--profile <name>` / `--json` | 否 | — | 通用参数 |

### show

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | integer | 机构 ID |

### create

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--chinese_name <value>` | 是 | string | 机构中文名，全表唯一 |
| `--english_name <value>` | 否 | string | 英文名 |
| `--full_name <value>` | 否 | string | 完整名称 |
| `--other_name <value>` | 否 | string | 别名，可用于搜索匹配 |

## 返回字段

```json
{
  "id": "2524",
  "chinese_name": "纪源资本",
  "english_name": null,
  "full_name": "纪源资本",
  "other_name": "",
  "created_at": "2020-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "fund_investors_count": 12
}
```

`fund_investors_count` 仅 `show` 返回。

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `403 forbidden` | 缺少 `accelerator:funds:read`（查看）/ `accelerator:funds:write`（创建） | 确认账号角色 |
| `404 not_found` | 机构 ID 不存在 | 用 `list --q` 重新搜索 |
| `422` | 创建时机构名重复（唯一性校验） | 先 `list --q` 确认是否已存在 |

## AI 使用建议

1. 查找机构用 `list --q`，不要假设机构名唯一可直接拼 ID
2. `funds` 是"机构"维度，"投资人"个体在 `mplus build fund_investors`

## 参考

- [mplus-build](../SKILL.md) — build 领域概览
- [build-fund-investors](build-fund-investors.md) — 投资人个体
