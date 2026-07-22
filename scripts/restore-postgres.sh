#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 || "$2" != "--confirm" ]]; then
    echo "Usage: $0 <backup.dump> --confirm" >&2
    exit 1
fi

BACKUP_FILE="$1"
if [[ ! -s "${BACKUP_FILE}" ]]; then
    echo "Backup file is missing or empty: ${BACKUP_FILE}" >&2
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/compose.production.yaml"
ENV_FILE="${COCO_ENV_FILE:-${ROOT_DIR}/.env.production}"

compose=(docker compose -f "${COMPOSE_FILE}")
if [[ -f "${ENV_FILE}" ]]; then
    compose+=(--env-file "${ENV_FILE}")
elif [[ -z "${COCO_DB_PASSWORD:-}" ]]; then
    echo "Missing ${ENV_FILE}; set COCO_DB_PASSWORD or create the environment file." >&2
    exit 1
fi

restart_api() {
    "${compose[@]}" start api >/dev/null 2>&1 || true
}

"${compose[@]}" stop api
trap restart_api EXIT

"${compose[@]}" exec -T postgres sh -c \
    'pg_restore --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --clean --if-exists --exit-on-error --no-owner --no-privileges' \
    < "${BACKUP_FILE}"

"${compose[@]}" up -d --wait api
trap - EXIT

echo "Restore completed from: ${BACKUP_FILE}"
