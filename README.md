# Workspace

这个仓库提供一个纯 Docker 的长期开发工作区，用于在可复现环境中运行 OpenCode、OpenClaw 和 Multica daemon。

## 内容

- `docker-compose.yml`：用共享 base 配置分别启动 `opencode`、`openclaw`、`multica`，并启动 Docker-in-Docker service `docker`。
- `Dockerfile`：构建开发工具镜像，内置 OpenCode、OpenClaw、常用 CLI、Docker CLI、Compose plugin 和论文输出工具链。
- `devcontainer.json`：仅作为 VS Code 快速打开入口，不再使用 devcontainer features。
- `scripts/setup.sh`：准备本地 `./data` 下的持久化用户数据路径。
- `dockerfiles/Dockerfile.java`：Java 扩展镜像。

## 镜像

CI 发布以下镜像：

- `songhuangcn/devcontainer:latest` / `songhuangcn/devcontainer:commit-<short-sha>`
- `songhuangcn/devcontainer-java:latest` / `songhuangcn/devcontainer-java:commit-<short-sha>`

`songhuangcn/devcontainer` 虽然保留原名称，但现在是纯 Docker 镜像，不依赖 devcontainer feature，并已包含 LaTeX/PDF、Pandoc DOCX、CJK 字体和 PDF 检查工具。

Java 镜像预装的 VS Code Server 默认版本由 `dockerfiles/vscode.java.version` 定义。Java 镜像还会发布按 VS Code 版本命名的标签，可以直接拉取指定版本：

```bash
docker pull songhuangcn/devcontainer-java:vscode-1.130.0
```

`vscode-<version>-repo-<short-sha>` 同时锁定 VS Code 版本和本仓库构建版本。手动运行 `build-devcontainer-java` workflow 时，可以通过 `vscode_version` 输入临时构建其他稳定版；非默认版本不会更新 `latest` 和 `commit-*` 标签。

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

`make setup` 会在缺失时从 `.env.sample` 创建 `.env`，并创建 Compose 会挂载到 `/home/ubuntu` 的必需空文件和 OpenClaw 状态目录，确保目录由当前用户创建并可由容器写入。

必需存在的本地文件包括 `.env` 和 `./data/.claude.json`。如果不想运行 `make setup`，也可以手动创建这些文件。OpenCode、Git、Claude 和 Codex 的可共享配置位于 `./config`，随版本库提供。OpenClaw 状态持久化在 `./data/.openclaw`。

`docker-compose.yml` 不挂载完整的 `~/.local`，避免遮住镜像内置工具链；只把 OpenCode 和 Lark CLI 的持久化数据分别从 `./data/opencode`、`./data/lark-cli` 挂到 `~/.local/share` 下。`.bashrc`、`.profile` 等 shell 启动文件继续使用镜像内版本。Docker Compose plugin 的系统级入口位于 `/usr/local/lib/docker/cli-plugins/docker-compose`。

如果旧的 `./data/.bashrc`、`./data/.profile` 仍存在，它们不会再挂载到容器内。

在 `.env` 中设置 OpenClaw Gateway token：

```bash
OPENCLAW_GATEWAY_TOKEN=<随机 token>
```

启动容器、OpenCode Web、OpenClaw Gateway 和 Multica daemon：

```bash
make start
```

OpenCode Web 默认地址为 `http://localhost:4096`，OpenClaw Control UI 默认地址为 `http://localhost:18789`。

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

## Multica daemon

镜像通过 Multica 官方安装脚本安装最新 CLI，daemon 在独立的 `multica` service 中以前台模式运行；未认证时 service 会保持运行并等待登录。首次使用时执行：

```bash
make setup
make start
make multica.login
```

`make multica.login` 会交互读取 PAT，登录态保存在 `./data/.multica`，任务目录保存在 `./data/multica_workspaces`；不要把 PAT 写入 `.env` 或仓库。常用命令：

```bash
make multica.status
make multica.logs
make multica.restart
make multica.stop
make multica.smoke
```

验证时先用 `make multica.status` 确认 runtime 在线，再从 Multica 远程执行一次命令和文件读写。容器重启后，认证和 task workspace 会继续保留。

## Docker

- Docker daemon 由 `docker:28-dind` service 提供，三个应用 service 通过 `DOCKER_HOST=tcp://docker:2375` 连接。
- Docker 数据持久化在 `docker-data` volume。

## VS Code

VS Code 可以继续通过 `devcontainer.json` 快速打开工作区。这个文件只引用同一份 `docker-compose.yml`，不再声明任何 feature 或 lifecycle 回调。

## k3s 部署

`deploy/` 目录（风格参考 `yangcheng-team/eastar-price` 的 `deploy/`）把这个工作区部署为 k3s 上长期运行的个人云端实例：

- 集群：`oracle-arm1`（2 节点 k3s，Traefik + cert-manager + Sealed Secrets 均为集群已有组件），namespace `devcontainer`；OpenCode 使用 `https://ai.hdgcs.com`，OpenClaw 使用 `https://claw.hdgcs.com`。
- 只有单一环境，不做 stg/prod 分层；根目录 `kustomization.yaml` 在 `deploy/` 基础资源之上生成工具配置。
- 存储：`workspace-pvc`（15Gi，空卷，不含本地历史数据）、`home-data-pvc`（8Gi，通过 subPath 对应 `~/.agents/.cache/.claude/.codex/.config/.copilot/.lark-cli/.multica/.npm/.openclaw/.ssh/.vscode-server`、`~/multica_workspaces` 等目录及 `.claude.json`，并单独持久化 `~/.local/share/opencode` 和 `~/.local/share/lark-cli`）、`docker-data-pvc`（15Gi，供 dind sidecar 用）。三者都用 `local-path` storageClass 并通过 `nodeSelector` 固定调度到 `arm1`。不挂载完整的 `~/.local`，避免遮住镜像中的 mise 和工具链。
- 配置：根目录 Kustomize overlay 从 `config/` 生成带内容哈希的 ConfigMap，挂载 OpenCode、Git、Claude 和 Codex 配置；配置变化会触发 Pod 滚动更新。
- 鉴权：`opencode web` 使用 Sealed Secret 中的 `OPENCODE_SERVER_PASSWORD`（HTTP Basic Auth，用户名默认 `opencode`）；OpenClaw Gateway 复用该 Secret 值作为 `OPENCLAW_GATEWAY_PASSWORD`，并共享 `home-data-pvc` 中持久化的 Claude Code CLI 登录态。密码不在仓库里。
- Docker-in-Docker：`dind` 是同 Pod 内的特权 sidecar，`opencode`、`openclaw` 和 `multica` 容器通过 `DOCKER_HOST=tcp://localhost:2375` 连接（和 compose 里的 `tcp://docker:2375` 不同，这里是同一个 Pod）。
- 探针：OpenCode 使用 `tcpSocket`，避免鉴权导致 HTTP 401；OpenClaw 使用无需鉴权的 `/healthz` 和 `/readyz`。
- 首次上线时手动把本地 `./data` 下的 `.ssh`、`.claude`/`.codex` 登录态、`gh`/`lark-cli` 配置等**凭据**（不含 `.cache`/`.local`/`.vscode-server`/`.claude` 里的会话历史等可再生数据）一次性迁移进了 `home-data-pvc`；之后的更新走 CI，不再涉及这类手动数据迁移。

手动操作（需要本地 `kubectl` 已指向该集群、并安装 `kubeseal`）：

```bash
make deploy.config   # 预览根目录 kustomize overlay 渲染结果
make deploy.apply    # kubectl apply -k ./ 并等待 rollout
make deploy.status   # 查看 Pod/Service/Ingress/PVC
make deploy.logs     # 查看 opencode 容器日志
make deploy.bash     # 进入集群里的 opencode 容器
make deploy.multica-login   # 首次安全输入 PAT，并滚动重启 Pod
make deploy.multica-status  # 查询 daemon 状态
make deploy.multica-logs    # 查看 daemon 日志
```

Kubernetes Pod 内分别运行 `opencode`、`openclaw` 和 `multica` 容器；Multica 认证、任务目录和 OpenClaw 状态均通过现有 `home-data-pvc` 的 subPath 持久化。首次部署后运行 `make deploy.multica-login`，再用 status 和 Runtimes 页面确认在线。

修改 `deploy/app-secret.yaml`（明文，已被 `deploy/.gitignore` 排除）后，用 `make deploy.encode` 重新生成 `deploy/app-sealed-secret.yaml`。

`.github/workflows/build-devcontainer.yml` 在构建镜像成功后会自动 `kubectl apply -k ./`，使用当次构建的 `commit-<short-sha>` 镜像 tag；所需的 `KUBECONFIG` secret 对应一个只在 `devcontainer` 命名空间内有权限的 ServiceAccount（非集群管理员凭据）。

## 本地数据

以下内容不会提交到 Git：

- `.env`
- `data/*`
- `agents/*`

凭证、历史记录和用户数据默认放在 `./data`，并按需挂载到 `/home/ubuntu` 下的对应路径。可提交的工具配置放在 `./config`；镜像自带的 `.bashrc`、`.profile` 和工具链配置不会被本地 `./data` 覆盖。
