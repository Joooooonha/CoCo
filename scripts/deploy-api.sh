#!/usr/bin/env bash

set -euo pipefail
umask 077

if [[ $# -ne 1 || ! "$1" =~ ^sha-[0-9a-f]{40}$ ]]; then
    echo "Usage: $0 sha-<40-character-git-commit>" >&2
    exit 64
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.production"
COMPOSE_FILE="${ROOT_DIR}/compose.production.yaml"
IMAGE_REPOSITORY="ghcr.io/joooooonha/coco-api"
TARGET_TAG="$1"
TARGET_IMAGE="${IMAGE_REPOSITORY}:${TARGET_TAG}"
EXPECTED_REVISION="${TARGET_TAG#sha-}"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing production environment file: ${ENV_FILE}" >&2
    exit 1
fi

exec 9>"${ROOT_DIR}/.deploy.lock"
if ! flock -n 9; then
    echo "Another CoCo deployment is already running." >&2
    exit 75
fi

compose=(docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}")

read_image_setting() {
    local configured
    configured="$(sed -n 's/^COCO_API_IMAGE=//p' "${ENV_FILE}" | tail -n 1)"
    printf '%s\n' "${configured:-${IMAGE_REPOSITORY}:latest}"
}

write_image_setting() {
    local image="$1"
    local temp_file
    local found=false

    temp_file="$(mktemp "${ENV_FILE}.XXXXXX")"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == COCO_API_IMAGE=* ]]; then
            printf 'COCO_API_IMAGE=%s\n' "${image}" >> "${temp_file}"
            found=true
        else
            printf '%s\n' "${line}" >> "${temp_file}"
        fi
    done < "${ENV_FILE}"

    if [[ "${found}" == false ]]; then
        printf 'COCO_API_IMAGE=%s\n' "${image}" >> "${temp_file}"
    fi

    chmod 600 "${temp_file}"
    mv "${temp_file}" "${ENV_FILE}"
}

previous_image="$(read_image_setting)"
previous_digest="$(docker image inspect \
    --format '{{index .RepoDigests 0}}' "${previous_image}" 2>/dev/null || true)"
rollback_image="${previous_digest:-${previous_image}}"

echo "Deploying ${TARGET_IMAGE}"
write_image_setting "${TARGET_IMAGE}"

deployment_succeeded=false
if "${compose[@]}" pull api; then
    actual_revision="$(docker image inspect \
        --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' \
        "${TARGET_IMAGE}" 2>/dev/null || true)"

    if [[ "${actual_revision}" != "${EXPECTED_REVISION}" ]]; then
        echo "Image revision mismatch: expected ${EXPECTED_REVISION}, got ${actual_revision:-missing}" >&2
    elif "${compose[@]}" up -d --wait api \
        && curl --fail --silent --show-error \
            http://127.0.0.1:19090/actuator/health >/dev/null; then
        deployment_succeeded=true
    fi
fi

if [[ "${deployment_succeeded}" == true ]]; then
    echo "Deployment healthy: ${TARGET_IMAGE}"
    exit 0
fi

echo "Deployment failed; rolling back to ${rollback_image}" >&2
write_image_setting "${rollback_image}"
"${compose[@]}" pull api || true
"${compose[@]}" up -d --wait api || true

if curl --fail --silent --show-error \
    http://127.0.0.1:19090/actuator/health >/dev/null; then
    echo "Rollback healthy: ${rollback_image}" >&2
else
    echo "Rollback did not restore a healthy API." >&2
fi

exit 1
