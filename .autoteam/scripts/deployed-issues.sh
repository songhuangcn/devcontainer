#!/usr/bin/env bash
# Output a JSON array of issue IDs introduced by a deployment, or removed by a rollback.
# `rules` mode prints true/false: whether a deployment touched .autoteam/ or instruction sources.
set -euo pipefail

mode=${1:?usage: deployed-issues.sh deploy|rollback|rules SHA}
sha=${2:?usage: deployed-issues.sh deploy|rollback|rules SHA}
case "$mode" in deploy|rollback|rules) ;; *) echo "invalid mode: $mode" >&2; exit 2 ;; esac
[ -f .autoteam/autoteam.conf ] || { echo 'missing autoteam.conf' >&2; exit 2; }
conf() { sed -n "s/^$1=//p" .autoteam/autoteam.conf | tail -n 1; }
AUTOTEAM_REPO=$(conf AUTOTEAM_REPO)
AUTOTEAM_ISSUE_PREFIX=$(conf AUTOTEAM_ISSUE_PREFIX)
AUTOTEAM_DEPLOY_ENVIRONMENT=$(conf AUTOTEAM_DEPLOY_ENVIRONMENT)
: "${AUTOTEAM_REPO:?missing AUTOTEAM_REPO}"
: "${AUTOTEAM_ISSUE_PREFIX:?missing AUTOTEAM_ISSUE_PREFIX}"
[[ $AUTOTEAM_ISSUE_PREFIX =~ ^[A-Z][A-Z0-9]*$ ]] || { echo 'invalid issue prefix' >&2; exit 2; }

# GitHub's environment deployment statuses identify the last *successful* deployment.
# A push's before SHA can skip merges when the deploy concurrency group cancels runs.
base=''
if [ -n "${AUTOTEAM_DEPLOY_ENVIRONMENT:-}" ]; then
  deployments=$(gh api --paginate "repos/$AUTOTEAM_REPO/deployments?environment=$AUTOTEAM_DEPLOY_ENVIRONMENT&per_page=100" --jq '.[].id')
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    state=$(gh api "repos/$AUTOTEAM_REPO/deployments/$id/statuses?per_page=1" --jq '.[0].state // ""')
    if [ "$state" = success ]; then
      base=$(gh api "repos/$AUTOTEAM_REPO/deployments/$id" --jq '.sha')
      break
    fi
  done <<< "$deployments"
fi

# Repositories without a GitHub environment use the last successful deploy run.
if [ -z "$base" ]; then
  base=$(gh api "repos/$AUTOTEAM_REPO/actions/workflows/deploy.yml/runs?status=success&per_page=1" \
    --jq '.workflow_runs[0].head_sha // ""')
fi

if [ "$mode" = rules ]; then
  # Same boundary as deploy; the first deployment only counts its head commit.
  # The API lists at most 300 files and pagination cannot complete it, so a full list
  # is treated as truncated and conservatively counts as touching the rules.
  list='if (.files | length) >= 300 then ".autoteam/(file list truncated)" else .files[].filename end'
  if [ -z "$base" ]; then
    files=$(gh api "repos/$AUTOTEAM_REPO/commits/$sha" --jq "$list")
  elif [ "$base" = "$sha" ]; then
    files=''
  else
    files=$(gh api "repos/$AUTOTEAM_REPO/compare/$base...$sha?per_page=1" --jq "$list")
  fi
  if printf '%s\n' "$files" | grep -Eq '^(\.autoteam/|skills/autoteam/instructions/)'; then echo true; else echo false; fi
  exit 0
fi

if [ -z "$base" ]; then
  # First deployment has no safe historical boundary. Only its head commit's PR counts.
  [ "$mode" = deploy ] || { echo '[]'; exit 0; }
  commits=$sha
elif [ "$base" = "$sha" ]; then
  echo '[]'
  exit 0
elif [ "$mode" = deploy ]; then
  commits=$(gh api --paginate "repos/$AUTOTEAM_REPO/compare/$base...$sha?per_page=100" --jq '.commits[].sha')
else
  commits=$(gh api --paginate "repos/$AUTOTEAM_REPO/compare/$sha...$base?per_page=100" --jq '.commits[].sha')
fi

ids=''
while IFS= read -r commit; do
  [ -n "$commit" ] || continue
  titles=$(gh api --paginate "repos/$AUTOTEAM_REPO/commits/$commit/pulls?per_page=100" --jq '.[].title')
  while IFS= read -r title; do
    if [[ $title =~ ^($AUTOTEAM_ISSUE_PREFIX-[0-9]+)([[:space:]:-]|$) ]]; then
      ids+="${BASH_REMATCH[1]}"$'\n'
    fi
  done <<< "$titles"
done <<< "$commits"
printf '%s' "$ids" | jq -R -s 'split("\n") | map(select(length > 0)) | unique'
