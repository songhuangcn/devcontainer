#!/bin/sh
set -u

retry_seconds="${MULTICA_DAEMON_RESTART_DELAY:-10}"
child_pid=""

log() {
  printf '[multica-daemon] %s\n' "$*"
}

stop_child() {
  if [ -n "${child_pid}" ]; then
    kill -TERM "${child_pid}" 2>/dev/null || true
    wait "${child_pid}" 2>/dev/null || true
  fi
  exit 0
}

wait_before_retry() {
  sleep "${retry_seconds}" &
  child_pid=$!
  wait "${child_pid}" || true
  child_pid=""
}

check_installation() {
  command -v multica >/dev/null 2>&1 || {
    log 'multica is not on PATH.'
    return 1
  }
  multica version
  mkdir -p "${HOME}/.multica" "${MULTICA_WORKSPACES_ROOT:-${HOME}/multica_workspaces}"
  test -w "${HOME}/.multica"
  test -w "${MULTICA_WORKSPACES_ROOT:-${HOME}/multica_workspaces}"
  log 'CLI and persistent directories are ready.'
}

if [ "${1:-}" = "--check" ]; then
  check_installation
  exit $?
fi

trap stop_child INT TERM HUP

check_installation || exit 1

while :; do
  if ! multica auth status >/dev/null 2>&1; then
    log 'waiting for authentication; run `make multica.login` on the host.'
    wait_before_retry
    continue
  fi

  log 'starting foreground daemon.'
  multica daemon start --foreground --no-auto-update --no-auto-reload &
  child_pid=$!
  wait "${child_pid}"
  daemon_status=$?
  child_pid=""
  log "daemon exited with status ${daemon_status}; retrying in ${retry_seconds}s."
  wait_before_retry
done
