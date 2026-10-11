# .autoteam

这个目录定义了本仓库的自管理 agent 团队，由 [autoteam](https://github.com/autoteam-ai/autoteam) 生成。
整个目录受 CODEOWNERS 保护，修改走 PR，由人批准。

| 文件 | 作用 |
|---|---|
| `autoteam.conf` | 仓库、负责人、Multica 工作区、各种上限、autopilot 的定时（`AUTOTEAM_CRON_*`） |
| `registry.yaml` | 计费注册表 + 团队清单：有哪些 agent、什么角色、用哪个账号、跑在哪个 runtime |
| `playbook.md` | 本项目的经验库，Planner 每次开工必读 |
| `scripts/loop-guard.sh` | 统计打回和验收不通过的次数，判断是否升级给人 |
| `scripts/merge-mode.sh` | 判断这个 PR 由谁放行、由谁合并（platform / staged / reviewer） |
| `scripts/merge-status.sh` | 核对 PR 的自动合并是否真的开了（merged / queued / auto / none） |
| `scripts/open-pr.sh` | Implementer 交付用：开 PR、按合并模式开自动合并并核对（返工时只核对、补开） |
| `scripts/protected-paths.sh` | 按 CODEOWNERS 与 lock 文件判断受保护路径；命中返回 0，未命中返回 1，出错返回 2 |
| `scripts/health-metrics.sh` | 代码健康指标，Auditor 每周用 |
| `.lock.json` | 装机版本和每个文件的 sha256，`autoteam upgrade` 靠它判断哪些文件你改过；要入库 |
| `local/` | 本机私钥等，不入库 |

## 角色指令默认不在这里

四个角色的指令、autopilot 的 runbook、`planner-mcp.json` **不落盘**：`autoteam multica --apply` 直接读 autoteam 包内的版本，升级 autoteam 就升级了它们。

想按本项目改某一份，就 eject 出来自己维护：

```bash
autoteam eject reviewer          # 角色名、autopilot 名（如 patrol）、planner-mcp.json，或 --all
autoteam eject --diff reviewer   # 只看包内版本和你 eject 的那份有什么差异，不写文件
```

文件会落在 `instructions/` 下（`instructions/roles/reviewer.md`、`instructions/autopilots/patrol.md`）。
落盘就表示“我有意改过”：此后读取优先用这一份，升级不会覆盖，包内的新版本要自己用 `eject --diff` 对比、手动合并。
删掉这份文件，就回到包内版本。

改了 registry、autopilot 或 eject 的指令，合并到默认分支后运行：

```bash
autoteam multica --apply   # 同步到 Multica
autoteam doctor            # 逐项检查，能发现 Multica 里的指令和生效文本不一致
```
