---
name: miracleplus-context
description: 'MiraclePlus（奇绩创坛）项目上下文与个人开发约定。当前工作目录或任务目标位于 miracleplus/ 目录及其任意子目录（如 ~/workspace/miracleplus/、/workspace/miracleplus/），或属于这些仓库的 worktree 时，处理任何项目任务前都必须加载，即使用户未提及 MiraclePlus 或 MP。涵盖开发、排错、测试、重构、代码审查、文档维护及部署验证；其中 MP 容器、staging 与共享 UI 规则仅适用于 mp 仓库，不套用于同目录其他项目。'
license: MIT
allowed-tools: Read, Glob, Grep, Bash
---

# MiraclePlus 项目上下文

## 使用流程与范围

1. 根据当前工作目录、用户指定的目标路径和仓库身份确认项目；不能只依赖用户是否提及 MiraclePlus。在其他目录操作 `miracleplus/` 下项目，或使用对应仓库的 worktree 时，也要加载本技能。
2. 先读取目标项目自身的 `AGENTS.md` 等规范；本技能记录个人补充约定，不替代团队规范。软件开发任务同时遵守 `development` skill。
3. 按实际仓库应用下面的规则：仅 MP 仓库使用 MP 专属约定；`miracleplus/` 下其他项目遵循各自配置，不假定它们使用 Rails、相同的 Compose 服务、staging 域名或共享 UI。
4. 本技能不额外授权提交、推送、cherry-pick、部署或修改线上数据；这些操作仍以用户请求为准。

## MiraclePlus (mp)

以下仅适用于 `~/workspace/miracleplus/mp`（容器中为 `/workspace/miracleplus/mp`）仓库及其 worktree（个人偏好，未纳入团队 `AGENTS.md`）。

### 容器环境

用根目录 `compose.yml`；`.devcontainer/docker-compose.yml` 只给 devcontainer 内部用（PG15、端口未暴露），不要拿它跑测试。

**`rails` / `rspec` 一律在容器里跑，不要在 host 上跑。** `.env.docker` 已提供 `SECRET_KEY_BASE` / `DATABASE_HOST` / `REDIS_HOST`，无需手工 export。

```bash
docker compose up -d db redis
make rspec                    # 全量测试；单文件用 make rspec OPTS=path/to/_spec.rb
make test-db-setup-docker     # 重建测试库
```

原因：`node_modules` 是在 linux 容器里 `yarn install` 的，只有 `@rolldown/binding-linux-*`。macOS host 缺 darwin binding，Vite 构建必失败，所有渲染 `vite_javascript_tag` 的 spec 都会挂，与被测代码无关。

镜像里装的是 PGDG 的 `postgresql-client-17`，不是 Debian 自带的（bookworm 上是 15）：schema 是 `:sql` 格式，`db:schema:load` / `db:migrate` 依赖 psql 和 pg_dump，而 pg_dump 拒绝导出比自己新的服务端。改完 Dockerfile 需 `docker compose build web-apply web-accelerator` 才生效。

两个坑：

- `rails db:migrate` **结尾一定会重新 dump `structure.sql`**，即使没有待跑迁移。
- 仓库里的 `structure.sql` 是在 PG≤16 上生成的，而 compose 的 db 是 pg17，重新 dump 会带出 `CHECK ... ANY (ARRAY[...])` 这类渲染差异（还有个别外键缺注释头、排序错位）。提交前要剔掉，只留自己迁移产生的部分。

### staging 验证

staging 环境**会定期重制成 master 分支**，所以：staging 上的分叉（`AGENTS.md` 章节结构、`db/structure.sql` 缺列/缺迁移版本号）一律不要去修，把改动 cherry-pick 上去验证完就行。

- 域名：accelerator 是 `build-staging.miracleplus.com`，apply 是 `apply-staging.miracleplus.com`。
- **Actions 显示成功 ≠ 新代码已生效。** 部署 workflow 只发 `aws ecs update-service --force-new-deployment` 就结束，不等 `services-stable`。ECS 滚完还要几分钟，急着开页面看到的是旧版本。
  ```bash
  aws ecs wait services-stable --cluster mp-staging-ECSCluster --services mp-staging-accelerator
  # 或直接看：旧 deployment 的 runningCount 归零即可
  aws ecs describe-services --cluster mp-staging-ECSCluster --services mp-staging-accelerator \
    --query 'services[0].deployments[].{status:status,running:runningCount,rollout:rolloutState}' --output table
  ```
  ECS 服务名是 `mp-staging-accelerator` / `mp-staging-apply`（不是 `mp-staging-web`）。
- 本地跑 staging 分支的 spec 前要重建测试库；若报 pending migration 或缺列，是 staging 的 `structure.sql` 漂移，**在测试库里手工补**（补 `schema_migrations` 版本号 / `ALTER TABLE` 补列），不要改仓库文件。
- 浏览器验证时，带 `data-confirm` 的按钮会弹原生 `confirm()`，把 CDP 卡死。直接带 CSRF token 打接口更快：
  ```js
  fetch(path, { method: 'POST', headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content }, credentials: 'same-origin' })
  ```
- 验证产生的测试数据（上传的文件、填充的字段）**验完要删干净**。

### 共享 UI（Tailwind 4，费用管理起）

组件在 `app/helpers/ui_helper.rb` + `app/views/shared/ui/`，预览页 `/ui_kit`（仅 dev/test）。团队规范 `docs/specs/ui-design.md` 不改，这里是它没覆盖部分的补充（数值取自设计稿「组件规范」）。

- 类名一律 `tw:` 前缀且必须是完整字面量，helper 里用映射表不拼接。**同一元素别放冲突的工具类**（如 `cursor-pointer` + `cursor-not-allowed`）：谁生效由 Tailwind 的排序决定而不是书写顺序，且不会报错。
- 颜色只用 `tokens.css` 令牌；透明度写 `tw:bg-success/12`，中性描边用 `tw:border-body/25`（设计稿的 `#d4dee9` 不是令牌）。新增用到 Tailwind 类的目录要在 `ui.css` 登记 `@source`。
- **Vite test 构建只监视 `app/frontend`**：只改了 haml / helper 里的类名时，system spec 用的还是旧 CSS。先删 `tmp/cache/vite/last-build-test.json`（python `os.remove`），首次构建要几分钟。
- system spec 里页面 locale 跟浏览器走（无头 Chrome 是英文），按中文文案找元素要 `visit path(locale: 'zh-CN')`；Selenium 的 `css_value` 把不透明色回成 `rgba(r, g, b, 1)`。
- 数据表格：表头 13/500 label + head 底；单元格 14 label、内边距 12×14；数字列右对齐 + tabular-nums；首列 sticky（高亮行用渐变叠白底，保证 sticky 格不透明）；「将到期」行 lemon/6；合计行 head 底；操作列 nowrap。
- tabs 是链接：当前项 ink/500 + 2px brand 下划线，其余 body/400。
- 表单：控件高 38、圆角 4、边框 line；聚焦 brand 边框 + 2px sky outline；错误 ruby 边框 + 13px ruby 提示；提示 12px body；必填星号 ruby；`ui_field` 接好 `aria-describedby` / `aria-invalid`。
- 状态徽标 = 彩色圆点 + 深色文字 + 浅色底（不只靠颜色）；空状态 = 40px 图标 + 16/500 标题 + 14 body 说明 + 可选操作，放卡片里。
- 弹窗用原生 `<dialog>` + Stimulus `ui-dialog`（宽 480、sm 360，圆角 8，`shadow-dialog`，遮罩 ink/50），不用 `window.confirm`。
- 链接与按钮文字用 `#0a6feb`，不用 `#0884ff`（白底对比度不足）。
