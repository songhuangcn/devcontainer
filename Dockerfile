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
ARG MULTICA_VERSION=0.6.1
RUN cd /tmp \
    && arch="$(dpkg --print-architecture)" \
    && archive="multica-cli-${MULTICA_VERSION}-linux-${arch}.tar.gz" \
    && curl -fsSL -O "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/${archive}" \
    && curl -fsSL "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/checksums.txt" \
        | grep -F " ${archive}" | sha256sum --check - \
    && tar -xzf "${archive}" -C /usr/local/bin multica \
    && rm -f "${archive}" \
    && multica version

# autoteam 启动器：装成 PATH 里的 autoteam。agent 在任何项目里跑 autoteam，都用团队仓库
# （autoteam-ai/autoteam）main 最新提交的 CLI 和配置，成员仓库不用装 autoteam 的文件。
# 启动器本身很少变，按提交固定并校验 sha256；它下载的 CLI 不固定，随团队仓库走。
ARG AUTOTEAM_LAUNCHER_REF=47edf2b69b85d3a229e579f7c8f89607a7d5174b
ARG AUTOTEAM_LAUNCHER_SHA256=c3d0e9fd5546cf189e9e7094b5134e65859f95adefd425521df86efa1eb30321
RUN curl -fsSL "https://raw.githubusercontent.com/autoteam-ai/autoteam/${AUTOTEAM_LAUNCHER_REF}/skills/autoteam/bin/autoteam-launcher" \
        -o /usr/local/bin/autoteam \
    && echo "${AUTOTEAM_LAUNCHER_SHA256}  /usr/local/bin/autoteam" | sha256sum --check - \
    && chmod 755 /usr/local/bin/autoteam

# gh 不走 apt：Ubuntu 24.04 仓库里停在 2.45.0（2024 年初），缺 `gh ruleset`
# 和 `pr merge --auto` 的若干修复，都是 agent 会用到的；官方 apt 源又只提供
# stable，装到的是构建当天的版本，不可复现。它在 mise 的 registry 里
# （aqua:cli/cli，带 checksum 校验），所以和 node/python/agent CLI 一起写进
# mise.toml 统一管版本，由容器启动后的 install.sh 安装。
# multica 不在 registry 里，只能留着上面那段固定 URL。

USER ubuntu

WORKDIR /workspace

# 工具在启动后安装到持久化 home，供所有应用容器共享。
# 全局工具清单仍使用 mise 的 system config：/etc/mise/config.toml。
ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    SHELL=/bin/bash \
    MISE_INSTALL_PATH=/home/ubuntu/.local/bin/mise \
    MISE_DATA_DIR=/home/ubuntu/.local/share/mise \
    MISE_CACHE_DIR=/home/ubuntu/.cache/mise \
    MISE_STATE_DIR=/home/ubuntu/.local/state/mise \
    PATH=/home/ubuntu/.local/share/agent-bin:/home/ubuntu/.local/bin:/home/ubuntu/.local/share/mise/shims:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY mise.toml /etc/mise/config.toml
COPY --chmod=755 scripts/smoke-agent-cli-launchers.sh /usr/local/bin/smoke-agent-cli-launchers
COPY --chmod=755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 scripts/install.sh /usr/local/bin/install.sh
COPY --chmod=755 scripts/start-sshd.sh /usr/local/bin/devcontainer-start-sshd
# Compose 使用仓库目录覆盖；Kubernetes 首启复制到 Pod 的共享 agents 卷。
COPY --chown=ubuntu:ubuntu agents/ /opt/agents/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
