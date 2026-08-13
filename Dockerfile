ARG MULTICA_VERSION=0.4.24
ARG MULTICA_LINUX_AMD64_SHA256=736dd222bb4305ba1dd0f5483c8d52cd281bacf55cff04285b9dda5a96e2a140
ARG MULTICA_LINUX_ARM64_SHA256=fc889a99c77820486fbb480668c3f18cc7cb4f22d9ce76f86b8f414f02e4088c

FROM ubuntu:24.04 AS multica-cli

ARG DEBIAN_FRONTEND=noninteractive
ARG MULTICA_VERSION
ARG MULTICA_LINUX_AMD64_SHA256
ARG MULTICA_LINUX_ARM64_SHA256

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Pin the Multica CLI and verify the release archive before installing it.
RUN arch="$(dpkg --print-architecture)" \
    && case "${arch}" in \
        amd64) multica_sha256="${MULTICA_LINUX_AMD64_SHA256}" ;; \
        arm64) multica_sha256="${MULTICA_LINUX_ARM64_SHA256}" ;; \
        *) echo "Unsupported Multica CLI architecture: ${arch}" >&2; exit 1 ;; \
    esac \
    && archive="multica-cli-${MULTICA_VERSION}-linux-${arch}.tar.gz" \
    && curl --proto '=https' --tlsv1.2 -fsSL \
        "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/${archive}" \
        -o "/tmp/${archive}" \
    && printf '%s  %s\n' "${multica_sha256}" "/tmp/${archive}" | sha256sum --check - \
    && tar -xzf "/tmp/${archive}" -C /usr/local/bin multica \
    && chmod 0755 /usr/local/bin/multica \
    && rm "/tmp/${archive}" \
    && multica version

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

COPY --from=multica-cli /usr/local/bin/multica /usr/local/bin/multica
RUN multica version

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

RUN curl https://mise.run | sh

COPY --chown=ubuntu:ubuntu mise.toml /opt/mise/config/mise.toml

RUN mise install \
    && sudo mkdir -p /usr/local/lib/docker/cli-plugins \
    && sudo ln -sf "$(mise which docker-compose)" /usr/local/lib/docker/cli-plugins/docker-compose \
    && mise cache clear

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

# keep permissions
RUN mkdir -p ~/.vscode-server ~/.m2 ~/.config/opencode ~/.openclaw ~/.multica ~/multica_workspaces

COPY --chown=ubuntu:ubuntu --chmod=0755 scripts/multica-daemon-entrypoint.sh /usr/local/bin/multica-daemon-entrypoint

CMD ["sleep", "infinity"]
