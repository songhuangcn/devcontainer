# apply contacts batch-update

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

对一批人脉批量追加标签（与已有标签合并去重），单次最多 1000 个 ID。

对应命令：`mplus apply contacts batch-update --ids <json> --tags <json>`（内部调用 `PATCH /apply/open_api/v2/contacts/batch_update`，通过 API Gateway）。

## 命令示例

```bash
mplus apply contacts batch-update --ids '[123, 456]' --tags '["VIP", "重点跟进"]' --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--ids <value>` | 是 | JSON 数组字符串 | 人脉 ID 列表（最多 1000 个），如 `'[123, 456]'` |
| `--tags <value>` | 是 | JSON 数组字符串 | 要追加的标签列表，如 `'["VIP"]'` |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

## 权限

需要 `apply:contacts:batch_update` 权限。

## 功能说明

- 只支持批量追加 `tags`，不支持更新其他字段
- 追加语义：传入的标签与已有标签合并去重，**不会替换**已有标签
- 单次最多 1000 个 ID
- 部分失败不影响整体，返回 200 并分别列出成功/失败/无权限的 ID

## 返回字段

```json
{
  "success_ids": ["123", "456"],
  "failed_ids": [],
  "forbidden_ids": ["789"]
}
```

| 字段 | 说明 |
|------|------|
| `success_ids` | 成功更新的人脉 ID 列表（字符串） |
| `failed_ids` | 更新失败的人脉 ID 列表（字符串） |
| `forbidden_ids` | 无权操作的人脉 ID 列表（字符串） |

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-contacts-search](apply-contacts-search.md) — 搜索获取 ID 列表
