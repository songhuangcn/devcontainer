---
name: mp-oauth-skill
description: 'MiraclePlus OAuth access token 获取：使用公开 OAuth client 和 Device Flow 为 prod 或 staging 创建用户 token；当用户提到 MP OAuth、MiraclePlus token、创建 access token、生产或测试环境 token 时使用。不依赖 mplus-cli，不需要 client secret。'
license: MIT
allowed-tools: Bash, Read
---

# MP OAuth Token

## Overview

通过 MiraclePlus 的公开 OAuth client 和 OAuth 2.0 Device Authorization Grant 获取绑定当前用户身份的 `access_token`。本 skill 不依赖 `mplus-cli`，不包含也不使用 `client_secret`。

脚本位于本 skill 目录：`scripts/get_user_token.sh`。

## Prerequisites

运行环境需要：

- `bash`
- `curl`
- `jq`（用于可靠地解析和生成 JSON）

## Environments

| 环境 | 参数 | OAuth Endpoint |
|---|---|---|
| 生产 | `prod` | `https://apply.miracleplus.com` |
| Staging | `staging` | `https://apply-staging.miracleplus.com` |

默认环境为 `prod`。

## Workflow

### 1. 发起登录

生产环境：

```bash
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh prod start
```

Staging 环境：

```bash
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh staging start
```

脚本会输出 `verification_uri_complete`。将该链接发给用户，请用户在浏览器中登录并授权。授权链接通常在 5 分钟内有效。

### 2. 等待用户确认

停止当前执行流程，等待用户明确回复“已授权”或同等含义。不要在用户确认前运行 `continue`。

### 3. 换取 token

用户确认后，对同一环境运行：

```bash
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh prod continue
```

或：

```bash
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh staging continue
```

成功时 stdout 只输出一行：

```text
ACCESS_TOKEN=<token>
```

将这一行返回给用户。不要把 token 写入仓库、文档、日志或其他持久化文件。

## Commands

```bash
# 查看帮助
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh --help

# 发起生产环境授权（默认命令为 start）
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh prod

# 查看待处理授权的状态
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh prod status

# 取消并删除待处理授权
~/.agents/skills/mp-oauth-skill/scripts/get_user_token.sh prod cancel
```

## Configuration

| 环境变量 | 说明 |
|---|---|
| `SCOPE` | OAuth scope，默认 `public` |
| `BASE_URL` | 覆盖 OAuth endpoint，供调试或私有部署使用 |
| `CLIENT_ID` | 覆盖公开 OAuth client ID；它不是 secret |
| `MP_OAUTH_HOME` | 待处理 Device Flow 状态目录，默认 `~/.config/mp-oauth-skill` |

禁止添加、读取或发送 `CLIENT_SECRET`。公开客户端依靠用户授权、短期 `device_code` 和服务端轮询约束保护登录流程。

## Safety Rules

- 只在用户明确要求创建 token 时启动授权。
- 授权环境不明确时，默认使用生产环境；用户明确提到测试环境时使用 `staging`。
- 不要展示或返回 `device_code` 之外的本地状态文件内容。
- `continue` 成功后脚本会删除待处理状态，且不会持久化 access token 或 refresh token。
- 如果授权过期，重新运行 `start`，不要复用旧 `device_code`。
- 不要提交 token、状态文件或任何用户认证信息。
