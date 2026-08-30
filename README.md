# Workspace

这个仓库提供一个纯 Docker 的长期开发工作区，用于在可复现环境中运行 OpenCode 和 Multica daemon。

## 内容

- `docker-compose.yml`：用共享 base 配置分别启动 `opencode`、`multica`，并启动 Docker-in-Docker service `docker`。
- `Dockerfile`：构建开发工具镜像，内置 OpenCode、常用 CLI、Docker CLI、Compose plugin 和论文输出工具链。
- `devcontainer.json`：仅作为 VS Code 快速打开入口，不再使用 devcontainer features。
- `scripts/setup.sh`：创建 `.env`，并预建 `./data` 下 config 嵌套挂载所需的父目录。
- `dockerfiles/Dockerfile.java`：Java 扩展镜像。

## 镜像

CI 发布以下镜像：

- `songhuangcn/devcontainer:latest` / `songhuangcn/devcontainer:commit-<short-sha>`
- `songhuangcn/devcontainer-java:latest` / `songhuangcn/devcontainer-java:commit-<short-sha>`

`songhuangcn/devcontainer` 虽然保留原名称，但现在是纯 Docker 镜像，不依赖 devcontainer feature，并已包含 LaTeX/PDF、Pandoc DOCX、CJK 字体和 PDF 检查工具。

Java 镜像预装的 VS Code Server 默认版本由 `dockerfiles/vscode.java.version` 定义。Java 镜像还会发布按 VS Code 版本命名的标签，可以直接拉取指定版本：

```bash
docker pull songhuangcn/devcontainer-java:vscode-1.135.0
```

`vscode-<version>-repo-<short-sha>` 同时锁定 VS Code 版本和本仓库构建版本。手动运行 `build-devcontainer-java` workflow 时，可以通过 `vscode_version` 输入临时构建其他稳定版；非默认版本不会更新 `latest` 和 `commit-*` 标签。

Java 镜像的 VS Code Server 装在 `/opt/vscode-server`（不在 `~/.vscode-server`），首启时由 ENTRYPOINT `devcontainer-home-init` 在 home 卷里建软链指回去，556 MB 不进卷。因此挂一个已有的 home 卷不再会遮住预装的 server。

注意：devcontainer CLI 在 `overrideCommand: true`（image/dockerfile 型 devcontainer 的默认值）时会覆盖镜像 ENTRYPOINT，软链就不会建，VS Code 会自己重新下载一份 server——功能不丢，只是慢。需要的话在消费方的 `devcontainer.json` 里加 `"postCreateCommand": "/usr/local/bin/devcontainer-home-init"` 兜底。

## 前置依赖

只需要 Docker 和 Docker Compose：

```bash
docker --version
docker compose version
```

不再需要安装 `devcontainer` CLI。

## 本地使用

首次启动前创建 `.env` 和必需的持久化路径：

```bash
make setup
```

`make setup` 会在缺失时从 `.env.sample` 创建 `.env`，并预建 `./data/.claude`、`./data/.codex`、`./data/.config/opencode`。这三个目录是 `./config` 那四条嵌套挂载的父目录：缺失时 Docker daemon 会以 root 身份创建挂载点父目录，容器内的 `ubuntu` 用户就写不进去。

必需存在的只有 `.env` 和上面那三个目录。如果不想运行 `make setup`，也可以手动创建。OpenCode、Git、Claude 和 Codex 的可共享配置位于 `./config`，随版本库提供。

`docker-compose.yml` 把 `./data` 整挂到 `/home/ubuntu`。镜像自带的工具链装在 `/opt`（`/opt/mise`、`/opt/agent-bin`、`/opt/home-skel`），不会被这个卷遮住，所以新增工具不再需要补挂载。首次启动时镜像的 ENTRYPOINT `devcontainer-home-init` 会把 `/opt/home-skel` 补进卷里——只补缺失项，`./data` 里已有的文件（包括你自己改过的 `.bashrc`、`.profile`）永远不会被覆盖。这也意味着镜像升级带来的 `.bashrc` 改动不会推送给已有的 `./data`。

`~/.local/bin` 在 login shell 中排在镜像工具链之前（Ubuntu `.profile` 的默认行为），所以 `pip install --user`、`uv tool install`、`pipx` 装的工具会盖过镜像自带的同名命令。Docker Compose plugin 的系统级入口位于 `/usr/local/lib/docker/cli-plugins/docker-compose`。

启动容器、OpenCode Web 和 Multica daemon：

```bash
make start
```

OpenCode Web 默认地址为 `http://localhost:4096`。

进入容器：

```bash
make bash
```

查看日志：

```bash
make logs
```

停止容器：

```bash
make stop
```

拉取最新镜像并重启：

```bash
make update
```

本地构建运行镜像：

```bash
make build
```

## 一次性数据迁移（从旧的 21 条选择性挂载切到整挂 home）

只在从旧布局切过来时做一次，做完就不用再看这一节。策略是**两侧都从空目录开始，
只把凭据白名单捞过来**，旧数据完整保留作为退路。

先停容器并备份（`cp -Rpc` 在 APFS 上是 clone，瞬时完成且保住权限位）：

```bash
make down
cp -Rpc data ../devcontainer-data-backup-$(date +%F)
mv data data.old && mkdir data
```

**必须先 `make down`**：`opencode.db` 是 WAL 模式，运行中拷贝会拿到不一致的快照。

用 `tar -T` 按清单捞（不要用 macOS 自带的 `rsync`——它其实是 openrsync，
`--files-from` 不递归子目录，还会把 `.ssh` 的 700 放宽成 755）：

```bash
cat > /tmp/dc-migrate.list <<'LIST'
.agents
.claude
.claude.json
.codex/auth.json
.codex/config.toml
.codex/history.jsonl
.codex/memories_1.sqlite
.codex/sessions
.codex/skills
.config/gh
.config/opencode/.gitignore
.config/opencode/AGENTS.md
.config/opencode/package.json
.config/opencode/package-lock.json
.copilot
.lark-cli/config.json
.multica/config.json
.multica/daemon.id
.ssh
multica_workspaces
LIST

tar -C data.old --exclude '.DS_Store' -cf - -T /tmp/dc-migrate.list | tar -C data -xpf -

# 清单里只列了 .lark-cli/config.json 这一个文件，父目录是 tar 用默认权限
# 补出来的（755），补回原来的 700
chmod 700 data/.lark-cli
```

另外两处路径要改（旧布局把它们放在 `data/` 顶层，新布局回到 `~/.local/share`）：

```bash
mkdir -p data/.local/share/lark-cli data/.local/share/opencode

# master.key 丢了，两个 .enc 就永久解不开
tar -C data.old/lark-cli --exclude '.DS_Store' -cf - .   | tar -C data/.local/share/lark-cli -xpf -

# opencode.db 是 WAL 模式，三个文件必须一起拷
cat > /tmp/dc-migrate-opencode.list <<'LIST'
auth.json
opencode.db
opencode.db-shm
opencode.db-wal
storage
snapshot
worktree
repos
LIST
tar -C data.old/opencode --exclude '.DS_Store' -cf - -T /tmp/dc-migrate-opencode.list   | tar -C data/.local/share/opencode -xpf -
```

**刻意不捞**：`.cache`、`.npm`、`.vscode-server`（VS Code 会自己重下）、`.local`
（旧 mise 死数据）、`.claude.0801`、`.claude.json.0801`、`claude-backup-*.tar.gz`、
`.gitconfig`（被 `config/.gitconfig` 遮住，且含 macOS 专用的 `hooksPath` 和已失效的
credential helper）、`.config/{configstore,libreoffice,matplotlib,mplus,openspec}`、
`.codex/{logs_2.sqlite*,cache,tmp,shell_snapshots}`、`opencode/opencode.db.bak-1.18.9`
（1.5G 的旧备份）、`opencode/log`、`.bash_aliases`。

然后正常启动并逐项验证登录态：

```bash
make setup && make start
docker compose exec opencode bash -lc 'smoke-agent-cli-launchers; command -v mise; ls -A ~ | head -30'
docker compose exec opencode stat -c "%a %n" /home/ubuntu/.ssh /home/ubuntu/.ssh/id_rsa
```

`.ssh` 应为 `700`、`id_rsa` 应为 `600`。再确认嵌套挂载没有被卷里的旧文件顶掉——
四个文件的大小应等于 `config/` 下的对应文件，`mount` 输出里 `/home/ubuntu` 在前、
四个文件在后：

```bash
docker compose exec opencode sh -c 'stat -c "%n %s" ~/.gitconfig ~/.claude/settings.json ~/.codex/config.toml ~/.config/opencode/opencode.jsonc; echo ---; mount | grep /home/ubuntu'
```

最后逐项过一遍：`ssh -T git@github.com`、`gh auth status`、`claude` 读得到登录态、
`codex` 起得来、OpenCode Web 看得到历史会话、`multica auth status`、lark CLI 解得开
`.enc`。全部无误后再删 `data.old`；`../devcontainer-data-backup-*` 留久一点。
漏捞了随时从这两处补。

## Multica daemon

镜像通过 Multica 官方安装脚本安装最新 CLI，daemon 在独立的 `multica` service 中以前台模式运行。首次启动时，如果持久化目录中还没有登录态，会使用 `.env` 中的 `MULTICA_TOKEN` 自动登录：

```bash
make setup
make start
```

请先从 `.env.sample` 复制 `.env` 并填写 `MULTICA_TOKEN`。登录态保存在 `./data/.multica`，任务目录保存在 `./data/multica_workspaces`；不要提交 `.env`。`docker-compose.yml` 还固定了官方支持的 `MULTICA_DAEMON_ID` 和 `MULTICA_DAEMON_DEVICE_NAME`：前者复用已有 agent 绑定的 runtime 身份，后者避免容器重建后显示随机 hostname。只有部署完全独立的另一套本地实例时才在 `.env` 中同时覆盖这两项，并为 ID 使用新的 UUID。常用命令：

```bash
make multica.status
make multica.logs
make multica.restart
make multica.stop
make multica.smoke
make agent-cli.smoke
```

`make agent-cli.smoke` 会在空白临时目录中按 Multica daemon 使用的方式解析并执行 Codex、Claude 和 OpenCode，防止 provider 命令错误落到 mise task runner。验证时先用 `make multica.status` 确认 runtime 在线，再从 Multica 触发一次真实 agent task。容器重启后，认证和 task workspace 会继续保留。

## Docker

- Docker daemon 由 `docker:28-dind` service 提供，两个应用 service 通过 `DOCKER_HOST=tcp://docker:2375` 连接。
- Docker 数据持久化在 `docker-data` volume。

## VS Code

VS Code 可以继续通过 `devcontainer.json` 快速打开工作区。这个文件只引用同一份 `docker-compose.yml`，不再声明任何 feature 或 lifecycle 回调。

## k3s 部署

`deploy/` 目录（风格参考 `yangcheng-team/eastar-price` 的 `deploy/`）把这个工作区部署为 k3s 上长期运行的个人云端实例：

- 集群：`oracle-arm1`（2 节点 k3s，Traefik + cert-manager + Sealed Secrets 均为集群已有组件），namespace `devcontainer`；OpenCode 使用 `https://ai.hdgcs.com`。
- 只有单一环境，不做 stg/prod 分层；根目录 `kustomization.yaml` 在 `deploy/` 基础资源之上生成工具配置。
- 存储：`workspace-pvc`（15Gi，空卷，不含本地历史数据）、`user-data-pvc`（20Gi，整个挂成 `/home/ubuntu`）、`docker-data-pvc`（15Gi，供 dind sidecar 用）。三者都用 `local-path` storageClass 并通过 `nodeSelector` 固定调度到 `arm1`。镜像自带的工具链在 `/opt`，不会被 home 卷遮住，所以新增工具不需要改 `volumeMounts`。`local-path` 的 `allowVolumeExpansion` 是 `false`，PVC 容量事后改不了，所以 20Gi 是一次给足的。
- **待办（2026-09-20 之后）**：旧的 `home-data-pvc`（8Gi）在切到整挂 home 时原封不动留着当退路，新卷跑稳几周后从 `deploy/pvc.yaml` 删掉并 `kubectl delete pvc home-data-pvc`。顺带还有一个更早遗留的 `openclaw-data-pvc` 可以一起回收。
- 配置：根目录 Kustomize overlay 从 `config/` 生成带内容哈希的 ConfigMap，挂载 OpenCode、Git、Claude 和 Codex 配置；配置变化会触发 Pod 滚动更新。
- 工具解析：mise 负责安装 provider CLI，但镜像会在 `/opt/agent-bin` 创建直达实际 CLI 的链接并置于 `/opt/mise/shims` 之前。Multica daemon 即使规范化可执行文件路径，也不会把 Codex 等 provider 错误启动成 mise task runner；可用 `smoke-agent-cli-launchers` 在任意空白目录复验。
- 首启初始化：两个应用容器都**只写 `args:`，不写 `command:`**。`command:` 会覆盖镜像 ENTRYPOINT `devcontainer-home-init`，首启就不会把 `/opt/home-skel` 补进空卷（后果不重：卷里少了 dotfiles，Java 镜像少了 vscode-server 软链，VS Code 自己重下）。`livenessProbe.exec.command` 不经过 ENTRYPOINT，不受影响。
- 鉴权：`opencode web` 使用 Sealed Secret 中的 `OPENCODE_SERVER_PASSWORD`（HTTP Basic Auth，用户名默认 `opencode`）。Multica 首次启动时使用同一 Secret 中的 `MULTICA_TOKEN` 自动登录，登录态持久化到 `user-data-pvc`。Secret 明文不在仓库里。
- Multica 身份：`multica` 容器显式设置 `MULTICA_DAEMON_ID` 为原 `devcontainer.cloud` runtime 的 ID，并固定 `MULTICA_DAEMON_DEVICE_NAME=devcontainer.cloud`。官方以 daemon ID 作为 runtime 去重键；Pod 名变化或 CLI 升级后会更新原 runtime，不会注册成 `app-<hash>-<suffix>` 新机器。该 ID 不是凭据，不要随镜像升级修改。
- Docker-in-Docker：`dind` 是同 Pod 内的特权 sidecar，`opencode` 和 `multica` 容器通过 `DOCKER_HOST=tcp://localhost:2375` 连接（和 compose 里的 `tcp://docker:2375` 不同，这里是同一个 Pod）。
- 探针：OpenCode 使用 `tcpSocket`，避免鉴权导致 HTTP 401。
- 数据迁移：切到 `user-data-pvc` 时，凭据是在集群内用一个同时挂了两个 PVC 的临时 Pod 从 `home-data-pvc` 捞过来的（白名单同「一次性数据迁移」那一节），老卷全程只读、不做任何修改。注意 `~/.local/share/lark-cli/master.key` 从来没有迁到集群，只在本地 `./data` 里有，要用 lark CLI 得单独上传。之后的更新走 CI，不再涉及手动数据迁移。

手动操作（需要本地 `kubectl` 已指向该集群、并安装 `kubeseal`）：

```bash
make deploy.config   # 预览根目录 kustomize overlay 渲染结果
make deploy.apply    # kubectl apply -k ./ 并等待 rollout
make deploy.status   # 查看 Pod/Service/Ingress/PVC
make deploy.logs     # 查看 opencode 容器日志
make deploy.bash     # 进入集群里的 opencode 容器
make deploy.multica-status  # 查询 daemon 状态
make deploy.multica-logs    # 查看 daemon 日志
```

Kubernetes Pod 内分别运行 `opencode` 和 `multica` 容器；Multica 认证和任务目录随整挂的 `user-data-pvc` 持久化。首次部署会使用 `MULTICA_TOKEN` 自动登录，之后可用 status 和 Runtimes 页面确认在线。

修改 `deploy/app-secret.yaml`（明文，已被 `deploy/.gitignore` 排除）后，用 `make deploy.encode` 重新生成 `deploy/app-sealed-secret.yaml`。

`.github/workflows/build-devcontainer.yml` 在构建镜像成功后会自动 `kubectl apply -k ./`，使用当次构建的 `commit-<short-sha>` 镜像 tag；所需的 `KUBECONFIG` secret 对应一个只在 `devcontainer` 命名空间内有权限的 ServiceAccount（非集群管理员凭据）。

## 本地数据

以下内容不会提交到 Git：

- `.env`
- `data/*`
- `agents/*`

凭证、历史记录和用户数据默认放在 `./data`，整个目录挂载为容器里的 `/home/ubuntu`。可提交的工具配置放在 `./config`，以嵌套挂载的方式覆盖 `./data` 中的对应文件。镜像自带的工具链在 `/opt`，不受这个卷影响。
