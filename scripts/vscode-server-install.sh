#!/bin/sh

# Copyright 2023 Khalifah K. Shabazz
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

set -eu

PLATFORM="linux"
ARCH="${2:-}"
VERSION="${1:-}"
# 装到镜像自己的目录而不是 ~/.vscode-server：home 会被持久化卷整挂盖住。
# 首启时由 devcontainer-home-init 在卷里建软链指回这里。
SERVER_ROOT="${3:-${VSCODE_SERVER_ROOT:-${HOME}/.vscode-server}}"

if ! printf "%s" "${VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "invalid VS Code version '${VERSION}', expected x.y.z" >&2
    exit 1
fi

if [ -z "${ARCH}" ]; then
    U_NAME=$(uname -m)

    if [ "${U_NAME}" = "aarch64" ]; then
        ARCH="arm64"
    elif [ "${U_NAME}" = "x86_64" ]; then
        ARCH="x64"
    elif [ "${U_NAME}" = "armv7l" ]; then
        ARCH="armhf"
    fi
fi

case "${ARCH}" in
    amd64|x86_64)
        ARCH="x64"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    armv7l|armhf)
        ARCH="armhf"
        ;;
    x64)
        ARCH="x64"
        ;;
    *)
        echo "unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

archive="vscode-server-${PLATFORM}-${ARCH}.tar.gz"
update_url="https://update.code.visualstudio.com/${VERSION}/server-${PLATFORM}-${ARCH}/stable"

echo "downloading VS Code Server ${VERSION} for ${PLATFORM}-${ARCH}"
effective_url=$(curl --fail --location --silent --show-error \
    --output "/tmp/${archive}" \
    --write-out '%{url_effective}' \
    "${update_url}")

commit_path=${effective_url%/*}
commit_sha=${commit_path##*/}
case "${commit_sha}" in
    ''|*[!0-9a-f]*)
        echo "could not resolve VS Code commit from '${effective_url}'" >&2
        exit 1
        ;;
esac
if [ "${#commit_sha}" -ne 40 ]; then
    echo "could not resolve VS Code commit from '${effective_url}'" >&2
    exit 1
fi

echo "resolved VS Code ${VERSION} to commit ${commit_sha}"

# VS Code clients locate preinstalled servers by commit, not release version.
mkdir -p "${SERVER_ROOT}/bin/${commit_sha}"
tar --no-same-owner -xz --strip-components=1 \
    -C "${SERVER_ROOT}/bin/${commit_sha}" \
    -f "/tmp/${archive}"
cd "${SERVER_ROOT}/bin"
ln -sfn "${commit_sha}" default_version
