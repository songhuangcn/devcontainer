# Workspace

这个仓库提供一个纯 Docker 的长期开发工作区，用于在可复现环境中运行 OpenCode 和 Multica daemon。

## 内容

- `docker-compose.yml`：用共享 base 配置分别启动 `opencode`、`multica`，并提供 Docker-in-Docker service `docker`。
- `Dockerfile`：只构建一个基础镜像，包含系统开发依赖、字体和论文输出工具链，仅复制 `entrypoint.sh`。
- `devcontainer.json`：仅作为 VS Code 快速打开入口（指向 `opencode` service），不再使用 devcontainer features。
- `scripts/setup.sh`：检查手动配置的 `.env`，准备持久化 home 目录 `./data`。
- `scripts/entrypoint.sh`：从 `/etc/skel` 补齐缺失的默认用户文件，然后执行容器命令。
- `scripts/start.sh`：将用户配置、指令和 skills 链接到可写仓库，再执行应用命令；无参数时只准备配置。
- `scripts/sync-runtime.sh`：生产 Pod 启动前更新持久化仓库，保留本地修改，遇到冲突停止。
- `scripts/install.sh`：容器启动后安装 mise、`config/mise.toml` 中的工具、Python 依赖、Multica 和 Autoteam 启动器。
- `tests/`：运行时回归、真实安装验证和 agent CLI 冒烟测试。
- `config/`、`agents/`：纳入版本控制的工具配置、用户指令和 skills。
- `deploy/`：完整的 Kubernetes 部署配置，包括唯一的 `kustomization.yaml`。

## 镜像

CI 只发布主镜像：

- `songhuangcn/devcontainer:latest` / `songhuangcn/devcontainer:commit-<short-sha>`

`songhuangcn/devcontainer` 虽然保留原名称，但现在是纯 Docker 镜像，不依赖 devcontainer feature，包含 LaTeX/PDF、CJK 字体和 PDF 检查工具；Pandoc 等 mise 工具在启动后安装。

mise、OpenCode、Claude、Codex、Node、Python、GitHub CLI、Docker CLI、Compose plugin、Multica、Autoteam 等都由 `make setup` 安装到用户 home。配置、安装脚本和 skills 不进入镜像，修改它们无需重新构建基础镜像。

## 前置依赖

需要 `make`、Docker 和 Docker Compose：

```bash
docker --version
docker compose version
```

不再需要安装 `devcontainer` CLI。

## 本地使用

首次使用，先参考 `.env.sample` 手动创建并编辑 `.env`：填写 `OPENCODE_SERVER_PASSWORD`，没有持久化 Multica 登录态时还需填写 `MULTICA_TOKEN`。不要提交 `.env`。然后运行：

```bash
make setup
make start
```

`make setup` 要求 `.env` 已存在，不会生成或覆盖它。它预建 `./data`，在本地构建 OpenCode 和 Multica 共用的应用镜像，准备 Docker-in-Docker 镜像，再用一次性容器检查启动配置并安装工具。它不会启动常驻服务；成功后直接 `make start`，无需再构建、拉取镜像或安装工具。

安装脚本通过工作区挂载路径 `/workspace/.devcontainer/scripts/install.sh` 执行。脚本准备用户配置链接、串行安装工具，并建立 Compose plugin 入口。Multica 和 Autoteam 启动器固定版本/提交，校验 SHA-256 后才替换已有文件。只想重装工具时，可用 `make install` 复用已有应用镜像，不需要先启动服务。

`docker-compose.yml` 只挂载工作区和整个 home。`start.sh` 在应用启动前将 Git、Claude、Codex、mise、OpenCode 的配置链接到仓库的 `config/`，将 `~/.agents` 链接到仓库的 `agents/`；不使用只读配置或单文件挂载。容器内修改配置会直接写回工作树，宿主机编辑仓库文件也立即可见。已有配置和指令会先保留为同名的 `.before-workspace-link`；Claude 的 `CLAUDE.md` 和 `skills` 使用 `.before-agents-link`。备份已存在时拒绝覆盖。默认用户文件从 `/etc/skel` 补齐，已有 `.bashrc`、`.profile` 永远不会被覆盖。

编辑器若通过替换文件保存，应直接编辑仓库路径或软链的真实路径，避免把用户路径的软链替换成独立文件。

mise、Multica 和 Autoteam 启动器安装在 `~/.local/bin`；mise 使用默认的用户数据、缓存、状态目录，不设置 `MISE_*` 环境变量或专用 provider 目录。Compose plugin 位于 `~/.docker/cli-plugins/docker-compose`。这些内容随 home 持久化，由用户自行管理。

OpenCode 和 Multica 服务通过 login shell 执行 `mise exec -- …`，使用真实工具路径而不是 mise shim；`make bash` 也会进入 `opencode` 容器的 mise 工具环境。其他 shell 可运行 `mise exec -- <命令>`，或自行在 `~/.bashrc` 配置 `eval "$(mise activate bash)"`；安装脚本不会修改用户 shell 配置。

`~/.config/mise/config.toml` 链接到 `/workspace/.devcontainer/config/mise.toml`，支持在容器内调整工具版本；修改版本后直接 `make install` 即可。常规重启无需重新安装；`make update` 会依次拉取镜像、停止服务、安装工具并重新启动。

本地修改 `agents/skills` 会直接对所有应用容器生效。配置与 skills 的写回只修改工作树，不自动提交或推送；需要同步到其他环境时自行检查 diff、提交并推送，避免将凭据纳入版本控制。挂载配置变化后需重建容器才能生效。

飞书 Skills 使用官方 `suite` 聚合布局：`agents/skills/lark-suite/SKILL.md` 是唯一入口，各业务说明位于其 `references/<能力名>/GUIDE.md`，按需读取。更新统一运行 `lark-cli update --skills-layout suite`，避免将各业务重新安装为顶层独立 Skills。`agents/.skill-lock.json` 保留在 Git 中，由安装器维护来源与更新信息；登录凭据保存在持久化 home 中，不进入仓库。

启动容器、OpenCode Web 和 Multica daemon：

```bash
make start
```

OpenCode Web 默认地址为 `http://localhost:4096`。首次打开是 OpenCode 自带的「连接到服务器」页：点 **Use password**，密码填 `.env` 里的 `OPENCODE_SERVER_PASSWORD`（必须自己配置，见下面「OpenCode」一节）。

进入 `opencode` 容器（不提供 SSH 入站连接；镜像保留 SSH 客户端供 Git 等出站连接使用）：

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

## OpenCode

`config/opencode.jsonc` 使用 V2 配置格式：允许工具操作、禁用 `opencode` 模型供应商，并通过 `agents.title.model` 指定会话标题模型。标题模型必须在所用供应商中真实可用。

Web 界面偏好保存在当前站点的浏览器本地存储中，不支持通过 `opencode.jsonc` 或容器挂载设置。在 Web 的 Settings 中设置：

- **Show agent**：开启。
- **Tab layout**：选择 **Inbox**。
- **Language**：选择 **English**，不跟随浏览器语言。

也可以在已打开的 OpenCode Web 页面的开发者工具 Console 中执行 `config/opencode-web-settings.js` 的完整内容，一次性合并这三个选项并刷新页面，保留其他偏好。脚本使用 V2.3.2 的客户端存储格式，不会由容器自动执行；不同域名、浏览器或浏览器配置文件需要分别设置，升级客户端后应先核对存储格式。

`install.sh` 安装的是 OpenCode 2.x。2.x 只发布到 npm 的 `@opencode/cli`（GitHub 上只有 tag 没有 release），所以 `config/mise.toml` 里写的是 `"npm:@opencode/cli"`，不是 mise 内置的 `opencode`（后者走 GitHub release，只能装到 1.x）。这个包靠 postinstall 从平台包里拷出真正的二进制，而 mise 默认不跑依赖的安装脚本，所以要用 `allow_builds` 放行，否则装出来的 `opencode` 一运行就报 postinstall 没执行。

和 1.x 不同、影响这个仓库的几点：

- **Web UI**：`opencode web` 没了，改由 `opencode serve` 同时提供 API 和 Web UI。`serve` 必须带密码，读 `OPENCODE_PASSWORD`，旧名 `OPENCODE_SERVER_PASSWORD` 仍然认；都没配时每次启动随机生成一个。Web UI 的页面本身不设防，打开后在自带的登录页里输密码；所有 API（包括 `/api/info`）都要 Basic Auth（用户名固定 `opencode`），原来的 `/global/health` 也不存在了，所以 compose 健康检查带着 `.env` 里的密码打 `/api/info`，k8s 探针继续用 `tcpSocket`。
- **关掉常驻后台服务**：2.x 的 `opencode run`、TUI 等命令默认连一个常驻后台服务（`opencode serve --service`，监听 `127.0.0.1:49374`），找不到就拉起一个，靠 `~/.local/state/opencode/service.json` 发现彼此。这里两个应用容器共享同一个 home 和同一个 `opencode.db`，这套机制会出两个问题：compose 下各容器网络隔离，A 容器注册的 `127.0.0.1` 在 B 容器里连不上，B 会另起一个并覆盖注册文件，A 的服务发现自己被替换就退出，正在跑的 Multica 任务跟着断掉；后台服务启动时还会把库里「执行中但不属于自己」的会话当成崩溃遗留接着跑，而它分不出这些会话其实正在 `opencode` 容器的 `serve` 里跑着。所以 `config/opencode-service.json` 写了 `{"disabled": true}`，链接到 `~/.config/opencode/service.json`：每次 `opencode run`/TUI 都自带一个私有子进程服务器，进程模型和 1.x 一样，也不会去接管别的会话。代价是每次 `run` 多一次服务器启动（实测约 0.4 秒），且不能使用依赖共享后台服务的配对功能。此配置可写，但应保持后台服务禁用，避免共享 home 的服务发现冲突。
- **会话数据**：2.x 和 1.x 共用 `~/.local/share/opencode/opencode.db`，首次启动会在后台把 1.x 的会话迁移到同一个库里的新表，旧表保留（本地 2.3G、511 个会话的库约 15 秒迁完，期间 Web UI 可用）。升级前先停容器再备份 `data/.local/share/opencode/opencode.db*`（包括 WAL 文件），回退时用得上。
- **配置**：`config/opencode.jsonc` 使用原生 V2 的 `permissions`、`agents.title.model` 和 `policies`，并保留定时任务开关。
- **Multica**：内置的 OpenCode 2.x runtime 默认通过 ACP 启动会话，并通过 ACP 传入 Multica 管理的 MCP server，不向任务目录写入凭据。若使用 `opencode run` 模式，Multica 仍会拒绝带有这类 MCP server 的任务，以免把凭据写入可能被提交的工作目录。

## Multica daemon

`install.sh` 从 Multica 官方 release 安装固定 CLI 版本（当前为 0.11.1），并校验 checksums.txt；daemon 在独立的 `multica` service 中以前台模式运行。首次 `make start` 时，如果持久化目录中还没有登录态，会使用 `.env` 中的 `MULTICA_TOKEN` 自动登录。

登录态保存在 `./data/.multica`，任务目录保存在 `./data/multica_workspaces`。`docker-compose.yml` 固定了官方支持的 `MULTICA_DAEMON_ID`（复用已有 agent 绑定的 runtime 身份）以及所有应用容器的 `hostname: devcontainer-local`（避免容器重建后显示随机 hostname）。Multica 的 device name 不单独设置——`MULTICA_DAEMON_DEVICE_NAME` 未配置时会读容器 hostname 当默认值，固定 hostname 后自然拿到 `devcontainer-local`。只有部署完全独立的另一套本地实例时才需要在 `.env` 中把 `MULTICA_DAEMON_ID` 覆盖成新的 UUID。常用命令：

```bash
make multica.status
make multica.logs
make multica.restart
make multica.stop
make multica.smoke
make agent-cli.smoke
```

`make agent-cli.smoke` 会在空白临时目录中按 Multica daemon 使用的方式解析并执行 Codex、Claude 和 OpenCode，防止 provider 命令错误落到 mise task runner。验证时先用 `make multica.status` 确认 runtime 在线，再从 Multica 触发一次真实 agent task。容器重启后，认证和 task workspace 会继续保留。

## 检查与测试

测试脚本集中在 `tests/`，功能脚本保留在 `scripts/`：

```bash
make check          # ShellCheck（含 tests）、Dockerfile、Compose、Kustomize 和运行时回归
make test           # 临时 home 和命令替身，不下载工具、不接触真实 data
make install.test   # 一次性容器内联网安装并验证工具、配置写回和用户链接
make agent-cli.smoke  # 在 multica 容器内验证已安装的 agent CLI
```

`make test` 和 `make install.test` 共用主镜像容器入口，通过 stdin 提供 `scripts/`、`tests/`、配置和 skills，不挂载持久化 home。`tests/test-runtime.sh` 包含本地 Git 仓库同步回归；`tests/test-install.sh` 仅用于一次性容器。安装脚本会调用 `tests/smoke-agent-cli-launchers.sh`，验证 provider 没有误解析为 mise task runner。

## Docker

- Docker daemon 由 `docker:28-dind` service 提供，两个应用 service 通过 `DOCKER_HOST=tcp://docker:2375` 连接。
- Docker 数据持久化在 `docker-data` volume。

## VS Code

VS Code 可以继续通过 `devcontainer.json` 快速打开工作区。这个文件只引用同一份 `docker-compose.yml`，不再声明任何 feature 或 lifecycle 回调。

## k3s 部署

`deploy/` 目录（风格参考 `yangcheng-team/eastar-price` 的 `deploy/`）把这个工作区部署为 k3s 上长期运行的个人云端实例：

- 集群：`oracle-arm1`（2 节点 k3s，Traefik + cert-manager + Sealed Secrets 均为集群已有组件），namespace `devcontainer`；OpenCode 使用 `https://ai.hdgcs.com`。
- 只有单一环境，不做 stg/prod 分层；所有部署配置都在 `deploy/`，入口是 `deploy/kustomization.yaml`。
- 存储：`workspace-pvc`（15Gi）、`user-data-pvc`（20Gi，整个挂成 `/home/ubuntu`，包含运行时安装的工具）、`docker-data-pvc`（15Gi，供 dind sidecar 用）。三者都用 `local-path` storageClass 并通过 `nodeSelector` 固定调度到 `arm1`。`local-path` 不支持事后扩容；工具下载和安装缓存也占用 home 卷空间，需留意容量。
- **待办（2026-09-20 之后）**：旧的 `home-data-pvc`（8Gi）在切到整挂 home 时原封不动留着当退路，新卷跑稳几周后从 `deploy/pvc.yaml` 删掉并 `kubectl delete pvc home-data-pvc`。顺带还有一个更早遗留的 `openclaw-data-pvc` 可以一起回收。
- 配置：工具配置直接来自持久化仓库，通过与 Compose 相同的用户软链读写。`runtime-config` ConfigMap 仅供部署准备使用；其版本化名称写入应用 Pod 模板，确保新提交触发 rollout。
- 运行时仓库：每次发布先通过临时 `runtime-setup` Pod，把指定提交检出到 `workspace-pvc` 中的 `/workspace/.devcontainer`；准备成功才更新应用 Deployment。普通 Pod 重建直接读取卷里的工作区，不拉 Git、不切提交。CI 使用本次提交的完整 SHA；手工部署默认使用本地 HEAD，也可以通过 `RUNTIME_REVISION` 指定已推送的完整 SHA。
- 仓库更新：已有非仓库目录或不同来源的仓库不会被接管。非强制 Git checkout 保留不冲突的在线改动；有冲突或未集成的本地提交时，准备失败，不替换应用 Pod，也不清理或隐式 stash。旧 HEAD 通过 `refs/workspace/saved-heads/<完整 SHA>` 保留。云端目录仍可写：工具热加载的配置可能立即生效；启动脚本、安装版本和镜像等改动不一定立即生效，正式发布应提交并推送，由 CI 更新。排查冲突后重试 `make deploy.apply`。
- 目录和工具：临时准备 Pod 初始化工作区目录；应用的 `setup` initContainer 准备用户配置目录，不递归修改权限。`install-tools` 执行卷里的 `scripts/install.sh` 安装工具，再启动应用。准备阶段最长 5 分钟，应用 rollout 最长 20 分钟。
- 工具解析：应用通过 `mise exec` 获取真实 provider PATH，避免 Multica 把 Codex 等误启动成 mise task runner；用 `make agent-cli.smoke` 在空白目录复验。
- 用户文件初始化：所有应用容器只写 `args:`，不写会覆盖 ENTRYPOINT 的 `command:`。镜像的 `entrypoint.sh` 从 `/etc/skel` 补齐默认用户文件，运行时的 `start.sh` 准备配置与指令链接，再执行应用命令；修改链接逻辑不需要重建镜像。
- 鉴权：`opencode serve` 使用 Sealed Secret 中的 `OPENCODE_SERVER_PASSWORD`：Web UI 在自带登录页选 Use password 输入，API 客户端走 HTTP Basic Auth（用户名固定为 `opencode`）。Multica 首次启动时使用同一 Secret 中的 `MULTICA_TOKEN` 自动登录，登录态持久化到 `user-data-pvc`。Secret 明文不在仓库里。
- Multica 身份：`multica` 容器显式设置 `MULTICA_DAEMON_ID` 为原 `devcontainer.cloud` runtime 的 ID。官方以 daemon ID 作为 runtime 去重键；Pod 名变化或 CLI 升级后会更新原 runtime，不会注册成 `app-<hash>-<suffix>` 新机器。该 ID 不是凭据，不要随镜像升级修改。device name 不再单独设置——Pod 固定了 `hostname: devcontainer-cloud`（同 UTS namespace，opencode/multica 都生效），`MULTICA_DAEMON_DEVICE_NAME` 未配置时 daemon 会读容器 hostname 当默认值，跟着显示 `devcontainer-cloud`。
- Docker-in-Docker：`dind` 是同 Pod 内的特权 sidecar，`opencode` 和 `multica` 容器通过 `DOCKER_HOST=tcp://localhost:2375` 连接（和 compose 里的 `tcp://docker:2375` 不同，这里是同一个 Pod）。
- 探针：OpenCode 使用 `tcpSocket`，避免鉴权导致 HTTP 401。
- 数据迁移：旧的 `home-data-pvc` 在迁移时全程只读保留。注意 `~/.local/share/lark-cli/master.key` 从来没有迁到集群，只在本地 `./data` 里有，要用 lark CLI 得单独上传。之后的更新走 CI。

手动操作（需要本地 `kubectl` 已指向该集群、并安装 `kubeseal`）：

```bash
make deploy.config   # 预览完整的部署清单
make deploy.setup    # 只准备工作区，不替换应用 Pod
make deploy.apply    # 先准备工作区，再更新应用并等待 rollout
make deploy.status   # 查看 Pod/Service/Ingress/PVC
make deploy.logs     # 查看 opencode 容器日志
make deploy.bash     # 进入集群里的 opencode 容器
make deploy.multica-status  # 查询 daemon 状态
make deploy.multica-logs    # 查看 daemon 日志
```

Kubernetes Pod 内分别运行 `opencode`、`multica` 和 `dind` 容器；Multica 认证和任务目录随整挂的 `user-data-pvc` 持久化。首次部署会使用 `MULTICA_TOKEN` 自动登录，之后可用 status 和 Runtimes 页面确认在线。

修改 `deploy/app-secret.yaml`（明文，已被 `deploy/.gitignore` 排除）后，用 `make deploy.encode` 重新生成 `deploy/app-sealed-secret.yaml`。

`.github/workflows/build-devcontainer.yml` 仅在 Dockerfile、构建上下文规则、entrypoint 或工作流本身变化时重建基础镜像，发布 `commit-<short-sha>` 和 `latest`。只修改配置、安装脚本或 skills 时复用已发布的基础镜像，独立更新运行时仓库提交。两种路径都会验证安装并执行 `make deploy.apply`。所需 `KUBECONFIG` secret 仅有 `devcontainer` 命名空间权限。

## 本地数据

以下内容不会提交到 Git：

- `.env`
- `data/*`

凭证、历史记录、运行时安装的工具和缓存放在 `./data`，整个目录挂载为容器里的 `/home/ubuntu`。可提交的工具配置放在 `./config`，用户指令和 skills 放在 `./agents`，用户默认路径通过软链关联到仓库。不要把 token、登录态或私钥放进 `config/`、`agents/` 或其他 Git 跟踪文件。
