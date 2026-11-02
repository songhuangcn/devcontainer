---
name: mplus-news
description: "奇绩创坛 News（齐思）数据查询：获取每日 Twitter 爬取内容，支持按日期分页查询，含 GPT 洞见评分和话题标签。当用户需要获取齐思 Twitter 内容、查询每日推文、获取洞见摘要时使用。"
metadata:
  requires:
    bins: ["mplus"]
---

# mplus news

**开始前先读 [`../mplus-shared/SKILL.md`](../mplus-shared/SKILL.md)（认证、登录、全局参数）**

## 是什么

齐思（news.miracleplus.com）的 Twitter 内容查询，仅限管理员使用。每日自动爬取 Twitter 内容，含 GPT 生成的洞见评分（score、summary、中文分析）。`date` 参数按 Asia/Shanghai 自然日过滤。

## 查看帮助

```bash
mplus news --help
mplus news twitter --help
```

详细参数文档见 `references/` 目录下各 .md 文件。
