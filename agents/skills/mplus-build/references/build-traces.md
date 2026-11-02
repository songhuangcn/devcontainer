# build traces

校友追踪记录查询。需要 `accelerator:company_traces:read:all` 权限。

## 查询列表

```bash
mplus build traces list --q Alpha --batch_names S23,W23 --company_ids 123,456 --page 1 --page_size 20
```

可选参数：

- `--q <value>`：关键词搜索，匹配校友追踪中的公司名称，以及关联公司名称 / 注册名称
- `--batch_names <value>`：按批次名称过滤，支持逗号分隔字符串，例如 `S23,W23`
- `--company_ids <value>`：按公司 ID 过滤，支持逗号分隔字符串，例如 `123,456`
- `--page <value>`：页码，从 1 开始
- `--page_size <value>`：每页数量，默认 20，最大 100
- `--profile <name>`：指定登录身份
- `--json`：以 JSON 格式输出

列表项包含 `id`、`company_id` 和公开追踪字段。`id` 可用于查询详情。

## 查询详情

```bash
mplus build traces show <id>
```

详情只返回公开追踪字段，不返回 `id`、`company_id`、创建时间、更新时间等内部字段。
