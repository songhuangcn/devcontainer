#!/usr/bin/env bash
# 给 agent 铸一个 GitHub App 的 installation token。每个角色一个 App，身份互不相同，
# 这样"写代码的不能评审自己"由平台保证：GitHub 不允许 PR 作者批准自己的 PR，而
# Implementer 和 Reviewer 是两个不同的 App 身份。
#
# 用法：
#   .autoteam/scripts/gh-app-token.sh --run <角色> <命令...>  带这个角色的身份跑命令（最常用）
#   .autoteam/scripts/gh-app-token.sh <角色>              只打印 token
#   .autoteam/scripts/gh-app-token.sh --setup-git <角色>  给当前 clone 配好 git 身份和凭据（每次 clone 后跑一次）
#   .autoteam/scripts/gh-app-token.sh --identity <角色>   打印 git 提交身份：name<TAB>email
#   .autoteam/scripts/gh-app-token.sh --credential <角色> git 凭据助手模式（git push 用）
#   .autoteam/scripts/gh-app-token.sh --find-key <角色>   只打印按下面顺序找到的私钥路径（doctor 用，不联网）
#   .autoteam/scripts/gh-app-token.sh --installation <角色>  打印这个 App 在本仓库的安装信息 JSON（doctor 用）
#
# agent 每次工具调用都是新 shell，export 出来的变量活不到下一条命令，所以一律用 --run：
#   .autoteam/scripts/gh-app-token.sh --run implementer gh pr create --title ...
#
# 角色是 implementer / reviewer / planner，对应 autoteam.conf 里的 AUTOTEAM_<角色大写>_APP_ID。
# 私钥按这个顺序找，文件名只要带上角色名就行（GitHub 下载时的原始名字也可以）：
#   1. AUTOTEAM_<角色大写>_APP_KEY  环境变量直接给路径
#   2. .autoteam/local/            仓库里，不提交
#   3. autoteam.conf 的 AUTOTEAM_KEYS_DIR（默认 ~/.autoteam）  机器上的固定位置
# 第 3 条是给 agent 用的：它每次 checkout 都是新目录，私钥放仓库里就要跟着重放一遍。
#
# token 有效期 1 小时，缓存在 ~/.cache/autoteam 下（权限 600），剩余不足 5 分钟才重铸。
# 依赖 openssl、curl、jq。不要把输出写进日志或评论。
set -o pipefail

die() { printf 'gh-app-token：%s\n' "$*" >&2; exit 1; }

mode=token role=
case ${1:-} in
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --identity) mode=identity; role=${2:-} ;;
  --setup-git) mode=setup-git; role=${2:-} ;;
  --credential) mode=credential; role=${2:-} ;;
  --find-key) mode=find-key; role=${2:-} ;;
  --installation) mode=installation; role=${2:-} ;;
  --run) mode=run; role=${2:-}; shift 2 2>/dev/null || true; RUN_CMD=("$@") ;;
  -*) die "未知选项：$1" ;;
  *) role=${1:-} ;;
esac
[ -n "$role" ] || die "要指定角色：implementer / reviewer / planner"
[ "$mode" != run ] || [ "${#RUN_CMD[@]}" -gt 0 ] || die "--run <角色> 后面要跟要执行的命令"

# git 凭据助手只在 get 时应答；store / erase 什么都不做（token 是现铸的，不需要存）
if [ "$mode" = credential ] && [ "${3:-get}" != get ]; then exit 0; fi

case $role in
  implementer|reviewer|planner) ;;
  *) die "角色只能是 implementer / reviewer / planner，收到：$role" ;;
esac
# 键名直接由角色名推导：implementer -> AUTOTEAM_IMPLEMENTER_APP_ID
role_upper=$(printf '%s' "$role" | tr '[:lower:]' '[:upper:]')
conf_key=AUTOTEAM_${role_upper}_APP_ID
key_env=AUTOTEAM_${role_upper}_APP_KEY

for cmd in openssl curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || die "缺少命令 $cmd"
done

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "不在 git 仓库里"
conf="$root/.autoteam/autoteam.conf"
conf_get() { sed -n "s/^$1=//p" "$conf" 2>/dev/null | head -n 1 | tr -d '[:space:]'; }
# 把开头的 ~ 展开成 $HOME。shell 只对字面量里的波浪号做展开，从配置文件或环境变量
# 读出来的是普通字符，要自己处理。
# shellcheck disable=SC2088  # 下面 case 的 pattern 是字面量 ~，本来就不该展开
expand_tilde() {
  case $1 in
    "~") printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# 路径类的配置不能像上面那样删掉所有空白——目录名里可能有空格，只去掉首尾
conf_get_path() {
  local v
  v=$(sed -n "s/^$1=//p" "$conf" 2>/dev/null | head -n 1) || return 0
  v=${v#"${v%%[![:space:]]*}"}
  v=${v%"${v##*[![:space:]]}"}
  expand_tilde "$v"
}

app_id=${!conf_key:-}
[ -n "$app_id" ] || app_id=$(conf_get "$conf_key")
[ -n "$app_id" ] || die "autoteam.conf 里没有 $conf_key：先按 docs 建好 App 并把 App ID 填进去"

# 在一个目录里找这个角色的私钥：先按约定名字，再按角色名匹配——这样 GitHub 下载时
# 带日期的原始文件名（autoteam-implementer.2026-01-01.private-key.pem）不用改名也能用
find_key_in() {
  local dir=$1 found count
  [ -d "$dir" ] || return 1
  if [ -r "$dir/$role.pem" ]; then printf '%s' "$dir/$role.pem"; return 0; fi
  found=$(find "$dir" -maxdepth 1 -name "*$role*.pem" 2>/dev/null | sort)
  count=$(printf '%s\n' "$found" | grep -c . || true)
  case $count in
    1) printf '%s' "$found"; return 0 ;;
    0) return 1 ;;
    *) die "$dir 里有多个匹配 $role 的 .pem，留一个或用 $key_env 指定：$(printf '%s ' "$found" | tr '\n' ' ')" ;;
  esac
}

# 和 App ID 一样：环境变量优先于配置文件，方便临时覆盖
keys_dir=${AUTOTEAM_KEYS_DIR:-}
[ -n "$keys_dir" ] || keys_dir=$(conf_get_path AUTOTEAM_KEYS_DIR)
[ -n "$keys_dir" ] || keys_dir="$HOME/.autoteam"
keys_dir=$(expand_tilde "$keys_dir")

key=${!key_env:-}
if [ -z "$key" ]; then
  key=$(find_key_in "$root/.autoteam/local") \
    || key=$(find_key_in "$keys_dir") \
    || die "找不到 $role 的私钥。把 App 的 .pem 放进 .autoteam/local/（不会被提交）或 $keys_dir，文件名带上 $role；也可以用 $key_env 直接指路径"
fi
[ -r "$key" ] || die "读不到私钥 $key"
if [ "$mode" = find-key ]; then printf '%s\n' "$key"; exit 0; fi

repo=$(conf_get AUTOTEAM_REPO)
[ -n "$repo" ] || die "autoteam.conf 里没有 AUTOTEAM_REPO"

cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/autoteam
cache="$cache_dir/$(printf '%s' "$repo-$role" | tr -c '[:alnum:]._-' '-').token"

emit() {  # token
  case $mode in
    credential) printf 'username=x-access-token\npassword=%s\n' "$1" ;;
    run) GH_TOKEN=$1 GITHUB_TOKEN=$1 exec "${RUN_CMD[@]}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# 缓存里还剩 5 分钟以上就直接用。文件格式：第一行到期时间戳，第二行 token
if [ "$mode" != identity ] && [ "$mode" != setup-git ] && [ "$mode" != installation ] && [ -r "$cache" ]; then
  cached_exp=$(sed -n 1p "$cache")
  cached_tok=$(sed -n 2p "$cache")
  if [ -n "$cached_tok" ] && [ "${cached_exp:-0}" -gt "$(($(date +%s) + 300))" ] 2>/dev/null; then
    emit "$cached_tok"; exit 0
  fi
fi

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
# iat 往前挪 60 秒，容忍本机和 GitHub 的时钟差；App 的 JWT 最长只能活 10 分钟
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now - 60))" "$((now + 540))" "$app_id" | b64url)
signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$key" -binary | b64url) ||
  die "用 $key 签名失败：确认它是 App 的私钥（PEM 格式）"
jwt="$header.$payload.$signature"

api() {  # 方法 路径 [凭据，默认用 App 的 JWT]
  local out code rc cred=${3:-$jwt}
  # 凭据经 stdin 传入，避免出现在 curl 的进程参数里。
  # 单位为秒，支持小数；curl 自己校验环境变量的取值。
  local connect_timeout=${AUTOTEAM_GH_CONNECT_TIMEOUT:-10}
  local max_time=${AUTOTEAM_GH_MAX_TIME:-60}
  out=$(printf 'Authorization: Bearer %s\n' "$cred" | curl -sS -w '\n%{http_code}' -X "$1" \
    --connect-timeout "$connect_timeout" --max-time "$max_time" \
    -H @- \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "https://api.github.com$2")
  rc=$?
  case $rc in
    0) ;;
    28) die "调用 GitHub 超时：$2（连接超时 ${connect_timeout}s，总超时 ${max_time}s，curl 退出码 28）" ;;
    *) die "调用 GitHub 失败：$2（curl 退出码 $rc）" ;;
  esac
  code=$(printf '%s' "$out" | tail -n 1)
  API_BODY=$(printf '%s' "$out" | sed '$d')
  case $code in
    2*) return 0 ;;
    401) die "GitHub 拒绝了凭据（401）：调 $2 时。App ID 或私钥不对、本机时钟偏差过大，或者拿 App 的 JWT 调了只认 installation token 的接口" ;;
    404) die "App $app_id 没有装在 $repo 上（404）：到 App 的 Install 页面把它装到这个仓库" ;;
    *) die "GitHub 返回 $code：$(printf '%s' "$API_BODY" | jq -r '.message // empty' 2>/dev/null)" ;;
  esac
}

api GET "/repos/$repo/installation"
if [ "$mode" = installation ]; then printf '%s\n' "$API_BODY"; exit 0; fi
installation=$(printf '%s' "$API_BODY" | jq -r '.id // empty')
slug=$(printf '%s' "$API_BODY" | jq -r '.app_slug // empty')
[ -n "$installation" ] || die "没拿到 installation id"

api POST "/app/installations/$installation/access_tokens"
token=$(printf '%s' "$API_BODY" | jq -r '.token // empty')
[ -n "$token" ] || die "没拿到 installation token"
expires=$(printf '%s' "$API_BODY" | jq -r '.expires_at // empty')

if [ "$mode" = identity ] || [ "$mode" = setup-git ]; then
  [ -n "$slug" ] || die "没拿到 App 的 slug"
  # 这里必须用 installation token：/users/ 不吃 App 的 JWT
  api GET "/users/$slug%5Bbot%5D" "$token"
  uid=$(printf '%s' "$API_BODY" | jq -r '.id // empty')
  [ -n "$uid" ] || die "没拿到 ${slug}[bot] 的 user id"
  name="${slug}[bot]"
  email="${uid}+${slug}[bot]@users.noreply.github.com"
  if [ "$mode" = identity ]; then
    printf '%s\t%s\n' "$name" "$email"
    exit 0
  fi
  # 提交身份要是 App 自己，否则代码会算在人的账号头上，成绩单和"谁写的"就都不对了。
  # 一律写 worktree 级：托管 checkout 是共享 bare 仓库上的 worktree，--local 写进的是
  # 所有任务共用的 config，而且 config.worktree 里 include 的人的身份优先级更高，会盖掉它。
  # 没启用 extensions.worktreeConfig 时 --worktree 等同 --local。
  git -C "$root" config --worktree user.name "$name" || die "配置 user.name 失败"
  git -C "$root" config --worktree user.email "$email" || die "配置 user.email 失败"
  # git push 的凭据现铸现用，不落盘。先用空值清掉从 ~/.gitconfig 继承来的助手，
  # 否则机器上 gh auth login 留下的钥匙串会先应答，agent 就会以人的身份推代码。
  git -C "$root" config --worktree --replace-all credential.helper "" || die "清空凭据助手失败"
  git -C "$root" config --worktree --add credential.helper \
    "!'$root/.autoteam/scripts/gh-app-token.sh' --credential $role" || die "配置凭据助手失败"
  # 回读生效值：别处（如 include 进来的配置）盖掉了就在这里报错，不要等提交完才发现
  [ "$(git -C "$root" config --get user.email)" = "$email" ] ||
    die "提交身份没有生效，当前是 $(git -C "$root" config --get user.email)：检查 git config --show-origin user.email"
  printf '已把这个 clone 配成 %s：提交身份 %s，git push 用 App token\n' "$role" "$name"
  exit 0
fi

# 缓存前先建好目录并收紧权限，token 不能让同机器的其他用户读到
mkdir -p "$cache_dir" && chmod 700 "$cache_dir" 2>/dev/null
umask 077
exp_ts=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$expires" +%s 2>/dev/null) ||
  exp_ts=$(date -d "$expires" +%s 2>/dev/null) || exp_ts=$((now + 3000))
printf '%s\n%s\n' "$exp_ts" "$token" > "$cache" 2>/dev/null

emit "$token"
