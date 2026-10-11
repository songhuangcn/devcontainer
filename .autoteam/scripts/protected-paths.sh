#!/usr/bin/env bash
# Print protected paths. Exit 0 if any match, 1 if none match, 2 on error.
# Usage: protected-paths.sh [--pr NUMBER | --files FILE... | --stdin] [--codeowners FILE]
set -o pipefail

die() { printf 'protected-paths: %s\n' "$*" >&2; exit 2; }
root=$(git rev-parse --show-toplevel 2>/dev/null) || die 'not in a git repository'
cd "$root" || die 'cannot enter repository'
tmp=$(mktemp -d) || die 'cannot create temporary directory'
trap 'rm -rf "$tmp"' EXIT
mode='files'
pr=
source_file=
files=()
while [ "$#" -gt 0 ]; do
  case $1 in
    --pr) [ "$#" -ge 2 ] || die '--pr needs a number'; mode='pr'; pr="$2"; shift 2 ;;
    --stdin) mode='stdin'; shift ;;
    --files) shift ;;
    --codeowners) [ "$#" -ge 2 ] || die '--codeowners needs a file'; source_file=$2; shift 2 ;;
    -*) die "unknown option: $1" ;;
    *) files+=("$1"); shift ;;
  esac
done
[ "${#files[@]}" -eq 0 ] || [ "$mode" = files ] || die 'file arguments cannot be combined with --pr or --stdin'
if [ "$mode" = pr ]; then
  [ -n "$pr" ] || die 'missing PR number'
  command -v gh >/dev/null || die 'gh is required for --pr'
  base=$(gh pr view "$pr" --json baseRefName --jq .baseRefName) || die 'cannot read PR base branch'
  gh pr view "$pr" --json files --jq '.files[].path' > "$tmp/files" || die 'cannot read PR files'
  if [ -z "$source_file" ]; then
    gh api "repos/{owner}/{repo}/contents/.github/CODEOWNERS?ref=$base" -H 'Accept: application/vnd.github.raw' > "$tmp/CODEOWNERS" || die 'cannot read base CODEOWNERS'
    source_file=$tmp/CODEOWNERS
  fi
elif [ "$mode" = stdin ]; then
  cat > "$tmp/files" || die 'cannot read stdin'
else
  [ "${#files[@]}" -gt 0 ] || die 'provide files, --stdin, or --pr'
  printf '%s\n' "${files[@]}" > "$tmp/files"
fi
[ -n "$source_file" ] || source_file="$root/.github/CODEOWNERS"
[ -r "$source_file" ] || die "cannot read CODEOWNERS: $source_file"

# GitHub CODEOWNERS uses gitignore-style path patterns, but does not support
# negation, character ranges, or escaped leading #. An ownerless later rule
# clears ownership, so retain it and record whether each rule has an owner.
: > "$tmp/rules"
: > "$tmp/owners"
awk -v rules="$tmp/rules" -v owners="$tmp/owners" '
  NF >= 1 && $1 !~ /^#/ && $1 !~ /^!/ && $1 !~ /[\[\]]/ {
    print $1 > rules
    print (NF >= 2 ? 1 : 0) > owners
  }
' "$source_file" || die 'cannot parse CODEOWNERS'
git -C "$tmp" init -q --template= || die 'cannot initialize matcher'
hit=1
while IFS= read -r path || [ -n "$path" ]; do
  path=${path#./}
  [ -n "$path" ] || continue
  case $path in /*|../*|*/../*|*/..) die "invalid path: $path" ;; esac
  name=${path##*/}
  case $name in *.lock|*.lockb|*-lock.json|*-lock.yaml|*-lock.yml|.lock.json)
    printf '%s\n' "$path"; hit=0; continue ;;
  esac
  # Check each rule separately. Git skips later rules beneath an ignored parent
  # directory; CODEOWNERS still applies its final matching rule there.
  protected=0
  exec 3< "$tmp/rules" 4< "$tmp/owners"
  while IFS= read -r rule <&3 && IFS= read -r owner <&4; do
    printf '%s\n' "$rule" > "$tmp/.gitignore"
    if git -c core.excludesFile=/dev/null -C "$tmp" check-ignore --no-index -q -- "$path"; then
      protected=$owner
    else
      rc=$?
      [ "$rc" -eq 1 ] || die "matcher failed for: $path"
    fi
  done
  exec 3<&- 4<&-
  if [ "$protected" = 1 ]; then
    printf '%s\n' "$path"
    hit=0
  fi
done < "$tmp/files"
exit "$hit"
