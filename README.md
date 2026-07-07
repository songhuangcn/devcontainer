# Workspace

这个仓库提供一个纯 Docker 的开发工作区，用于在可复现环境中运行 OpenCode。

## 内容

- `docker-compose.yml`：启动工作容器 `app` 和 Docker-in-Docker sidecar `docker`。
- `Dockerfile`：构建开发工具镜像，内置 OpenCode、常用 CLI、Docker CLI、Compose plugin 和 sshd。
- `devcontainer.json`：仅作为 VS Code 快速打开入口，不再使用 devcontainer features。
- `scripts/setup.sh`：生成 `.env`，并把镜像内 `/home/ubuntu` 的缺失文件合并到本地 `./data`。
- `scripts/entrypoint.sh`：容器启动时拉起 sshd 和 OpenCode Web。
- `Dockerfile.java`、`Dockerfile.paper`：Java 和论文输出扩展镜像。

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

首次使用或镜像更新后，同步默认配置到本地：

```bash
make setup
```

`make setup` 会在缺失时生成 `.env`，然后把镜像内 `/home/ubuntu` 的缺失文件复制到本地 `./data`。生成后请按提示检查 `.env`。

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

VS Code 可以继续通过 `devcontainer.json` 快速打开工作区。这个文件只引用同一份 `docker-compose.yml`，不再声明任何 feature 或 lifecycle 回调；首次使用前统一运行 `make setup`。

## 本地数据

以下内容不会提交到 Git：

- `.env`
- `data/*`
- `config/*`
- `agents/*`

凭证、历史记录和工具配置默认放在 `./data`，并通过 `./data:/home/ubuntu` 持久化到容器内。
