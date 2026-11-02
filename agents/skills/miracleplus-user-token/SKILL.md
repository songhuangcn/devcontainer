---
name: miracleplus-user-token
description: 'MiraclePlus OAuth user access token 获取：使用 get_user_token.sh 为 prod 或 staging 创建用户 token，触发词包括 MiraclePlus token、get_prod_user_token.sh、创建 token、生产/测试环境 token'
license: MIT
allowed-tools: Bash, Read
---

# MiraclePlus User Token

## Overview

用于通过 OAuth authorization_code + PKCE 流程，为 MiraclePlus 生产或 staging 环境获取绑定当前用户身份的 `access_token`。

脚本位于本 skill 目录：`scripts/get_user_token.sh`。

## Environments

| 环境 | 参数 | Base URL |
|------|------|----------|
| 生产 | `prod` | `https://build.miracleplus.com` |
| Staging | `staging` | `https://build-staging.miracleplus.com` |

默认环境是 `prod`。

## Workflow

### 1. 运行脚本

生产环境：

```bash
/home/ubuntu/.agents/skills/miracleplus-user-token/scripts/get_user_token.sh prod
```

Staging 环境：

```bash
/home/ubuntu/.agents/skills/miracleplus-user-token/scripts/get_user_token.sh staging
```

也可以省略环境参数，默认使用生产环境：

```bash
/home/ubuntu/.agents/skills/miracleplus-user-token/scripts/get_user_token.sh
```

### 2. 让用户完成浏览器授权

脚本会打印授权链接。把链接发给用户，让用户在浏览器中打开、登录并授权。

授权后浏览器会跳转到 `http://localhost:9090/callback?...`，页面打不开是正常现象。请用户复制浏览器地址栏中的完整 URL 并发回。

### 3. 粘贴回调 URL

把用户给出的完整回调 URL 粘贴到脚本提示的 `请粘贴回调 URL:` 后，脚本会自动校验 `state`，并用授权码兑换 token。

### 4. 返回 token

脚本成功后会打印 `access_token`。只把 `access_token` 返回给用户即可，例如：

```bash
ACCESS_TOKEN=<token>
```

## Configuration

常用环境变量：

| 变量 | 说明 |
|------|------|
| `SCOPE` | OAuth scope，默认 `public` |
| `REDIRECT_URI` | 回调地址，默认 `http://localhost:9090/callback` |
| `CLIENT_ID` / `CLIENT_SECRET` | 覆盖当前环境 OAuth client 凭据 |
| `BASE_URL` | 覆盖当前环境 Base URL |
| `PROD_CLIENT_ID` / `PROD_CLIENT_SECRET` | 覆盖生产环境 OAuth client 凭据 |
| `STAGING_CLIENT_ID` / `STAGING_CLIENT_SECRET` | 覆盖 staging 环境 OAuth client 凭据 |

如果 staging 使用不同 OAuth app，应通过 `STAGING_CLIENT_ID` 和 `STAGING_CLIENT_SECRET` 提供对应凭据。

## Safety Notes

- 不要把 `access_token`、`refresh_token` 或 client secret 写入仓库。
- 如果用户只需要创建 token，不要修改业务代码。
- 若 token 接口返回错误，先检查环境、回调 URL、`state`、client 凭据和 redirect URI 白名单。
