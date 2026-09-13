FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository --yes universe \
    && add-apt-repository --yes multiverse \
    && rm -rf /var/lib/apt/lists/*

RUN printf 'ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true\n' | debconf-set-selections

RUN apt-get update && apt-get install -y --no-install-recommends \
    biber \
    build-essential \
    clang \
    default-jre-headless \
    fontconfig \
    fonts-croscore \
    fonts-dejavu \
    fonts-liberation \
    fonts-noto-cjk \
    ghostscript \
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
    latexmk \
    tree \
    libreoffice-writer \
    gh \
    libssl-dev \
    openssh-client \
    openssh-server \
    locales \
    poppler-utils \
    qpdf \
    sqlite3 \
    texlive-bibtex-extra \
    texlive-fonts-recommended \
    texlive-lang-chinese \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-latex-recommended \
    texlive-luatex \
    texlive-publishers \
    texlive-xetex \
    ttf-mscorefonts-installer \
    xdg-utils \
    && locale-gen en_US.UTF-8 zh_CN.UTF-8 \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

ARG SOURCE_HAN_SERIF_VERSION=2.003R
ARG SOURCE_HAN_SERIF_TC_SHA256=71354ed752104c8a3cbcff18943c6110d179d01cc6eaaf1aff7ea14c4a447879
RUN install -d /usr/local/share/fonts/opentype/source-han-serif \
    && curl --proto '=https' --tlsv1.2 -fsSL \
        "https://raw.githubusercontent.com/adobe-fonts/source-han-serif/${SOURCE_HAN_SERIF_VERSION}/Variable/TTF/SourceHanSerifTC-VF.ttf" \
        -o /usr/local/share/fonts/opentype/source-han-serif/SourceHanSerifTC-VF.ttf \
    && printf '%s  %s\n' \
        "${SOURCE_HAN_SERIF_TC_SHA256}" \
        /usr/local/share/fonts/opentype/source-han-serif/SourceHanSerifTC-VF.ttf \
        | sha256sum --check - \
    && fc-cache -f

RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# sshd 支持：删掉包安装时烘进镜像层的默认 host key（同一镜像 tag 的所有容器会
# 共享同一份，且每次重新构建都会换一批——host key 只从持久卷里生成/复用，见
# scripts/start-sshd.sh）。给 sshd 加 setuid 位，让非 root 的 ubuntu 用户能直接
# exec 起它拿到 root，不用 sudo 包一层常驻成为事实上的 PID 1。
RUN rm -f /etc/ssh/ssh_host_* && chmod u+s /usr/sbin/sshd

# 锁定版本而非官方 install.sh：该脚本没有版本锁定的开关（已读源码确认，
# releases/latest 的 302 跳转是唯一版本来源），装到的永远是构建当天的 latest，
# 不可复现。改用 release 附带的 checksums.txt 校验 + 固定版本号的资产 URL——
# 这套 `multica-cli-<version>-<os>-<arch>.tar.gz` 命名正是 multica-ai/homebrew-tap
# 的 Formula/multica.rb 由 GoReleaser 生成时用的同一 URL，稳定可依赖。
# 架构用 dpkg --print-architecture 现查，不吃 TARGETARCH：后者是 BuildKit 的
# predefined arg，只有声明了 ARG TARGETARCH 才会被自动填值，换成非 BuildKit
# 的构建路径（旧版 docker build、DOCKER_BUILDKIT=0）就会是空值，装出
# `multica-cli-0.4.43-linux-.tar.gz` 这种拼错的 URL。dpkg 直接读容器自身的
# 架构，不依赖构建器怎么传参。
ARG MULTICA_VERSION=0.4.43
RUN cd /tmp \
    && arch="$(dpkg --print-architecture)" \
    && archive="multica-cli-${MULTICA_VERSION}-linux-${arch}.tar.gz" \
    && curl -fsSL -O "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/${archive}" \
    && curl -fsSL "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/checksums.txt" \
        | grep -F " ${archive}" | sha256sum --check - \
    && tar -xzf "${archive}" -C /usr/local/bin multica \
    && rm -f "${archive}" \
    && multica version

# 镜像自带的一切都放在 /opt，构建结束时 /home/ubuntu 必须是空的。
#   /opt/mise       mise 数据目录（installs/shims/downloads/state/cache）
#   /opt/agent-bin  provider CLI 直连软链，PATH 中排在 shims 之前
#   /opt/home-skel  首启种子目录，由 devcontainer-home-init 补进 home 卷
RUN mkdir -p /opt/mise/bin /opt/agent-bin /opt/home-skel \
    && cp -a /etc/skel/. /opt/home-skel/ \
    && chown -R ubuntu:ubuntu /opt/mise /opt/agent-bin /opt/home-skel

USER ubuntu

WORKDIR /workspace

# mise 的数据/状态/缓存搬出 home。刻意不设 MISE_CONFIG_DIR：全局配置继续用
# /etc/mise/config.toml（mise 的 system config），这是当前镜像已验证可用的
# 路径；改动它才是 HDGCS-4 回退的真实风险点。
ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    SHELL=/bin/bash \
    MISE_INSTALL_PATH=/opt/mise/bin/mise \
    MISE_DATA_DIR=/opt/mise \
    MISE_CACHE_DIR=/opt/mise/cache \
    MISE_STATE_DIR=/opt/mise/state \
    PATH=/opt/agent-bin:/opt/mise/bin:/opt/mise/shims:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN curl -fsSL https://mise.run | sh

COPY mise.toml /etc/mise/config.toml
COPY --chmod=755 scripts/smoke-agent-cli-launchers.sh /usr/local/bin/smoke-agent-cli-launchers
COPY --chmod=755 scripts/home-init.sh /usr/local/bin/devcontainer-home-init
COPY --chmod=755 scripts/start-sshd.sh /usr/local/bin/devcontainer-start-sshd

# NPM_CONFIG_CACHE 只在本层生效：mise 的 npm backend（npm:@larksuite/cli）会把
# npm 缓存写进 ~/.npm，那是 home 里唯一一处几百 MB 级的构建残留。运行时仍用
# 默认的 ~/.npm（已随整挂持久化），所以不放进 ENV。
RUN NPM_CONFIG_CACHE=/tmp/npm-cache mise install \
    # Multica resolves provider executables to their canonical paths before launch.
    # A mise shim therefore turns back into the mise binary and is misinterpreted
    # as a task invocation. Put direct tool links ahead of the shim directory.
    && for tool in codex claude opencode; do \
        ln -sf "$(mise which "${tool}")" "/opt/agent-bin/${tool}"; \
    done \
    && sudo mkdir -p /usr/local/lib/docker/cli-plugins \
    && sudo ln -sf "$(mise which docker-compose)" /usr/local/lib/docker/cli-plugins/docker-compose \
    && smoke-agent-cli-launchers \
    && mise cache clear \
    && rm -rf /tmp/npm-cache

RUN mise exec -- python -m pip install --no-cache-dir \
    defusedxml \
    "jsonschema[format]>=4.17" \
    numpy \
    pypdf \
    pymupdf \
    pyyaml \
    requests~=2.32.5 \
    "ruamel.yaml>=0.17" \
    urllib3~=2.6.3

# 原来的 `mkdir -p ~/.vscode-server ~/.m2 ...` 在整挂 home 后毫无意义（会被卷
# 遮住），改为写进 skel，由首启的 devcontainer-home-init 补进卷里。
# .claude / .codex / .config/opencode 是 config 嵌套挂载的父目录，必须存在，
# 否则 Docker daemon 和 kubelet 会以 root 身份创建它们。
# 刻意不建 .local/bin：不存在时 .profile 的 PATH 前置分支不会触发。
RUN mkdir -p \
        /opt/home-skel/.vscode-server \
        /opt/home-skel/.m2 \
        /opt/home-skel/.claude \
        /opt/home-skel/.codex \
        /opt/home-skel/.config/opencode \
        /opt/home-skel/.multica \
        /opt/home-skel/multica_workspaces \
        /opt/home-skel/.cache \
        /opt/home-skel/.npm \
    && install -d -m 700 /opt/home-skel/.ssh

# 把镜像内容全部搬出 /home/ubuntu 并断言为空。这不是"清理"，是构建期硬约束：
# 以后谁往 home 里写东西，构建直接失败。
RUN find /home/ubuntu -mindepth 1 -delete \
    && if [ -n "$(ls -A /home/ubuntu)" ]; then \
         echo "FATAL: /home/ubuntu is not empty after build:" >&2; \
         ls -A /home/ubuntu >&2; exit 1; \
       fi

ENTRYPOINT ["/usr/local/bin/devcontainer-home-init", "--exec"]
CMD ["sleep", "infinity"]
