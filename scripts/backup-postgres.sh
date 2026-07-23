#!/usr/bin/env bash

set -euo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/compose.production.yaml"
ENV_FILE="${COCO_ENV_FILE:-${ROOT_DIR}/.env.production}"
BACKUP_DIR="${COCO_BACKUP_DIR:-${ROOT_DIR}/backups}"

compose=(docker compose -f "${COMPOSE_FILE}")
if [[ -f "${ENV_FILE}" ]]; then
    compose+=(--env-file "${ENV_FILE}")
elif [[ -z "${COCO_DB_PASSWORD:-}" ]]; then
    echo "Missing ${ENV_FILE}; set COCO_DB_PASSWORD or create the environment file." >&2
    exit 1
fi

mkdir -p "${BACKUP_DIR}"
backup_file="${BACKUP_DIR}/coco-$(date -u +%Y%m%dT%H%M%SZ).dump"

"${compose[@]}" exec -T postgres sh -c \
    'pg_dump --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --format=custom --no-owner --no-privileges' \
    > "${backup_file}"

if [[ ! -s "${backup_file}" ]]; then
    echo "Backup is empty: ${backup_file}" >&2
    exit 1
fi

echo "Backup created: ${backup_file}"

# Keep only the most recent backups so scheduled runs cannot fill the disk.
retain_count="${COCO_BACKUP_RETAIN:-14}"
if [[ "${retain_count}" -gt 0 ]]; then
    while IFS= read -r old_backup; do
        rm -f -- "${old_backup}"
        echo "Pruned old backup: ${old_backup}"
    done < <(ls -1t "${BACKUP_DIR}"/coco-*.dump 2>/dev/null | tail -n +"$((retain_count + 1))")
fi
