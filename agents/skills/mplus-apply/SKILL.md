---
name: mplus-apply
description: "奇绩创坛 Apply 申请系统数据查询与操作：管理批次、申请表、人脉（联系人）、企微渠道用户、面试安排、团队人员与系统角色、统计报表和奇绩创业公开课数据。支持搜索申请、批量获取申请详情 Markdown、搜索/新建/更新人脉、搜索企微用户汇总、查询面试安排列表与详情（空闲时段/已预约时段）、查询团队管理人员与系统角色变化审计报表、查询渠道统计数据、查询公开课课程/课节/学习记录/申请列表。当用户需要查找申请项目、了解人脉信息、搜索企微用户、查看面试排期、盘点人员权限与系统角色、统计渠道来源或查看公开课数据时使用。"
metadata:
  requires:
    bins: ["mplus"]
---

# mplus apply

**开始前先读 [`../mplus-shared/SKILL.md`](../mplus-shared/SKILL.md)（认证、登录、全局参数）**

## 是什么

apply 对应 apply.miracleplus.com，是奇绩创坛的申请招募系统，仅限管理员使用。包含以下数据：

- **batches**：创业营批次，一年两次（春季/秋季）
- **applications**：创业项目申请表，含申请全文 Markdown、评审记录
- **contacts**：申请系统沉淀的人脉/线索，支持搜索、新建、更新、批量打标签、批量查重
- **channel-users**：企业微信渠道用户（Soc::ChannelUser），可按企微标签、负责员工、申请进度筛选
- **interview-slots**：面试安排（面试时段），可按日期区间、申请、类别、是否可预约/已预约筛选，含已预约申请的摘要信息
- **teams**：团队管理人员与系统角色，含任职状态、飞书绑定、系统角色、团队归属，以及角色变化审计报表
- **reports**：运营统计，分手机号人脉（contacts）和企微用户（soc-channel-users）两类
- **startup-schools**：奇绩创业公开课数据，包括课程学习统计、课程、课节、问题反馈、学习记录和公开课申请列表

startup-schools 子命令按服务端权限动态显示：

- `analytics`：`apply:courses:analytics`
- `courses`：`apply:courses:read`
- `lessons`：`apply:courses:show`
- `feedbacks`：`apply:courses:feedback`
- `lesson-records`：`apply:courses:lesson_record`
- `applications`：`apply:startup_school:read`

## 查看帮助

```bash
mplus apply --help                        # 查看所有子命令
mplus apply applications --help           # 查看具体子命令参数
mplus apply startup-schools --help        # 查看公开课相关子命令
mplus apply interview-slots --help        # 查看面试安排相关子命令
mplus apply teams --help                  # 查看团队人员与系统角色相关子命令
```

详细参数文档见 `references/` 目录下各 .md 文件。
