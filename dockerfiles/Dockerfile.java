FROM ubuntu:24.04

ARG TARGETARCH
ARG VSCODE_VERSION

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    procps \
    sudo \
    unzip \
    gnupg2 \
    vim \
    curl \
    ca-certificates \
    make \
    less \
    lsof \
    man-db \
    jq \
    tree \
    gh \
    openssh-client \
    locales \
    sqlite3 \
    xdg-utils \
    && locale-gen en_US.UTF-8 zh_CN.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 镜像自带的一切都放在 /opt，构建结束时 /home/ubuntu 必须是空的。
#   /opt/mise           mise 数据/配置目录
#   /opt/vscode-server  预装的 VS Code Server（556 MB，不进 home 卷）
#   /opt/home-skel      首启种子目录，由 devcontainer-home-init 补进 home 卷
RUN mkdir -p /opt/mise/bin /opt/mise/config /opt/vscode-server /opt/home-skel \
    && cp -a /etc/skel/. /opt/home-skel/ \
    && chown -R ubuntu:ubuntu /opt/mise /opt/vscode-server /opt/home-skel

USER ubuntu

WORKDIR /workspace

ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    SHELL=/bin/bash \
    MISE_BASE_DIR=/opt/mise \
    MISE_INSTALL_PATH=/opt/mise/bin/mise \
    MISE_DATA_DIR=/opt/mise \
    MISE_CONFIG_DIR=/opt/mise/config \
    MISE_CACHE_DIR=/opt/mise/cache \
    MISE_STATE_DIR=/opt/mise/state \
    VSCODE_SERVER_ROOT=/opt/vscode-server \
    PATH=/opt/mise/bin:/opt/mise/shims:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Preinstall VS Code Server for dev container connections.
# https://gist.github.com/b01/0a16b6645ab7921b0910603dfb85e4fb
COPY --chown=ubuntu:ubuntu scripts/vscode-server-install.sh dockerfiles/vscode.java.version /tmp/
COPY --chmod=755 scripts/home-init.sh /usr/local/bin/devcontainer-home-init
RUN vscode_version="${VSCODE_VERSION:-$(cat /tmp/vscode.java.version)}" \
    && bash /tmp/vscode-server-install.sh "${vscode_version}" "${TARGETARCH}" \
    && rm -f /tmp/vscode-server-install.sh /tmp/vscode.java.version /tmp/vscode-server-linux-*.tar.gz
RUN curl https://mise.run | sh

COPY --chown=ubuntu:ubuntu dockerfiles/mise.java.toml /opt/mise/config/mise.toml

RUN mise install -y \
    && sudo mkdir -p /usr/local/lib/docker/cli-plugins \
    && sudo ln -sf "$(mise which docker-compose)" /usr/local/lib/docker/cli-plugins/docker-compose \
    && mise cache clear

RUN mise exec -- python -m pip install --no-cache-dir requests~=2.32.5 urllib3~=2.6.3 pymupdf

# 原来的 `mkdir -p ~/...` 在整挂 home 后毫无意义（会被卷遮住），改为写进 skel，
# 由首启的 devcontainer-home-init 补进卷里。
RUN mkdir -p \
        /opt/home-skel/.vscode-server \
        /opt/home-skel/.m2 \
        /opt/home-skel/.config/opencode

# 把镜像内容全部搬出 /home/ubuntu 并断言为空。这不是"清理"，是构建期硬约束：
# 以后谁往 home 里写东西，构建直接失败。
RUN find /home/ubuntu -mindepth 1 -delete \
    && if [ -n "$(ls -A /home/ubuntu)" ]; then \
         echo "FATAL: /home/ubuntu is not empty after build:" >&2; \
         ls -A /home/ubuntu >&2; exit 1; \
       fi

ENTRYPOINT ["/usr/local/bin/devcontainer-home-init", "--exec"]
CMD ["sleep", "infinity"]
