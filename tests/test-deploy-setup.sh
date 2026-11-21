#!/usr/bin/env bash
set -euo pipefail

root="$(mktemp -d)"
trap 'rm -rf -- "${root}"' EXIT
export PATH="${root}:${PATH}" CALLS="${root}/calls"
script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/deploy-setup.sh"
cat > "${root}/kubectl" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "${CALLS}"
case "$*" in
  *'get namespace'*) echo namespace/devcontainer ;;
  *'get pod'*) echo "${PHASE}" ;;
esac
EOF
chmod +x "${root}/kubectl"

if PHASE=Failed bash "${script}" --apply <<< 'manifest'; then
  printf 'Expected setup failure to stop deployment\n' >&2
  exit 1
fi
test -z "$(grep 'notin\|rollout status' "${CALLS}" || true)"
grep -q 'delete pod runtime-setup' "${CALLS}"

: > "${CALLS}"
PHASE=Succeeded bash "${script}" <<< 'manifest'
test -z "$(grep 'notin\|rollout status' "${CALLS}" || true)"

: > "${CALLS}"
PHASE=Succeeded bash "${script}" --apply <<< 'manifest'
test "$(sed -nE '/create .*deploy-phase=setup|notin|rollout status|delete pod runtime-setup/p' "${CALLS}" | sed -E 's/^-n devcontainer ([^ ]+).*/\1/')" = "$(printf 'create\napply\nrollout\ndelete')"
printf 'Deployment setup tests passed.\n'
