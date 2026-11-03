# Workspace

这个仓库提供一个纯 Docker 的长期开发工作区，用于在可复现环境中运行 OpenCode 和 Multica daemon。

## 内容

- `docker-compose.yml`：用共享 base 配置分别启动工作容器 `app`（SSH）、`opencode`、`multica`，并提供 Docker-in-Docker service `docker`。
- `Dockerfile`：只构建一个基础镜像，包含系统开发依赖、字体和论文输出工具链，仅复制 `entrypoint.sh`。
- `devcontainer.json`：仅作为 VS Code 快速打开入口（指向 `app` service），不再使用 devcontainer features。
- `scripts/setup.sh`：创建 `.env`，并预建 `./data` 下嵌套挂载所需的目录。
- `scripts/entrypoint.sh`：从 `/etc/skel` 补齐缺失的默认用户文件，然后执行容器命令。
- `scripts/install.sh`：容器启动后安装 mise、`config/mise.toml` 中的工具、Python 依赖、Multica 和 Autoteam 启动器。
- `config/`、`agents/`：纳入版本控制的工具配置、用户指令和 skills。
- `deploy/`：完整的 Kubernetes 部署配置，包括唯一的 `kustomization.yaml`。

## 镜像

CI 只发布主镜像：

- `songhuangcn/devcontainer:latest` / `songhuangcn/devcontainer:commit-<short-sha>`

`songhuangcn/devcontainer` 虽然保留原名称，但现在是纯 Docker 镜像，不依赖 devcontainer feature，包含 LaTeX/PDF、CJK 字体和 PDF 检查工具；Pandoc 等 mise 工具在启动后安装。

mise、OpenCode、Claude、Codex、Node、Python、GitHub CLI、Docker CLI、Compose plugin、Multica、Autoteam 等都由 `make install` 安装到用户 home。配置、安装脚本和 skills 不进入镜像，修改它们无需重新构建基础镜像。

## 前置依赖

只需要 Docker 和 Docker Compose：

```bash
docker --version
docker compose version
```

不再需要安装 `devcontainer` CLI。

## 本地使用

首次使用先准备配置、安装工具，再启动服务：

```bash
make setup
make install
make start
```

`make setup` 会在缺失时从 `.env.sample` 创建 `.env`，并预建 `./data/.agents`、`./data/.claude`、`./data/.codex`、`./data/.config/mise`、`./data/.config/opencode`，避免 Docker daemon 以 root 身份创建嵌套挂载需要的目录。启动服务前填写 `.env` 中的 `OPENCODE_SERVER_PASSWORD` 和 `MULTICA_TOKEN`。

`make install` 先启动 `app`，再执行 `docker compose exec -T app bash /opt/workspace/scripts/install.sh`。`scripts/` 是只读挂载，修改脚本后可直接重跑；不需要先启动 OpenCode 或 Multica。脚本串行安装用户工具，并建立 Compose plugin 入口及 Claude 的用户指令、skills 软链。Multica 和 Autoteam 启动器固定版本/提交，校验 SHA-256 后才替换已有文件。

`docker-compose.yml` 把 `./data` 整挂到 `/home/ubuntu`，再用 `./config` 的文件和 `./agents` 目录覆盖对应路径。默认用户文件直接从 `/etc/skel` 补齐，只补缺失项，已有 `.bashrc`、`.profile` 永远不会被覆盖。`install.sh` 创建 `~/.claude/CLAUDE.md -> ../.agents/AGENTS.md` 和 `~/.claude/skills -> ../.agents/skills`；如目标原先是实体文件或目录，会先保留为同名的 `.before-agents-link`。

mise、Multica 和 Autoteam 启动器安装在 `~/.local/bin`；mise 使用默认的用户数据、缓存、状态目录，不设置 `MISE_*` 环境变量或专用 provider 目录。Compose plugin 位于 `~/.docker/cli-plugins/docker-compose`。这些内容随 home 持久化，由用户自行管理。

OpenCode 和 Multica 服务通过 login shell 执行 `mise exec -- …`，使用真实工具路径而不是 mise shim；`make bash` 也会进入 mise 工具环境。普通 SSH shell 可运行 `mise exec -- <命令>`，或自行在 `~/.bashrc` 配置 `eval "$(mise activate bash)"`；安装脚本不会修改用户 shell 配置。

只启动 SSH 工作容器时可用 `make dev`；需要工具时再执行 `make install`。`config/mise.toml` 与其他配置一样，挂载到用户默认路径 `~/.config/mise/config.toml`；修改版本后直接 `make install` 即可。常规重启无需重新安装；`make update` 会依次拉取镜像、停止服务、安装工具并重新启动。

本地修改 `agents/skills` 会直接对所有应用容器生效。提交并推送后，CI 会部署对应的仓库提交，生产 Pod 从仓库获取脚本和 skills，无需手工同步，也不会保留已删除的 skill。挂载配置变化后需重建容器才能生效。

启动容器、OpenCode Web 和 Multica daemon：

```bash
make start
```

OpenCode Web 默认地址为 `http://localhost:4096`。首次打开是 OpenCode 自带的「连接到服务器」页：点 **Use password**，密码填 `.env` 里的 `OPENCODE_SERVER_PASSWORD`（必须自己配置，见下面「OpenCode」一节）。

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

## SSH

`app` 服务前台跑 sshd，可以直接用普通 SSH 客户端（包括 Claude Desktop 的 SSH 远程环境
功能）连进容器，当运行环境用：

```bash
make ssh
# 等价于 ssh -p 2222 ubuntu@localhost
```

- 只认公钥登录（`PasswordAuthentication no`），授权公钥列表是
  `data/.ssh/authorized_keys`；加新 key 直接 append 进去，不用重启容器。
- 宿主机端口默认 `2222`，可在 `.env` 里用 `SSH_PORT` 覆盖；容器内部固定监听 22。
- host key 只在缺失时生成一次，持久化在 `data/.ssh/host_keys/`，容器重建或镜像
  升级都不会跟着换——避免 SSH 客户端每次都要重新信任新的 host key。

## OpenCode

`install.sh` 安装的是 OpenCode 2.x。2.x 只发布到 npm 的 `@opencode/cli`（GitHub 上只有 tag 没有 release），所以 `config/mise.toml` 里写的是 `"npm:@opencode/cli"`，不是 mise 内置的 `opencode`（后者走 GitHub release，只能装到 1.x）。这个包靠 postinstall 从平台包里拷出真正的二进制，而 mise 默认不跑依赖的安装脚本，所以要用 `allow_builds` 放行，否则装出来的 `opencode` 一运行就报 postinstall 没执行。

和 1.x 不同、影响这个仓库的几点：

- **Web UI**：`opencode web` 没了，改由 `opencode serve` 同时提供 API 和 Web UI。`serve` 必须带密码，读 `OPENCODE_PASSWORD`，旧名 `OPENCODE_SERVER_PASSWORD` 仍然认；都没配时每次启动随机生成一个。Web UI 的页面本身不设防，打开后在自带的登录页里输密码；所有 API（包括 `/api/info`）都要 Basic Auth（用户名固定 `opencode`），原来的 `/global/health` 也不存在了，所以 compose 健康检查带着 `.env` 里的密码打 `/api/info`，k8s 探针继续用 `tcpSocket`。
- **关掉常驻后台服务**：2.x 的 `opencode run`、TUI 等命令默认连一个常驻后台服务（`opencode serve --service`，监听 `127.0.0.1:49374`），找不到就拉起一个，靠 `~/.local/state/opencode/service.json` 发现彼此。这里三个容器共享同一个 home 和同一个 `opencode.db`，这套机制会出两个问题：compose 下各容器网络隔离，A 容器注册的 `127.0.0.1` 在 B 容器里连不上，B 会另起一个并覆盖注册文件，A 的服务发现自己被替换就退出，正在跑的 Multica 任务跟着断掉；后台服务启动时还会把库里「执行中但不属于自己」的会话当成崩溃遗留接着跑，而它分不出这些会话其实正在 `opencode` 容器的 `serve` 里跑着。所以 `config/opencode-service.json` 写了 `{"disabled": true}`，挂到 `~/.config/opencode/service.json`：每次 `opencode run`/TUI 都自带一个私有子进程服务器，进程模型和 1.x 一样，也不会去接管别的会话。代价是每次 `run` 多一次服务器启动（实测约 0.4 秒），以及 `opencode service set`、`opencode pair` 这类会写这个文件的命令用不了。
- **会话数据**：2.x 和 1.x 共用 `~/.local/share/opencode/opencode.db`，首次启动会在后台把 1.x 的会话迁移到同一个库里的新表，旧表保留（本地 2.3G、511 个会话的库约 15 秒迁完，期间 Web UI 可用）。升级前先停容器再备份 `data/.local/share/opencode/opencode.db*`（包括 WAL 文件），回退时用得上。
- **配置**：`config/opencode.jsonc` 仍是 1.x 写法，2.x 原样兼容（`permission` 会归一成 `permissions`，`small_model` 变成内置 `title` agent 的模型，`disabled_providers` 变成 policy）。
- **Multica**：当前固定的 Multica 0.6.1 会按 `opencode --version` 识别 2.x 并切换参数（`--dir`、`--variant` 在 2.x 里被移除）。但 2.x 只能从任务工作目录里的 `opencode.json` 读 MCP 配置，Multica 不愿把凭据写进 agent 可能 `git add` 的目录，所以**带 MCP server 的任务会被直接拒绝**（报错里会写明原因）；这类 agent 要么去掉 MCP，要么换成别的 runtime。

## Multica daemon

`install.sh` 从 Multica 官方 release 安装固定 CLI 版本（当前为 0.6.1），并校验 checksums.txt；daemon 在独立的 `multica` service 中以前台模式运行。首次启动时，如果持久化目录中还没有登录态，会使用 `.env` 中的 `MULTICA_TOKEN` 自动登录：

```bash
make setup
make install
make start
```

请先从 `.env.sample` 复制 `.env` 并填写 `MULTICA_TOKEN`。登录态保存在 `./data/.multica`，任务目录保存在 `./data/multica_workspaces`；不要提交 `.env`。`docker-compose.yml` 固定了官方支持的 `MULTICA_DAEMON_ID`（复用已有 agent 绑定的 runtime 身份）以及所有应用容器的 `hostname: devcontainer-local`（避免容器重建后显示随机 hostname）。Multica 的 device name 不单独设置——`MULTICA_DAEMON_DEVICE_NAME` 未配置时会读容器 hostname 当默认值，固定 hostname 后自然拿到 `devcontainer-local`。只有部署完全独立的另一套本地实例时才需要在 `.env` 中把 `MULTICA_DAEMON_ID` 覆盖成新的 UUID。常用命令：

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

- Docker daemon 由 `docker:28-dind` service 提供，三个应用 service 通过 `DOCKER_HOST=tcp://docker:2375` 连接。
- Docker 数据持久化在 `docker-data` volume。

## VS Code

VS Code 可以继续通过 `devcontainer.json` 快速打开工作区。这个文件只引用同一份 `docker-compose.yml`，不再声明任何 feature 或 lifecycle 回调。

## k3s 部署

`deploy/` 目录（风格参考 `yangcheng-team/eastar-price` 的 `deploy/`）把这个工作区部署为 k3s 上长期运行的个人云端实例：

- 集群：`oracle-arm1`（2 节点 k3s，Traefik + cert-manager + Sealed Secrets 均为集群已有组件），namespace `devcontainer`；OpenCode 使用 `https://ai.hdgcs.com`。
- 只有单一环境，不做 stg/prod 分层；所有部署配置都在 `deploy/`，入口是 `deploy/kustomization.yaml`。
- 存储：`workspace-pvc`（15Gi）、`user-data-pvc`（20Gi，整个挂成 `/home/ubuntu`，包含运行时安装的工具）、`docker-data-pvc`（15Gi，供 dind sidecar 用）。三者都用 `local-path` storageClass 并通过 `nodeSelector` 固定调度到 `arm1`。`local-path` 不支持事后扩容；工具下载和安装缓存也占用 home 卷空间，需留意容量。
- **待办（2026-09-20 之后）**：旧的 `home-data-pvc`（8Gi）在切到整挂 home 时原封不动留着当退路，新卷跑稳几周后从 `deploy/pvc.yaml` 删掉并 `kubectl delete pvc home-data-pvc`。顺带还有一个更早遗留的 `openclaw-data-pvc` 可以一起回收。
- 配置：`deploy/kustomization.yaml` 从 `../config/` 生成带内容哈希的 ConfigMap；配置变化触发 Pod 滚动更新。因为配置源位于部署目录之外，渲染使用 `kubectl kustomize deploy/ --load-restrictor LoadRestrictionsNone`，再将结果交给 `kubectl apply -f -`，统一封装在 Makefile 中。
- 运行时仓库：`sync-runtime` initContainer 将公开仓库的指定提交检出到独立的 `emptyDir`，挂为 `/opt/workspace`；其中的 `agents/` 覆盖 `~/.agents`，`scripts/` 直接用于启动与安装。镜像不包含这些文件。CI 将 `RUNTIME_REVISION` 固定为本次提交的完整 SHA；手工部署默认使用 `main`，也可在 `deploy/kustomization.yaml` 中指定已经推送的提交。
- 工具安装：`fix-ownership` 准备挂载点和属主，`sync-runtime` 获取仓库，`install-tools` 执行仓库中的 `scripts/install.sh`，完成后才启动应用。首次部署需要联网获取仓库、下载工具；后续复用 home 中的安装。等待超时为 20 分钟，失败时查看对应 initContainer 的日志。
- 工具解析：应用通过 `mise exec` 获取真实 provider PATH，避免 Multica 把 Codex 等误启动成 mise task runner；用 `make agent-cli.smoke` 在空白目录复验。
- 用户文件初始化：所有应用容器只写 `args:`，不写会覆盖 ENTRYPOINT 的 `command:`。`entrypoint.sh` 仅从 `/etc/skel` 补齐默认用户文件；Claude 到 `~/.agents` 的软链由 `install.sh` 创建。`app` 前台运行 sshd，跟 OpenCode、Multica 隔离。
- 鉴权：`opencode serve` 使用 Sealed Secret 中的 `OPENCODE_SERVER_PASSWORD`：Web UI 在自带登录页选 Use password 输入，API 客户端走 HTTP Basic Auth（用户名固定为 `opencode`）。Multica 首次启动时使用同一 Secret 中的 `MULTICA_TOKEN` 自动登录，登录态持久化到 `user-data-pvc`。Secret 明文不在仓库里。
- Multica 身份：`multica` 容器显式设置 `MULTICA_DAEMON_ID` 为原 `devcontainer.cloud` runtime 的 ID。官方以 daemon ID 作为 runtime 去重键；Pod 名变化或 CLI 升级后会更新原 runtime，不会注册成 `app-<hash>-<suffix>` 新机器。该 ID 不是凭据，不要随镜像升级修改。device name 不再单独设置——Pod 固定了 `hostname: devcontainer-cloud`（同 UTS namespace，opencode/multica/app 都生效），`MULTICA_DAEMON_DEVICE_NAME` 未配置时 daemon 会读容器 hostname 当默认值，跟着显示 `devcontainer-cloud`。
- Docker-in-Docker：`dind` 是同 Pod 内的特权 sidecar，`opencode`、`multica` 和 `app` 容器通过 `DOCKER_HOST=tcp://localhost:2375` 连接（和 compose 里的 `tcp://docker:2375` 不同，这里是同一个 Pod）。
- 探针：OpenCode 使用 `tcpSocket`，避免鉴权导致 HTTP 401。
- SSH：`app` 容器同本地一样跑 sshd，独立的 `app-ssh` Service（`type: LoadBalancer`，
  依赖 k3s 自带的 ServiceLB/klipper）把 2222 端口（避开节点自己的系统 sshd 占用的
  22）暴露到集群外，`make deploy.ssh` 连接。云端 `user-data-pvc` 里的
  `authorized_keys` 是独立于本地 `./data` 的一份，需要单独确认已经写入授权公钥。
- 数据迁移：旧的 `home-data-pvc` 在迁移时全程只读保留。注意 `~/.local/share/lark-cli/master.key` 从来没有迁到集群，只在本地 `./data` 里有，要用 lark CLI 得单独上传。之后的更新走 CI。

手动操作（需要本地 `kubectl` 已指向该集群、并安装 `kubeseal`）：

```bash
make deploy.config   # 预览 deploy/ 的 kustomize 渲染结果
make deploy.apply    # 渲染 deploy/、apply 并等待 rollout
make deploy.status   # 查看 Pod/Service/Ingress/PVC
make deploy.logs     # 查看 app 容器日志
make deploy.bash     # 进入集群里的 app 容器
make deploy.multica-status  # 查询 daemon 状态
make deploy.multica-logs    # 查看 daemon 日志
```

Kubernetes Pod 内分别运行 `opencode`、`multica` 和 `app` 容器；Multica 认证和任务目录随整挂的 `user-data-pvc` 持久化。首次部署会使用 `MULTICA_TOKEN` 自动登录，之后可用 status 和 Runtimes 页面确认在线。

修改 `deploy/app-secret.yaml`（明文，已被 `deploy/.gitignore` 排除）后，用 `make deploy.encode` 重新生成 `deploy/app-sealed-secret.yaml`。

`.github/workflows/build-devcontainer.yml` 仅在 Dockerfile、构建上下文规则、entrypoint 或工作流本身变化时重建基础镜像，发布 `commit-<short-sha>` 和 `latest`。只修改配置、安装脚本或 skills 时复用已发布的基础镜像，独立更新运行时仓库提交。两种路径都会验证安装并执行 `make deploy.apply`。所需 `KUBECONFIG` secret 仅有 `devcontainer` 命名空间权限。

## 本地数据

以下内容不会提交到 Git：

- `.env`
- `data/*`

凭证、历史记录、运行时安装的工具和缓存放在 `./data`，整个目录挂载为容器里的 `/home/ubuntu`。可提交的工具配置放在 `./config`，用户指令和 skills 放在 `./agents`，两者都以嵌套挂载覆盖 `./data` 中的对应路径。不要把 token、登录态或私钥放进 `agents/`。
