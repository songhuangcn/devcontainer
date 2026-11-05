---
name: mplus-admission
description: "奇绩创坛 Admission 数据查询：创业项目申请材料与面试材料（startup-projects）、项目标签（project-labels）、模型打分 session 与 feature 分数（scoring-sessions / scoring-features / scoring-batches）、prompt-eval 宽表。当用户需要查看申请数据、打分结果、项目标签或 prompt-eval 数据时使用。"
metadata:
  requires:
    bins: ["mplus"]
---

# admission

**开始前先读 [`../mplus-shared/SKILL.md`](../mplus-shared/SKILL.md)（认证、登录、全局参数）**

## 是什么

admission 是奇绩创坛的申请评审模块，仅限管理员使用。包含以下数据：

- **startup-projects**：创业项目记录，包含申请材料（application_content）和面试材料（interview_content）
- **company-invests**：项目融资信息（`apply_company_invests`，按 application_id 关联申请；顶层 `invest_*` 为最近一次融资，`invests` 为历史融资记录数组）
- **project-labels**：事后人工确认的标签（如 `moic`、`tier`、`interview_conclusion`）
- **scoring-sessions / scoring-features / scoring-batches**：模型对项目的打分结果
- **prompt-eval**：申请维度和创始人维度的 feature 宽表

project-labels 是人工事后标注的，scoring-sessions 是模型运行时生成的，两者口径不同，不要混用。

## 批次命名格式

格式 `<YY><季节>`，全小写。季节：`s`=春季批、`a`=秋季批。  
例：`25s`=2025春、`25a`=2025秋、`26s`=2026春

## 查看帮助

```bash
mplus admission --help                        # 查看所有子命令
mplus admission startup-projects --help       # 查看具体子命令参数
```

详细参数文档见 `references/` 目录下各 .md 文件。
