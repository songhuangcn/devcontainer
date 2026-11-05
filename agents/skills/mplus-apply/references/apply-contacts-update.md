# apply contacts update

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

更新一条人脉记录（PATCH 语义）。成功返回 200 和更新后的完整人脉对象（`ContactWithRelations`，含 `application_ids` / `founder_ids` 关联 ID 数组）。`tags` 为追加模式（不覆盖原有标签）。

对应命令：`mplus apply contacts update <id> --contact <json>`（内部调用 `PATCH /apply/open_api/v2/contacts/{id}`，通过 API Gateway）。

## 命令示例

```bash
mplus apply contacts update 123 --contact '{"remark":"已电话沟通，意向较强"}' --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `<id>` | 是 | string | 人脉 ID |
| `--contact <value>` | 是 | JSON string | 要更新的字段对象（均为可选字段，传哪个更新哪个），整体作为一个 JSON 字符串传入；额外支持 `operator_id` |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

## 权限

- 需要 `apply:contacts:update` 权限
- 实例级权限：持 `apply:contacts:read:all` 可更新任意人脉；仅持 `read:self` 时只能更新归属自己的人脉

## tags 追加语义

传入 `tags` 时会与已有标签合并去重，**不会替换**已有标签。如果需要添加标签到一批人脉，优先使用 [apply-contacts-batch-update](apply-contacts-batch-update.md)。

## 错误说明

| HTTP | 错误码 | 原因 |
|------|--------|------|
| 403 | `forbidden` | 无权操作该人脉（非管理员且不在自己名下） |
| 409 | `conflict` | 更新的联系方式与其他人脉重复 |
| 404 | `not_found` | 人脉不存在 |

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-contacts-batch-update](apply-contacts-batch-update.md) — 批量追加标签
- [apply-contacts-get](apply-contacts-get.md) — 查看更新后的完整字段
