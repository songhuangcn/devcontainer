# admission prompt-eval

> **前置条件：** 先用 Read 工具读取 [`../../mplus-shared/SKILL.md`](../../mplus-shared/SKILL.md) 了解认证和全局参数。

查询 prompt-eval 方式生成的 feature 宽表。分申请维度（`application-features`，以 Apply `application_id` 为主体）和创始人维度（`founder-features`，以 Apply `founder_id` 为主体）两套。这里的 ID 与 Apply 侧 application/founder 是同一对象。

对应命令：
- `mplus admission prompt-eval application-features`（`GET /admission/api/v1/prompt-eval/application-features`）
- `mplus admission prompt-eval founder-features`（`GET /admission/api/v1/prompt-eval/founder-features`）

## 命令示例

```bash
# 按 application_id 批量查询申请 feature（逗号分隔多值）
mplus admission prompt-eval application-features --application_ids 10001,10002 --json

# 查询某 feature 非 null 的申请
mplus admission prompt-eval application-features --feature has_pre_seed --json

# 查询 score >= 0.7 的申请（数值型 feature）
mplus admission prompt-eval application-features --feature founder_score --min_value 0.7 --json

# 按 founder_id 批量查询创始人 feature
mplus admission prompt-eval founder-features --founder_ids 789,790 --json

# 精确匹配 feature 值（如 phd=true）
mplus admission prompt-eval founder-features --feature phd --feature_value true --json
```

## 参数

两个子命令参数结构一致，仅 ID 过滤参数不同（`application-features` 用 `--application_ids`，`founder-features` 用 `--founder_ids`）。

| 参数 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `--application_ids <value>` | 否 | string | 【仅 application-features】按 Apply `application_id` 过滤，逗号分隔多值 |
| `--founder_ids <value>` | 否 | string | 【仅 founder-features】按 Apply `founder_id` 过滤，逗号分隔多值；非整数返回 422 |
| `--feature <value>` | 否 | string | 过滤用的单个 feature 字段名；单独传表示该 feature 非 null，配合下方值参数按值过滤 |
| `--feature_value <value>` | 否 | string | 与 `feature` 配合的精确匹配值（`null`/`true`/`false`/整数/小数） |
| `--min_value <value>` | 否 | number | 与 `feature` 配合的数值下界（score >= 阈值），仅数值型 feature |
| `--max_value <value>` | 否 | number | 与 `feature` 配合的数值上界（score <= 阈值），仅数值型 feature |
| `--features <value>` | 否 | string | 响应投影字段，逗号分隔多个 feature 列名；不传返回全部 feature（传了 `feature` 但没传 `features` 时默认只返回该 feature） |
| `--page <value>` | 否 | string | 1-based 页码，小于 1 归一化为 1 |
| `--page_size <value>` | 否 | string | 每页数量，小于 1 归一化为 1，大于 100 限制为 100 |
| `--profile <name>` | 否 | string | 临时使用指定 profile |
| `--json` | 否 | boolean | 以 JSON 格式输出完整响应 |

> **权限**：需要 `admission:applications:read`。

## 返回字段

分页宽表，`items` 为 feature 记录列表，主体为 `application_id` / `founder_id`，其余列为各 prompt-eval feature 字段。具体 feature 列随后端变动，用 `--json` 输出后自行解析；可用 `--features` 控制返回哪些列。

## AI 使用建议

1. **ID 与 Apply 一致**：`application_id` / `founder_id` 即 Apply 侧 application/founder 的对象 ID，可与 `mplus apply applications list` 的 `id` / `founders[].id` 互通
2. **按值过滤要配合 `feature`**：`feature_value`/`min_value`/`max_value` 必须与 `--feature` 同传才生效
3. **投影减负**：只关心少数 feature 时用 `--features` 限定返回列，减小响应体积

## 参考

- [mplus-admission](../SKILL.md) — admission 领域概览
- [mplus-apply](../../mplus-apply/SKILL.md) — application/founder ID 来源
