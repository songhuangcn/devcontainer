# Workspace

这个仓库提供一个纯 Docker 的长期开发工作区，用于在可复现环境中运行 OpenCode、OpenClaw 和 Multica daemon。

## 内容

- `docker-compose.yml`：在 `app` 中启动 OpenCode Web 与 OpenClaw Gateway，并启动 Docker-in-Docker sidecar `docker`。
- `Dockerfile`：构建开发工具镜像，内置 OpenCode、OpenClaw、常用 CLI、Docker CLI、Compose plugin 和论文输出工具链。
- `devcontainer.json`：仅作为 VS Code 快速打开入口，不再使用 devcontainer features。
- `scripts/entrypoint.sh`：在 `app` 容器内同时启动 OpenCode 和 OpenClaw。
- `scripts/setup.sh`：准备本地 `./data` 下的持久化用户数据路径。
- `scripts/multica-daemon-entrypoint.sh`：以前台方式托管 Multica daemon；未登录时等待，异常退出后自动重启。
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

镜像内置工具链由 `/opt/mise` 管理，不放在 `/home/ubuntu` 下。`docker-compose.yml` 只挂载选定的用户数据路径，因此 `.bashrc`、`.profile` 等 shell 启动文件继续使用镜像内版本。Docker Compose plugin 的系统级入口位于 `/usr/local/lib/docker/cli-plugins/docker-compose`。

如果旧的 `./data/.bashrc`、`./data/.profile` 仍存在，它们不会再挂载到容器内。

在 `.env` 中设置 OpenClaw Gateway token：

```bash
OPENCLAW_GATEWAY_TOKEN=<随机 token>
```

启动容器、OpenCode Web、OpenClaw Gateway 和 Multica daemon supervisor：

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

镜像内置并锁定 Multica CLI `0.4.24`，构建时分别校验 amd64/arm64 release archive 的 SHA-256。daemon 使用独立的 `multica-daemon` 服务运行，不与 OpenCode 的主进程耦合：Compose 的 `restart: unless-stopped` 负责容器级恢复，入口脚本负责 daemon 进程异常退出后的恢复。CLI 的自动更新被关闭；升级时修改 `Dockerfile` 中的版本和两个 release checksum，重新构建镜像，从而保证升级可审计和可重复。

### 首次初始化

从干净环境开始：

```bash
make setup
make start
make multica.login
```

`make multica.login` 使用交互提示读取 `mul_...` PAT，token 不会进入命令历史、`.env`、镜像层或仓库。可在 Multica 的 Personal Access Tokens 设置页创建 PAT。登录态保存在宿主机的 `./data/.multica`；请不要把 token 直接写进命令行或日志。登录成功后 Make target 会重启 daemon，使它立即发现 PATH 上的 Codex、Claude、OpenCode 等 agent CLI。

如使用自托管 Multica，可先在容器中设置非敏感服务器地址，再登录：

```bash
docker compose exec multica-daemon multica config set server_url https://api.example.com
docker compose exec multica-daemon multica config set app_url https://app.example.com
make multica.login
```

daemon 只需要向 Multica API/实时连接端点和代码托管服务发起出站 HTTPS/WSS 连接，不需要暴露新的入站端口。代理、DNS 和 CA 配置需保证 `multica-daemon` 容器能访问这些地址。

### 生命周期、状态和日志

```bash
make multica.status   # daemon JSON 状态、runtime 和 watched workspace
make multica.logs     # supervisor 与 daemon 日志
make multica.restart  # 重启并重新检测 agent CLI
make multica.stop     # 单独停止 daemon 服务
make multica.smoke    # 检查 CLI、版本和持久化目录可写性
```

`docker compose ps` 的 `multica-daemon` health 状态来自 `multica daemon status`。未完成登录时 supervisor 会保持运行并等待认证，该服务显示 unhealthy 是预期行为；登录后应变为 healthy。

### 最小端到端验证

1. `make multica.status` 确认 daemon 为 running，至少发现一个 agent CLI，并 watch 到目标 workspace。
2. 在 Multica 的 Runtimes 页面确认名为 `Devcontainer` / `devcontainer` 的环境在线。
3. 将一个测试 issue 分配给该 runtime，让 agent 执行 `printf 'multica-ok\n' > /home/ubuntu/multica_workspaces/remote-smoke.txt && cat /home/ubuntu/multica_workspaces/remote-smoke.txt`。
4. 执行 `make restart`，然后再次运行 `make multica.status`，并确认上述文件仍存在。

这同时验证远程命令、文件读写、重启恢复和持久化。

### 持久化与安全边界

- `./data/.multica` → `~/.multica`：CLI 配置、PAT 和 daemon 状态。
- `./data/multica_workspaces` → `~/multica_workspaces`：daemon checkout、任务工作目录和约定的 smoke 文件。
- 现有 `./data/.codex`、`.claude`、`.ssh` 等挂载同时提供 agent 登录态；这些目录全部被 `.gitignore` 排除。
- `/workspace` 继续映射宿主机工作区；容器重启不会删除它。`make destroy` 会删除 Compose named volume，但 bind-mounted `./data` 不会被删除。
- 不要把 PAT 放入 `.env`、Dockerfile、Compose environment、Kubernetes Secret 模板或 issue 日志；使用交互登录并限制 `./data` 的宿主机访问权限。

### 故障排查和清理

- 一直等待认证：运行 `make multica.login`，然后看 `make multica.logs`。
- 没有 runtime：在 daemon 容器内运行 `command -v codex`（或其他 agent CLI），再执行 `make multica.restart`。
- daemon 离线：检查 `make multica.status`、DNS/代理/系统时间和到 Multica 服务的出站连接。
- 磁盘增长：运行 `docker compose exec multica-daemon multica daemon disk-usage`，按需清理已经完成且不再需要的 task workspace。
- 撤销本机认证：运行 `docker compose exec multica-daemon multica auth logout`，随后 `make multica.stop`。需要彻底清理时，在确认备份后手动删除 `./data/.multica` 和 `./data/multica_workspaces`；仓库不会自动删除这些数据。

## Docker

- Docker daemon 由 `docker:28-dind` sidecar 提供，`app` 通过 `DOCKER_HOST=tcp://docker:2375` 连接。
- Docker 数据持久化在 `docker-data` volume。

## VS Code

VS Code 可以继续通过 `devcontainer.json` 快速打开工作区。这个文件只引用同一份 `docker-compose.yml`，不再声明任何 feature 或 lifecycle 回调。

## k3s 部署

`deploy/` 目录（风格参考 `yangcheng-team/eastar-price` 的 `deploy/`）把这个工作区部署为 k3s 上长期运行的个人云端实例：

- 集群：`oracle-arm1`（2 节点 k3s，Traefik + cert-manager + Sealed Secrets 均为集群已有组件），namespace `devcontainer`；OpenCode 使用 `https://ai.hdgcs.com`，OpenClaw 使用 `https://claw.hdgcs.com`。
- 只有单一环境，不做 stg/prod 分层；根目录 `kustomization.yaml` 在 `deploy/` 基础资源之上生成工具配置。
- 存储：`workspace-pvc`（15Gi，空卷，不含本地历史数据）、`home-data-pvc`（8Gi，通过 subPath 对应 `~/.agents/.cache/.claude/.codex/.config/.copilot/.lark-cli/.local/.multica/.npm/.ssh/.vscode-server`、`~/multica_workspaces` 等目录及 `.claude.json`）、`openclaw-data-pvc`（8Gi，挂载到 `~/.openclaw`）、`docker-data-pvc`（15Gi，供 dind sidecar 用）。四者都用 `local-path` storageClass 并通过 `nodeSelector` 固定调度到 `arm1`。
- 配置：根目录 Kustomize overlay 从 `config/` 生成带内容哈希的 ConfigMap，挂载 OpenCode、Git、Claude 和 Codex 配置；配置变化会触发 Pod 滚动更新。
- 鉴权：`opencode web` 使用 Sealed Secret 中的 `OPENCODE_SERVER_PASSWORD`（HTTP Basic Auth，用户名默认 `opencode`）；OpenClaw Gateway 复用该 Secret 值作为 `OPENCLAW_GATEWAY_PASSWORD`，并共享 `home-data-pvc` 中持久化的 Claude Code CLI 登录态。密码不在仓库里。
- Docker-in-Docker：`dind` 是同 Pod 内的特权 sidecar，`app` 和 `openclaw` 容器通过 `DOCKER_HOST=tcp://localhost:2375` 连接（和 compose 里的 `tcp://docker:2375` 不同，这里是同一个 Pod）。
- 探针：OpenCode 使用 `tcpSocket`，避免鉴权导致 HTTP 401；OpenClaw 使用无需鉴权的 `/healthz` 和 `/readyz`。
- 首次上线时手动把本地 `./data` 下的 `.ssh`、`.claude`/`.codex` 登录态、`gh`/`lark-cli` 配置等**凭据**（不含 `.cache`/`.local`/`.vscode-server`/`.claude` 里的会话历史等可再生数据）一次性迁移进了 `home-data-pvc`；之后的更新走 CI，不再涉及这类手动数据迁移。

手动操作（需要本地 `kubectl` 已指向该集群、并安装 `kubeseal`）：

```bash
make deploy.config   # 预览根目录 kustomize overlay 渲染结果
make deploy.apply    # kubectl apply -k ./ 并等待 rollout
make deploy.status   # 查看 Pod/Service/Ingress/PVC
make deploy.logs     # 查看 app 容器日志
make deploy.bash     # 进入集群里的 app 容器
make deploy.multica-login   # 首次安全输入 PAT，并滚动重启 Pod
make deploy.multica-status  # 查询 daemon 状态
make deploy.multica-logs    # 查看 daemon 日志
```

Kubernetes 中的 daemon 是同一 Pod 内的独立 sidecar，使用 `home-data-pvc` 保存认证和任务目录；进程异常由入口脚本恢复，容器异常由 kubelet 恢复。未配置认证时 sidecar 会等待而不会 CrashLoop。首次部署完成后运行 `make deploy.multica-login`，再用 status 和 Runtimes 页面确认在线。

修改 `deploy/app-secret.yaml`（明文，已被 `deploy/.gitignore` 排除）后，用 `make deploy.encode` 重新生成 `deploy/app-sealed-secret.yaml`。

`.github/workflows/build-devcontainer.yml` 在构建镜像成功后会自动 `kubectl apply -k ./`，使用当次构建的 `commit-<short-sha>` 镜像 tag；所需的 `KUBECONFIG` secret 对应一个只在 `devcontainer` 命名空间内有权限的 ServiceAccount（非集群管理员凭据）。

## 本地数据

以下内容不会提交到 Git：

- `.env`
- `data/*`
- `agents/*`

凭证、历史记录和用户数据默认放在 `./data`，并按需挂载到 `/home/ubuntu` 下的对应路径。可提交的工具配置放在 `./config`；镜像自带的 `.bashrc`、`.profile` 和工具链配置不会被本地 `./data` 覆盖。
