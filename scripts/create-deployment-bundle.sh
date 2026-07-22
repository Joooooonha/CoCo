#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${ROOT_DIR}/build/deployment}"
ARCHIVE_PATH="${OUTPUT_DIR}/coco-deployment.tar.gz"
STAGING_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}" "${STAGING_DIR}/coco/scripts" "${STAGING_DIR}/coco/ops/fedora/sshd"

install -m 0644 "${ROOT_DIR}/compose.production.yaml" "${STAGING_DIR}/coco/compose.production.yaml"
install -m 0644 "${ROOT_DIR}/.env.production.example" "${STAGING_DIR}/coco/.env.production.example"
install -m 0755 "${ROOT_DIR}/scripts/backup-postgres.sh" "${STAGING_DIR}/coco/scripts/backup-postgres.sh"
install -m 0755 "${ROOT_DIR}/scripts/restore-postgres.sh" "${STAGING_DIR}/coco/scripts/restore-postgres.sh"
install -m 0644 \
    "${ROOT_DIR}/ops/fedora/sshd/00-coco-hardening.conf" \
    "${STAGING_DIR}/coco/ops/fedora/sshd/00-coco-hardening.conf"

tar -C "${STAGING_DIR}" -czf "${ARCHIVE_PATH}" coco

echo "Deployment bundle created: ${ARCHIVE_PATH}"
