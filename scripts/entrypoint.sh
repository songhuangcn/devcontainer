#!/usr/bin/env bash
set -euo pipefail

if [ -d "${HOME}/.ssh" ]; then
  chmod 700 "${HOME}/.ssh" 2>/dev/null || true
  [ -f "${HOME}/.ssh/authorized_keys" ] && chmod 600 "${HOME}/.ssh/authorized_keys" || true
fi

if [ -f "${HOME}/.bashrc" ] && grep -q '/home/ubuntu/.local/bin/mise activate bash' "${HOME}/.bashrc"; then
  sed -i '\#/home/ubuntu/.local/bin/mise activate bash#d' "${HOME}/.bashrc"
fi

sudo mkdir -p /run/sshd
sudo ssh-keygen -A >/dev/null 2>&1 || true

if ! pgrep -x sshd >/dev/null 2>&1; then
  sudo /usr/sbin/sshd
fi

start_opencode() {
  local port="${OPENCODE_PORT:-4096}"
  local host="${OPENCODE_HOST:-0.0.0.0}"
  local log_file="${OPENCODE_LOG_FILE:-/tmp/opencode-web.log}"

  if [ "${OPENCODE_AUTO_START:-1}" = "0" ]; then
    return 0
  fi

  if lsof -ti "tcp:${port}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "opencode web already listening on ${port}."
    return 0
  fi

  if ! command -v opencode >/dev/null 2>&1; then
    echo "opencode command not found; skip web startup." >&2
    return 0
  fi

  setsid -f opencode web --port "${port}" --hostname "${host}" >>"${log_file}" 2>&1 < /dev/null || true
  sleep 1

  if lsof -ti "tcp:${port}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "opencode web started on ${host}:${port} (log: ${log_file})."
  else
    echo "opencode web failed to listen on ${host}:${port}; see ${log_file}." >&2
  fi
}

start_opencode

exec "$@"
