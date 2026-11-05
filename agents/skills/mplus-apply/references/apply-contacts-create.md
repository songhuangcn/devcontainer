# apply contacts create

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

新建一条人脉记录。创建前会执行字段校验和重复检查，成功返回 HTTP 201 和完整人脉对象。

对应命令：`mplus apply contacts create --contact <json>`（内部调用 `POST /apply/open_api/v2/contacts`，通过 API Gateway）。

## 命令示例

```bash
mplus apply contacts create --contact '{
  "name": "张三",
  "phone": "13800000000",
  "s_product": "ba",
  "s_channel": "ib",
  "utm_source": "else"
}' --json
```

## 参数

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--contact <value>` | 是 | JSON string | 人脉字段对象，整体作为一个 JSON 字符串传入；字段列表见下方「必填字段」及 `ContactWriteParams` |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出 |

## 权限

需要 `apply:contacts:create` 权限。

## 必填字段（`--contact` JSON 内）

| 字段 | 说明 |
|------|------|
| `name` | 姓名（必填） |
| 至少一种联系方式 | `phone`/`phone_2`/`phone_3`/`email`/`email_2`/`email_3`/`email_4`/`wechat` 任填其一 |
| `s_product` | 原始来源产品（必填，合法枚举值，如 `ba`/`ls`/`ss` 等） |
| `s_channel` | 原始渠道大类（必填，如 `ib`/`ob`/`ad`/`al` 等） |
| `utm_source` | 原始一级渠道（必填，合法枚举值） |

## 错误说明

| HTTP | 错误码 | 原因 |
|------|--------|------|
| 422 | `validation_error` | 缺少必填字段或字段值非法 |
| 409 | `conflict` | 手机号/邮箱/微信重复，`details` 中有已有记录的 `contact_id` |

## 参考

- [mplus-apply](../SKILL.md) — apply 领域概览
- [apply-contacts-search](apply-contacts-search.md) — 搜索已有人脉
