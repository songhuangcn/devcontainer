# Workspace

这个仓库提供一个纯 Docker 的开发工作区，用于在可复现环境中运行 OpenCode。

## 内容

- `docker-compose.yml`：启动工作容器 `app` 和 Docker-in-Docker sidecar `docker`。
- `Dockerfile`：构建开发工具镜像，内置 OpenCode、常用 CLI、Docker CLI、Compose plugin 和 sshd。
- `devcontainer.json`：仅作为 VS Code 快速打开入口，不再使用 devcontainer features。
- `scripts/setup.sh`：准备本地 `./data` 下的持久化用户数据路径。
- `scripts/entrypoint.sh`：容器启动时拉起 sshd 和 OpenCode Web。
- `dockerfiles/Dockerfile.java`、`dockerfiles/Dockerfile.paper`：Java 和论文输出扩展镜像。

## 镜像

CI 发布以下镜像：

- `songhuangcn/devcontainer:latest` / `songhuangcn/devcontainer:commit-<short-sha>`
- `songhuangcn/workspace-java:latest` / `songhuangcn/workspace-java:commit-<short-sha>`
- `songhuangcn/workspace-paper:latest` / `songhuangcn/workspace-paper:commit-<short-sha>`

`songhuangcn/devcontainer` 虽然保留原名称，但现在是纯 Docker 镜像，不依赖 devcontainer feature。

## 前置依赖

只需要 Docker 和 Docker Compose：

```bash
docker --version
docker compose version
```

不再需要安装 `devcontainer` CLI。

## 本地使用

如需自动创建 `.env` 和必需的文件型挂载，可运行：

```bash
make setup
```

`make setup` 会在缺失时从 `.env.sample` 创建 `.env`，并创建 Compose 会挂载到 `/home/ubuntu` 的必需空文件。这个步骤不是启动前置条件；目录型挂载可由 Docker 自动创建，文件型挂载在文件不存在时会直接报错。

必需存在的文件包括 `.env`、`./data/.claude.json` 和 `./data/.gitconfig`。如果不想运行 `make setup`，也可以手动创建这些文件。

镜像内置工具链由 `/opt/mise` 管理，不放在 `/home/ubuntu` 下。`docker-compose.yml` 只挂载选定的用户数据路径，因此 `.bashrc`、`.profile` 等 shell 启动文件继续使用镜像内版本。Docker Compose plugin 的系统级入口位于 `/usr/local/lib/docker/cli-plugins/docker-compose`。

如果旧的 `./data/.bashrc`、`./data/.profile` 仍存在，它们不会再挂载到容器内。

启动容器和 OpenCode Web：

```bash
make start
```

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

## Docker 与 SSH

- Docker daemon 由 `docker:28-dind` sidecar 提供，`app` 通过 `DOCKER_HOST=tcp://docker:2375` 连接。
- Docker 数据持久化在 `docker-data` volume。
- sshd 由 `app` 容器 entrypoint 启动，监听容器内 `2222` 端口。
- SSH 默认不发布到宿主机；需要外部连接时，在 `docker-compose.yml` 的 `app.ports` 中启用 `"2222:2222"`。
- 公钥认证读取 `./data/.ssh/authorized_keys`。

## VS Code

VS Code 可以继续通过 `devcontainer.json` 快速打开工作区。这个文件只引用同一份 `docker-compose.yml`，不再声明任何 feature 或 lifecycle 回调。

## k3s 部署

`deploy/` 目录（风格参考 `yangcheng-team/eastar-price` 的 `deploy/`）把这个工作区部署为 k3s 上长期运行的个人云端实例：

- 集群：`oracle-arm1`（2 节点 k3s，Traefik + cert-manager + Sealed Secrets 均为集群已有组件），namespace `devcontainer`，域名 `https://devcontainer.hdgcs.com`。
- 只有单一环境，不做 stg/prod 分层；`deploy/kustomization.yaml` 直接管理全部资源。
- 存储：`workspace-pvc`（15Gi，空卷，不含本地历史数据）、`home-data-pvc`（8Gi，通过 subPath 对应 `~/.agents/.cache/.claude/.codex/.config/.copilot/.lark-cli/.local/.npm/.ssh/.vscode-server` 等目录及 `.claude.json`/`.gitconfig`）、`docker-data-pvc`（15Gi，供 dind sidecar 用）。三者都用 `local-path` storageClass 并通过 `nodeSelector` 固定调度到 `arm1`。
- 鉴权：`opencode web` 原生的 `OPENCODE_SERVER_PASSWORD`（HTTP Basic Auth，用户名默认 `opencode`），通过 Sealed Secret (`deploy/app-sealed-secret.yaml`) 注入，密码只有本人保存的一份，不在仓库里。
- Docker-in-Docker：`dind` 是同 Pod 内的特权 sidecar，`app` 容器通过 `DOCKER_HOST=tcp://localhost:2375` 连接（和 compose 里的 `tcp://docker:2375` 不同，这里是同一个 Pod）。
- 探针用 `tcpSocket` 而不是 `httpGet`：因为设置了 `OPENCODE_SERVER_PASSWORD` 后 `/global/health` 也需要 Basic Auth，`httpGet` 探针拿不到密码会一直 401。
- 首次上线时手动把本地 `./data` 下的 `.ssh`、`.claude`/`.codex` 登录态、`gh`/`lark-cli` 配置等**凭据**（不含 `.cache`/`.local`/`.vscode-server`/`.claude` 里的会话历史等可再生数据）一次性迁移进了 `home-data-pvc`；之后的更新走 CI，不再涉及这类手动数据迁移。

手动操作（需要本地 `kubectl` 已指向该集群、并安装 `kubeseal`）：

```bash
make deploy.config   # 预览 kustomize 渲染结果
make deploy.apply    # kubectl apply -k deploy/ 并等待 rollout
make deploy.status   # 查看 Pod/Service/Ingress/PVC
make deploy.logs     # 查看 app 容器日志
make deploy.bash     # 进入集群里的 app 容器
```

修改 `deploy/app-secret.yaml`（明文，已被 `deploy/.gitignore` 排除）后，用 `make deploy.encode` 重新生成 `deploy/app-sealed-secret.yaml`。

`.github/workflows/build-devcontainer.yml` 在构建镜像成功后会自动 `kubectl apply -k deploy/`，使用当次构建的 `commit-<short-sha>` 镜像 tag；所需的 `KUBECONFIG` secret 对应一个只在 `devcontainer` 命名空间内有权限的 ServiceAccount（非集群管理员凭据）。

## 本地数据

以下内容不会提交到 Git：

- `.env`
- `data/*`
- `config/*`
- `agents/*`

凭证、历史记录和用户数据默认放在 `./data`，并按需挂载到 `/home/ubuntu` 下的对应路径。镜像自带的 `.bashrc`、`.profile` 和工具链配置不会被本地 `./data` 覆盖。
