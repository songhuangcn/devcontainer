# build companies

公司列表、详情和追加投资投票快照查询。

## 查询列表

```bash
mplus build companies list --batch_ids 13,14 --application_ids 9001,9002 --cities 北京,上海 --q 奇绩 --page 1 --page_size 20
```

可选参数：

- `--batch_ids <value>`：批次 ID 列表，命中任一批次，支持逗号分隔字符串
- `--application_ids <value>`：关联申请表 ID 列表，命中任一，支持逗号分隔字符串
- `--cities <value>`：城市标签列表，命中任一，支持逗号分隔字符串
- `--q <value>`：名称关键词，对公司名称 `name` 与注册名称 `legal_name` 做模糊匹配
- `--page <value>`：页码，从 1 开始，默认 1
- `--page_size <value>`：每页数量，默认 20，最大 100
- `--profile <name>`：指定登录身份
- `--json`：以 JSON 格式输出

列表返回分页结构：`total`、`page`、`page_size`、`items`。

## 查询详情

```bash
mplus build companies show <id>
```

`<id>` 支持公司数字 ID 或 slug。详情返回公司基本信息、融资轮次、人员规模、行业分类、所在城市、批次、创始人和关联申请表 ID。

需要 `accelerator:companies:read` 权限。

## 查询追加投资投票快照

```bash
mplus build companies follow-on <companyId> --json
```

内部调用 `GET /build/open_api/v2/companies/{company_id}/follow_on`，返回该公司的追加投资投票快照。

需要 `accelerator:follow_on_investment_polls:read` 权限。
