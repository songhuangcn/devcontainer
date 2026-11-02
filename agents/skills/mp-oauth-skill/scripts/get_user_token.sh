#!/usr/bin/env bash

set -euo pipefail
umask 077

usage() {
  cat <<'EOF'
Usage:
  get_user_token.sh [prod|staging] [start|continue|status|cancel]
  get_user_token.sh --help

Examples:
  get_user_token.sh prod start
  get_user_token.sh prod continue
  get_user_token.sh staging start

Environment variables:
  SCOPE          OAuth scope (default: public)
  BASE_URL       Override the OAuth endpoint
  CLIENT_ID      Override the public OAuth client ID
  MP_OAUTH_HOME  Pending-state directory (default: ~/.config/mp-oauth-skill)

This script uses OAuth Device Flow with a public client. It does not use a
client secret and does not depend on mplus-cli.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '错误：缺少依赖命令 %s\n' "$1" >&2
    exit 1
  fi
}

json_get() {
  local field="$1"
  jq -r --arg field "$field" '.[$field] // empty'
}

ENVIRONMENT="${1:-prod}"
ACTION="${2:-start}"

case "$ENVIRONMENT" in
  -h|--help|help)
    usage
    exit 0
    ;;
  prod|production)
    ENVIRONMENT="prod"
    DEFAULT_BASE_URL="https://apply.miracleplus.com"
    DEFAULT_CLIENT_ID="e0ZStX8PFg3zwHi3vprqCrHfn-Y9EG-GUhRAsmGIx0g"
    ;;
  staging|stage)
    ENVIRONMENT="staging"
    DEFAULT_BASE_URL="https://apply-staging.miracleplus.com"
    DEFAULT_CLIENT_ID="sG7vtEFJgJnlNBB9N68ZYa1hoNzikxAsxGvtgMmG8CY"
    ;;
  *)
    printf '错误：不支持的环境 %s\n' "$ENVIRONMENT" >&2
    usage >&2
    exit 1
    ;;
esac

case "$ACTION" in
  start|continue|status|cancel) ;;
  *)
    printf '错误：不支持的操作 %s\n' "$ACTION" >&2
    usage >&2
    exit 1
    ;;
esac

require_command curl
require_command jq

BASE_URL="${BASE_URL:-$DEFAULT_BASE_URL}"
BASE_URL="${BASE_URL%/}"
CLIENT_ID="${CLIENT_ID:-$DEFAULT_CLIENT_ID}"
SCOPE="${SCOPE:-public}"
STATE_DIR="${MP_OAUTH_HOME:-${HOME}/.config/mp-oauth-skill}"
STATE_FILE="${STATE_DIR}/${ENVIRONMENT}-device-flow.json"

case "$ACTION" in
  start)
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"

    response=$(curl -sS -X POST "${BASE_URL}/oauth/authorize_device" \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "client_id=${CLIENT_ID}" \
      --data-urlencode "scope=${SCOPE}")

    error=$(printf '%s' "$response" | json_get error)
    if [ -n "$error" ]; then
      description=$(printf '%s' "$response" | json_get error_description)
      printf '错误：发起授权失败：%s%s\n' "$error" "${description:+ - ${description}}" >&2
      exit 1
    fi

    device_code=$(printf '%s' "$response" | json_get device_code)
    user_code=$(printf '%s' "$response" | json_get user_code)
    verification_uri_complete=$(printf '%s' "$response" | json_get verification_uri_complete)
    expires_in=$(printf '%s' "$response" | json_get expires_in)
    interval=$(printf '%s' "$response" | json_get interval)
    interval="${interval:-5}"

    if [ -z "$device_code" ] || [ -z "$verification_uri_complete" ] || [ -z "$expires_in" ]; then
      printf '错误：授权服务返回内容不完整\n' >&2
      exit 1
    fi

    jq -n \
      --arg base_url "$BASE_URL" \
      --arg client_id "$CLIENT_ID" \
      --arg scope "$SCOPE" \
      --arg device_code "$device_code" \
      --arg user_code "$user_code" \
      --arg verification_uri_complete "$verification_uri_complete" \
      --argjson expires_in "$expires_in" \
      --argjson interval "$interval" \
      --argjson saved_at "$(date +%s)" \
      '{base_url: $base_url, client_id: $client_id, scope: $scope, device_code: $device_code, user_code: $user_code, verification_uri_complete: $verification_uri_complete, expires_in: $expires_in, interval: $interval, saved_at: $saved_at}' \
      > "$STATE_FILE"

    chmod 600 "$STATE_FILE"
    printf '请在浏览器中打开以下链接并完成授权：\n%s\n' "$verification_uri_complete"
    printf '用户代码：%s\n' "$user_code"
    printf '授权有效期：%s 秒\n' "$expires_in"
    printf '授权完成后运行：%s %s continue\n' "$0" "$ENVIRONMENT"
    ;;

  continue)
    if [ ! -f "$STATE_FILE" ]; then
      printf '错误：没有待处理的 %s 授权，请先运行 start\n' "$ENVIRONMENT" >&2
      exit 1
    fi

    state=$(<"$STATE_FILE")
    saved_base_url=$(printf '%s' "$state" | json_get base_url)
    saved_client_id=$(printf '%s' "$state" | json_get client_id)
    saved_scope=$(printf '%s' "$state" | json_get scope)
    device_code=$(printf '%s' "$state" | json_get device_code)
    expires_in=$(printf '%s' "$state" | json_get expires_in)
    interval=$(printf '%s' "$state" | json_get interval)
    saved_at=$(printf '%s' "$state" | json_get saved_at)
    deadline=$((saved_at + expires_in))

    if [ "$(date +%s)" -ge "$deadline" ]; then
      rm -f "$STATE_FILE"
      printf '错误：授权请求已过期，请重新运行 start\n' >&2
      exit 1
    fi

    printf '正在等待用户授权...\n' >&2
    while [ "$(date +%s)" -lt "$deadline" ]; do
      response=$(curl -sS -X POST "${saved_base_url}/oauth/token" \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:device_code' \
        --data-urlencode "device_code=${device_code}" \
        --data-urlencode "client_id=${saved_client_id}")

      access_token=$(printf '%s' "$response" | json_get access_token)
      if [ -n "$access_token" ]; then
        rm -f "$STATE_FILE"
        printf 'ACCESS_TOKEN=%s\n' "$access_token"
        exit 0
      fi

      error=$(printf '%s' "$response" | json_get error)
      case "$error" in
        authorization_pending)
          sleep "$interval"
          ;;
        slow_down)
          interval=$((interval + 5))
          sleep "$interval"
          ;;
        access_denied)
          rm -f "$STATE_FILE"
          printf '错误：用户拒绝了授权请求\n' >&2
          exit 1
          ;;
        expired_token|invalid_grant)
          rm -f "$STATE_FILE"
          printf '错误：授权请求已失效，请重新运行 start\n' >&2
          exit 1
          ;;
        *)
          description=$(printf '%s' "$response" | json_get error_description)
          printf '错误：换取 token 失败：%s%s\n' "${error:-unknown_error}" "${description:+ - ${description}}" >&2
          exit 1
          ;;
      esac
    done

    rm -f "$STATE_FILE"
    printf '错误：等待授权超时，请重新运行 start\n' >&2
    exit 1
    ;;

  status)
    if [ ! -f "$STATE_FILE" ]; then
      printf '没有待处理的 %s 授权\n' "$ENVIRONMENT"
      exit 0
    fi

    state=$(<"$STATE_FILE")
    saved_at=$(printf '%s' "$state" | json_get saved_at)
    expires_in=$(printf '%s' "$state" | json_get expires_in)
    verification_uri_complete=$(printf '%s' "$state" | json_get verification_uri_complete)
    remaining=$((saved_at + expires_in - $(date +%s)))
    if [ "$remaining" -le 0 ]; then
      printf '待处理的 %s 授权已过期\n' "$ENVIRONMENT"
    else
      printf '待处理环境：%s\n剩余时间：%s 秒\n授权链接：%s\n' "$ENVIRONMENT" "$remaining" "$verification_uri_complete"
    fi
    ;;

  cancel)
    rm -f "$STATE_FILE"
    printf '已取消 %s 授权\n' "$ENVIRONMENT"
    ;;
esac
