FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository --yes universe \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    clang \
    git \
    pkg-config \
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
    libssl-dev \
    openssh-client \
    openssh-server \
    locales \
    sqlite3 \
    xdg-utils \
    && locale-gen en_US.UTF-8 zh_CN.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir -p /opt/mise/bin /opt/mise/config \
    && chown -R ubuntu:ubuntu /opt/mise

RUN mkdir -p /run/sshd \
    && printf '\nPort 2222\nPasswordAuthentication no\nPermitRootLogin no\nPubkeyAuthentication yes\n' >> /etc/ssh/sshd_config

COPY scripts/entrypoint.sh /usr/local/bin/workspace-entrypoint
RUN chmod +x /usr/local/bin/workspace-entrypoint

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

RUN curl https://mise.run | sh

COPY --chown=ubuntu:ubuntu mise.toml /opt/mise/config/mise.toml

RUN mise install \
    && sudo mkdir -p /usr/local/lib/docker/cli-plugins \
    && sudo ln -sf "$(mise which docker-compose)" /usr/local/lib/docker/cli-plugins/docker-compose \
    && mise cache clear

RUN mise exec -- python -m pip install --no-cache-dir requests~=2.32.5 urllib3~=2.6.3 pymupdf

# keep permissions
RUN mkdir -p ~/.vscode-server ~/.m2 ~/.config/opencode

ENTRYPOINT ["workspace-entrypoint"]
CMD ["sleep", "infinity"]
