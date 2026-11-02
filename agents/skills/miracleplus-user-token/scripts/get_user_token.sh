#!/bin/bash
# ===========================================================================
# MiraclePlus user access token 获取脚本（authorization_code + PKCE）
# ===========================================================================
#
# 用途：以「你本人的用户身份」在 MiraclePlus 环境走 OAuth 授权，拿到一个
#       绑定到你账号的 access token。
#
# 用法：
#   ./get_user_token.sh [prod|staging]
#   ./get_user_token.sh --help
#
# 环境：
#   prod     https://build.miracleplus.com（默认）
#   staging  https://build-staging.miracleplus.com
#
# 流程：
#   1. 脚本打印授权链接。
#   2. 你登录并点「授权」后，浏览器会跳转到一个打不开的页面（正常现象）。
#   3. 把浏览器地址栏里的完整 URL 复制，粘贴回终端。
#   4. 脚本用授权码换出 access token 并打印出来。
#
# 可选环境变量覆盖：
#   SCOPE / REDIRECT_URI
#   BASE_URL / CLIENT_ID / CLIENT_SECRET
#   PROD_CLIENT_ID / PROD_CLIENT_SECRET
#   STAGING_CLIENT_ID / STAGING_CLIENT_SECRET
# ===========================================================================

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  get_user_token.sh [prod|staging]

Examples:
  get_user_token.sh prod
  get_user_token.sh staging

Environment variables:
  SCOPE, REDIRECT_URI
  BASE_URL, CLIENT_ID, CLIENT_SECRET
  PROD_CLIENT_ID, PROD_CLIENT_SECRET
  STAGING_CLIENT_ID, STAGING_CLIENT_SECRET
EOF
}

ENVIRONMENT="${1:-prod}"
case "$ENVIRONMENT" in
  -h|--help|help)
    usage
    exit 0
    ;;
  prod|production)
    ENVIRONMENT="prod"
    DEFAULT_BASE_URL="https://build.miracleplus.com"
    DEFAULT_CLIENT_ID="${PROD_CLIENT_ID:-KKIk0p6n7xkaxn1GZPdpKsf3Tn_9_ZzhOh2SnvmoTLA}"
    DEFAULT_CLIENT_SECRET="${PROD_CLIENT_SECRET:-LyYWa-JS-STFTQwIfca6N3hfJg1DlIIb3ge-G7uAj08}"
    ;;
  staging|stage)
    ENVIRONMENT="staging"
    DEFAULT_BASE_URL="https://build-staging.miracleplus.com"
    DEFAULT_CLIENT_ID="${STAGING_CLIENT_ID:-${PROD_CLIENT_ID:-KKIk0p6n7xkaxn1GZPdpKsf3Tn_9_ZzhOh2SnvmoTLA}}"
    DEFAULT_CLIENT_SECRET="${STAGING_CLIENT_SECRET:-${PROD_CLIENT_SECRET:-LyYWa-JS-STFTQwIfca6N3hfJg1DlIIb3ge-G7uAj08}}"
    ;;
  *)
    echo "Unsupported environment: $ENVIRONMENT" >&2
    usage >&2
    exit 1
    ;;
esac

BASE_URL="${BASE_URL:-$DEFAULT_BASE_URL}"
CLIENT_ID="${CLIENT_ID:-$DEFAULT_CLIENT_ID}"
CLIENT_SECRET="${CLIENT_SECRET:-$DEFAULT_CLIENT_SECRET}"
SCOPE="${SCOPE:-public}"
REDIRECT_URI="${REDIRECT_URI:-http://localhost:9090/callback}"

GREEN=$'\033[32m'
RED=$'\033[31m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

log_step() { printf '%s%s%s%s\n' "$CYAN" "$BOLD" "$1" "$RESET"; }
log_ok()   { printf '%s✓ %s%s\n' "$GREEN" "$1" "$RESET"; }
log_err()  { printf '%s✗ %s%s\n' "$RED" "$1" "$RESET" >&2; }
log_warn() { printf '%s%s%s\n' "$YELLOW" "$1" "$RESET"; }

json_get() {
  local field="$1"
  ruby -rjson -e "puts JSON.parse(STDIN.read)['${field}'].to_s" 2>/dev/null || true
}

pretty() {
  ruby -rjson -e 'puts JSON.pretty_generate(JSON.parse(STDIN.read))' 2>/dev/null || cat
}

generate_random_string() {
  local length=$1
  openssl rand -base64 "$length" | tr -dc 'A-Za-z0-9' | head -c "$length"
}

generate_code_challenge() {
  local verifier=$1
  printf '%s' "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='
}

urlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
    c=${string:$pos:1}
    case "$c" in
      [-_.~a-zA-Z0-9] ) o="${c}" ;;
      * )               printf -v o '%%%02x' "'$c"
    esac
    encoded+="${o}"
  done
  printf '%s\n' "${encoded}"
}

log_step "OAuth authorization_code + PKCE 流程（${ENVIRONMENT}）"
printf '  BASE_URL:     %s\n' "${BASE_URL}"
printf '  Scope:        %s\n' "${SCOPE}"
printf '  Redirect URI: %s\n' "${REDIRECT_URI}"
printf '\n'

code_verifier=$(generate_random_string 64)
code_challenge=$(generate_code_challenge "$code_verifier")
state=$(generate_random_string 32)

printf '  Code Verifier:  %s\n' "${code_verifier}"
printf '  Code Challenge: %s\n' "${code_challenge}"
printf '  State:          %s\n' "${state}"
printf '\n'

auth_url="${BASE_URL}/oauth/authorize"
auth_url+="?client_id=$(urlencode "$CLIENT_ID")"
auth_url+="&redirect_uri=$(urlencode "$REDIRECT_URI")"
auth_url+="&response_type=code"
auth_url+="&scope=$(urlencode "$SCOPE")"
auth_url+="&state=$(urlencode "$state")"
auth_url+="&code_challenge=$(urlencode "$code_challenge")"
auth_url+="&code_challenge_method=S256"

log_warn "${BOLD}请在浏览器中打开以下链接完成授权：${RESET}"
printf '\n%s%s%s\n\n' "$CYAN" "$auth_url" "$RESET"
log_warn "授权后浏览器会跳转到一个无法访问的页面（正常现象）。"
log_warn "请复制浏览器地址栏中的完整 URL 并粘贴到下方。"
printf '\n'

if command -v open >/dev/null 2>&1; then
  open "$auth_url" 2>/dev/null || true
fi

printf '请粘贴回调 URL: '
read -r callback_response

auth_code=""
returned_state=""
if [[ "$callback_response" =~ code=([^&]+) ]]; then
  auth_code="${BASH_REMATCH[1]}"
else
  log_err "无法从回调 URL 中解析出授权码（code）"
  exit 1
fi

if [[ "$callback_response" =~ state=([^&]+) ]]; then
  returned_state="${BASH_REMATCH[1]}"
else
  log_err "无法从回调 URL 中解析出 state"
  exit 1
fi

log_ok "授权码: ${auth_code:0:20}..."
log_ok "State:  ${returned_state:0:20}..."

if [ "$returned_state" != "$state" ]; then
  log_err "State 参数不匹配（可能的 CSRF），中止"
  exit 1
fi
printf '\n'

log_step "用授权码换取 access_token"
token_response=$(curl -sS -X POST "${BASE_URL}/oauth/token" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=authorization_code" \
  -d "code=${auth_code}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${code_verifier}")

printf '  Token Response:\n'
printf '%s\n' "$token_response" | pretty
printf '\n'

access_token=$(printf '%s\n' "$token_response" | json_get "access_token")

if [ -z "$access_token" ]; then
  log_err "获取 access_token 失败"
  exit 1
fi

printf '\n'
printf '%s%s============================================================%s\n' "$GREEN" "$BOLD" "$RESET"
printf '%s%s  Access Token 已获取，请复制下面这一行：%s\n' "$GREEN" "$BOLD" "$RESET"
printf '%s%s============================================================%s\n' "$GREEN" "$BOLD" "$RESET"
printf '\n%s%s%s\n\n' "$CYAN" "$access_token" "$RESET"
log_ok "完成。把上面这段 token 填入 ACCESS_TOKEN=... 即可调用 OpenAPI。"
