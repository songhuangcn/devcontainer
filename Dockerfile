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

USER ubuntu

WORKDIR /workspace

ENV TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    SHELL=/bin/bash

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
