# admission startup-projects get

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询单个 startup_project 的详细信息。

对应命令：`mplus admission startup-projects get <project_id>`（内部调用 `GET /admission/api/v1/startup-projects/:project_id`，通过 API Gateway）。

## 命令示例

```bash
# 查询单个项目（默认只看初始提交）
mplus admission startup-projects get 87575

# JSON 格式输出（AI Agent 推荐）
mplus admission startup-projects get 87575 --json

# 查看补充材料版本
mplus admission startup-projects get 87575 --addition true --json

# 使用指定 profile
mplus admission startup-projects get 87575 --profile work --json
```

## 参数

| 参数 | 必填 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `<project_id>` | **是** | string (位置参数) | — | 项目唯一标识 |
| `--addition <bool>` | 否 | string | `"false"` | 是否查看补充材料版本：`true` 返回补充提交，`false` 返回初始提交 |
| `--profile <name>` | 否 | string | 当前 profile | 临时使用指定 profile |
| `--json` | 否 | boolean | `false` | 以 JSON 格式输出完整响应 |

> **`--addition` 取值规则**：接受 `true`/`1`/`yes`/`y` 或 `false`/`0`/`no`/`n`（不区分大小写）。其他值会报错。

## 返回字段

### JSON 格式（`--json`）

```json
{
  "project_id": "87575",
  "batch_name": "26s",
  "application_content": "完整的申请材料文本...",
  "interview_content": "完整的面试材料文本...",
  "addition": false
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `project_id` | string | 项目唯一标识 |
| `batch_name` | string | 所属批次名 |
| `application_content` | string \| null | 申请材料全文（可能为 null，表示未提交） |
| `interview_content` | string \| null | 面试材料全文（可能为 null，表示未提交） |
| `addition` | boolean | 是否为补充材料 |

### 默认文本格式

```
项目 ID：87575
批次：26s
补充材料：否
申请材料长度：3456
面试材料长度：2100
```

> 文本格式只显示材料长度，不显示实际内容。需要完整内容必须加 `--json`。

## 常见错误

| 现象 | 原因 | 解决方案 |
|------|------|---------|
| `OAuth 鉴权失败，请运行 mplus login 重新登录` | token 过期且刷新失败 | 执行 `mplus login` |
| `未找到 OAuth session，请先运行 mplus login` | 从未登录 | 执行 `mplus login` |
| `--addition 只能是 true 或 false` | `--addition` 传了非法值 | 使用 `true`/`false`/`1`/`0`/`yes`/`no` |
| `资源不存在` | project_id 不存在，或该 addition 状态下无记录 | 确认 project_id 正确；尝试切换 `--addition` 值 |
| `你没有访问该资源的权限` | 当前用户无 admission 数据权限 | 确认账户权限 |

## AI 使用建议

1. **获取完整材料**：必须加 `--json`，否则只能看到材料长度
2. **初始 vs 补充材料**：同一个 project_id 可能有两个版本——初始提交（`--addition false`，默认）和补充提交（`--addition true`）。如果用户要看"最新材料"或"补充材料"，记得切换 `--addition`
3. **project_id 来源**：通常从 `admission startup-projects list` 的结果中获取
4. **材料为 null**：表示该阶段材料尚未提交，不是错误

## 参考

- [mplus-admission](../SKILL.md) — admission 领域概览
- [mplus-shared](../../mplus-shared/SKILL.md) — 认证和全局参数
- [admission-startup-projects-list](admission-startup-projects-list.md) — 查询项目列表
