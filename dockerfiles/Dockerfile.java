FROM ubuntu:24.04

ARG TARGETARCH

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
    && locale-gen en_US.UTF-8 zh_CN.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir -p /opt/mise/bin /opt/mise/config \
    && chown -R ubuntu:ubuntu /opt/mise

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
    PATH=/opt/mise/bin:/opt/mise/shims:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# VS Code Server broken
# https://gist.github.com/b01/0a16b6645ab7921b0910603dfb85e4fb
ADD scripts/vscode-server-install.sh /tmp/vscode-server-install.sh
RUN bash /tmp/vscode-server-install.sh 1b6a188127eeaf9194f945eb6eb89a657e93c54c "${TARGETARCH}" && sudo rm -rf /tmp/*
# RUN curl -sSL https://gist.githubusercontent.com/b01/0a16b6645ab7921b0910603dfb85e4fb/raw/b0375bb5dd390199518a6cdf91a909ed27807119/download-vs-code-server.sh | bash -s -- linux

RUN curl https://mise.run | sh

COPY --chown=ubuntu:ubuntu dockerfiles/mise.java.toml /opt/mise/config/mise.toml

RUN mise install -y \
    && sudo mkdir -p /usr/local/lib/docker/cli-plugins \
    && sudo ln -sf "$(mise which docker-cli-plugin-docker-compose)" /usr/local/lib/docker/cli-plugins/docker-compose \
    && mise cache clear

RUN mise exec -- python -m pip install requests~=2.32.5 urllib3~=2.6.3 pymupdf

# keep permissions
RUN mkdir -p ~/.vscode-server ~/.m2 ~/.config/opencode

CMD ["sleep", "infinity"]
