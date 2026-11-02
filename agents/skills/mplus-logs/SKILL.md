---
name: mplus-logs
description: "奇绩创坛用户日志查询：查询用户行为日志和用户初始渠道来源信息。当用户需要查看某些 user_id 的访问/行为日志、追踪初始渠道来源时使用。"
metadata:
  requires:
    bins: ["mplus"]
---

# mplus logs

**开始前先读 [`../mplus-shared/SKILL.md`](../mplus-shared/SKILL.md)（认证、登录、全局参数）**

## 是什么

logs 对应数据日志服务，通过 `logs/open_api/v1/user_logs` 查询用户行为日志，以及通过 `logs/open_api/v1/user_logs/channels` 查询用户初始渠道来源。

需要服务端权限：`logs:mp_logs:read`。CLI 只按缓存权限控制 help 可见性，实际能否调用由服务端鉴权决定。

## 命令

```bash
mplus logs user-logs list --user-ids 123,456 --json
mplus logs user-logs list --user-ids 123 --start-date 2026-06-01 --end-date 2026-06-30 --json
mplus logs user-logs channels --user-ids 123,456 --json
```

## 参数

- `--user-ids <value>`：必填，用户 ID 列表，英文逗号分隔
- `--start-date <value>`：可选，开始日期，格式 `YYYY-MM-DD`，仅 `list` 支持
- `--end-date <value>`：可选，结束日期，格式 `YYYY-MM-DD`，仅 `list` 支持
- `--output-schema <value>`：可选，JSON 格式字段过滤配置，仅 `list` 支持
- `--json`：建议使用，输出结构化 JSON
- `--profile <name>`：指定登录身份
