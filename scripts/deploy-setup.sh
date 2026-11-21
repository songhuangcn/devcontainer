#!/usr/bin/env bash
set -euo pipefail

# Keep the setup Pod until the rollout ends so concurrent deploys cannot replace it.
manifest="$(mktemp)"
trap 'rm -f -- "${manifest}"' EXIT
cat > "${manifest}"

k() { kubectl -n devcontainer "$@"; }

if [[ -z "$(k get namespace devcontainer --ignore-not-found -o name)" ]]; then
  kubectl create namespace devcontainer
fi
k apply -f "${manifest}" -l devcontainer.hdgcs.com/deploy-phase=setup-input
# Use create, not apply: another setup may be using the workspace already.
k create -f "${manifest}" -l devcontainer.hdgcs.com/deploy-phase=setup
trap 'k delete pod runtime-setup --ignore-not-found --wait=false || true; rm -f -- "${manifest}"' EXIT

for ((attempt = 0; attempt < 72; attempt++)); do
  phase="$(k get pod runtime-setup -o jsonpath='{.status.phase}')"
  case "${phase}" in
    Succeeded)
      k logs runtime-setup -c sync-runtime
      if [[ "${1:-}" == --apply ]]; then
        k apply -f "${manifest}" -l 'devcontainer.hdgcs.com/deploy-phase notin (namespace,setup,setup-input)'
        k delete service app-ssh --ignore-not-found
        k rollout status deployment/app --timeout=20m
      fi
      exit 0 ;;
    Failed) break ;;
  esac
  sleep 5
done
k logs runtime-setup --all-containers=true --prefix || true
k describe pod runtime-setup || true
printf 'Runtime setup failed; application Deployment was not updated.\n' >&2
exit 1
