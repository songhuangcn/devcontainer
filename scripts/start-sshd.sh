#!/usr/bin/env bash
# 生成/复用持久化到 home 卷里的 sshd host key，然后前台启动 sshd。
# host key 只在缺失时生成一次，容器重建不会跟着换——避免 SSH 客户端每次都要
# 重新信任新的 host key。
set -euo pipefail

HOST_KEY_DIR="${HOME}/.ssh/host_keys"
install -d -m 700 "${HOST_KEY_DIR}"
for type in ed25519 rsa; do
  key="${HOST_KEY_DIR}/ssh_host_${type}_key"
  [ -f "${key}" ] || ssh-keygen -q -t "${type}" -f "${key}" -N ''
done

# /run 每次容器启动都是空 tmpfs，sshd 的权限分离目录需要提前建好。这里只是个
# 跑一下就退出的辅助命令，不是常驻进程。
sudo install -d -m 0755 /run/sshd

# sshd 二进制带 setuid 位（见 Dockerfile），exec 直接拿到 root：不经过 sudo 包一层，
# 避免 sudo 自己常驻成为事实上的 PID 1（它从不真正 execve 到目标命令），在没有
# init 进程收养孤儿的裸 k8s Pod 里更安全。
exec /usr/sbin/sshd -D -e \
  -o "HostKey=${HOST_KEY_DIR}/ssh_host_ed25519_key" \
  -o "HostKey=${HOST_KEY_DIR}/ssh_host_rsa_key" \
  -o "PasswordAuthentication=no" \
  -o "KbdInteractiveAuthentication=no" \
  -o "PermitRootLogin=no" \
  -o "PubkeyAuthentication=yes" \
  -o "AllowUsers=ubuntu" \
  -o "X11Forwarding=no" \
  -o "PrintMotd=no"
