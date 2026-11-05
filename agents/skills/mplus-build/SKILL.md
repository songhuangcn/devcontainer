---
name: mplus-build
description: "奇绩创坛 Build 数据查询：公司列表与详情及追加投资投票快照（companies）、用户全链路生命周期（user_lifecycle）、创业营作业文档（camp_documents）、公司作业与录音（camp_tasks / office_hour_recordings / articles）、校友追踪（traces）、财务数据（finance）、大力点评投资人系统（funds / fund_investors / fund_investor_reviews）、微信小程序活动与报名审核（wechat_activities / wechat_activity_signups）。当用户需要查看公司资料、某人全链路状态、作业文档、Office Hour 录音、校友公司追踪、财务数据、投资人评价，或管理小程序活动、审核活动报名（如产品日嘉宾初筛）时使用。"
metadata:
  requires:
    bins: ["mplus"]
---

# mplus build

**开始前先读 [`../mplus-shared/SKILL.md`](../mplus-shared/SKILL.md)（认证、登录、全局参数）**

## 是什么

build 对应 build.miracleplus.com，有两大功能：对奇绩管理员是投后管理平台；对校友（奇绩被投企业创始人）是校友网络，包含知识库、论坛、创业者互推、社区优惠（校友间的折扣与互助）、大力点评（校友点评投资人）。

- **companies**：公司列表与详情，支持按批次、申请表 ID、城市、名称关键词过滤列表，并按公司 ID 或 slug 查询详情，也支持查询追加投资投票快照
- **user_lifecycle**：以"人"为中心的全链路聚合视图，按 user_id 查询，覆盖人脉、申请、尽调、评估、入营、微信、推荐、财务、融资全链路。与 `mplus apply`（以"申请"为中心）互补
- **camp_documents**：创业营作业文档（Markdown 快照，来自飞书定期同步；`internal` 类型不可通过 API 获取）
- **camp_tasks / office_hour_recordings / articles**：公司维度嵌套资源，`companyId` 是必填位置参数，格式固定为 `build <模块> list <companyId>`
- **traces**：校友追踪记录，支持按关键词、批次名称、公司 ID 查询列表，并按追踪记录 ID 查询公开字段详情
- **finance**：财务数据，包含现金流、公司财务基础信息、融资轮次、投资信息、投资进展、季度报告、同步记录、团队标签和公司财务汇总
- **funds / fund_investors / fund_investor_reviews**：大力点评系统，三层结构——投资机构 → 投资人 → 创业者评价；评价只能改/删自己创建的
- **wechat_activities / wechat_activity_signups**：微信小程序活动管理与报名审核（活动增改、报名列表筛选、通过/拒绝/确认、写备注），详见 [`references/build-wechat-activities.md`](references/build-wechat-activities.md)

## 查看帮助

```bash
mplus build --help                        # 查看所有子命令
mplus build user_lifecycle --help         # 查看具体子命令参数
```

详细参数文档见 `references/` 目录下各 .md 文件。
