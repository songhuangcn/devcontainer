---
name: mplus-shared
description: "奇绩创坛 CLI 共享基础：安装、OAuth 登录、两段式 AI Agent 登录、登录状态验证、profile/session 管理、全局输出和错误处理。当用户首次使用 mplus CLI、需要登录或重新授权、遇到鉴权错误、验证当前身份、或切换环境和账号时触发。"
metadata:
  requires:
    bins: ["mplus"]
---

# mplus CLI 共享规则

奇绩创坛命令行工具，用于与 apply.miracleplus.com 和 build.miracleplus.com 交互。

详细帮助：`mplus --help`，各子命令：`mplus <命令> --help`

## 安装

```bash
npm install -g @miracleplus/mplus@latest
```

## 检查登录状态

```bash
mplus whoami --json   # 请求服务端验证，返回当前用户身份和角色
mplus status --json   # 仅检查本地 session，不请求服务端
```

## 人类在桌面终端登录

```bash
mplus login
```

自动打开浏览器完成 OAuth 授权。

## AI Agent 两段式登录

**必须跨两个对话轮次执行，不要在同一轮连续执行。**

### 第一轮：发起授权

```bash
mplus login --no-wait --json
```

从输出中提取 `verification_uri_complete`，将链接展示给用户，告知在浏览器完成授权后回复"已授权"。然后结束本轮，**不要立即执行第二步**。

### 第二轮：完成登录（仅在用户回复已授权后）

```bash
mplus login --continue
mplus whoami --json
```

## 多环境与多账号

```bash
mplus login --env staging          # 登录测试环境
mplus login --name <名称>          # 指定登录身份名称
mplus profiles                     # 列出所有已保存身份
mplus profiles switch <名称>       # 切换身份
mplus whoami --profile <名称>      # 临时用指定身份查询，不改变当前身份
```

## 全局参数

所有业务命令支持：
- `--json`：结构化输出，脚本和 AI Agent 使用时始终加此参数
- `--profile <名称>`：临时切换身份，不改变当前登录状态
- `--debug`：输出详细 HTTP 请求日志，排查问题用
