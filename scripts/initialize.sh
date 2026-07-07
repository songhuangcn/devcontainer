#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

USER_HOME_DIR="${DEVCONTAINER_USER_HOME_DIR:-${DEVCONTAINER_DIR}/data}"
CONTAINER_HOME="${DEVCONTAINER_CONTAINER_HOME:-/home/ubuntu}"
COMPOSE_FILE="${DEVCONTAINER_COMPOSE_FILE:-docker-compose.yml}"
MARKER_DIR="${USER_HOME_DIR}/.devcontainer"
MARKER_FILE="${MARKER_DIR}/home-image-id"

log() {
  printf '[initialize] %s\n' "$*"
}

dotenv_value() {
  local key="$1"
  local line value
  local env_file="${DEVCONTAINER_DIR}/.env"

  [ -f "${env_file}" ] || return 1

  while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%$'\r'}"
    case "${line}" in
      ''|\#*) continue ;;
      "${key}="*)
        value="${line#*=}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        printf '%s\n' "${value}"
        return 0
        ;;
    esac
  done < "${env_file}"

  return 1
}

resolve_image() {
  local image=''
  local image_name image_tag

  if docker compose version >/dev/null 2>&1; then
    image="$(
      cd "${DEVCONTAINER_DIR}" \
        && docker compose -f "${COMPOSE_FILE}" config --images 2>/dev/null \
        | awk 'NF { print; exit }'
    )" || image=''
  fi

  if [ -n "${image}" ]; then
    printf '%s\n' "${image}"
    return 0
  fi

  image_name="${IMAGE_NAME:-}"
  image_tag="${IMAGE_TAG:-}"

  if [ -z "${image_name}" ]; then
    image_name="$(dotenv_value IMAGE_NAME || true)"
  fi

  if [ -z "${image_tag}" ]; then
    image_tag="$(dotenv_value IMAGE_TAG || true)"
  fi

  printf '%s:%s\n' "${image_name:-songhuangcn/devcontainer}" "${image_tag:-latest}"
}

if ! command -v docker >/dev/null 2>&1; then
  log 'docker command not found; skip image home merge.'
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  log 'docker daemon is unavailable; skip image home merge.'
  exit 0
fi

mkdir -p "${USER_HOME_DIR}" "${MARKER_DIR}"

IMAGE="$(resolve_image)"
log "using image ${IMAGE}"

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  log "image not found locally; pulling ${IMAGE}"
  if ! docker pull "${IMAGE}"; then
    log "failed to pull ${IMAGE}; skip image home merge."
    exit 0
  fi
fi

IMAGE_ID="$(docker image inspect "${IMAGE}" --format '{{.Id}}')"

if [ "${DEVCONTAINER_HOME_SYNC_FORCE:-0}" != '1' ] \
  && [ -f "${MARKER_FILE}" ] \
  && [ "$(tr -d '\r\n' < "${MARKER_FILE}")" = "${IMAGE_ID}" ]; then
  log "home already merged for image ${IMAGE_ID}; skip."
  exit 0
fi

log "merging ${CONTAINER_HOME} from image into ${USER_HOME_DIR} without overwriting local files"
docker run --rm \
  --entrypoint bash \
  -e SOURCE_HOME="${CONTAINER_HOME}" \
  -v "${USER_HOME_DIR}:/target" \
  "${IMAGE}" \
  -lc 'set -euo pipefail; mkdir -p /target; if [ -d "${SOURCE_HOME}" ]; then tar -C "${SOURCE_HOME}" --ignore-failed-read -cf - . | tar -C /target -xf - --skip-old-files; fi'

printf '%s\n' "${IMAGE_ID}" > "${MARKER_FILE}"
log "home merge complete for image ${IMAGE_ID}"
