#!/usr/bin/env bash

# Installs operations files sent by CI over the restricted deployment SSH key.
# The tar stream arrives on stdin; only files named in ALLOWED_FILES below are
# installed, so the Mac mini decides what may be overwritten rather than the
# pushed content. Host scripts, systemd units and secrets are deliberately not
# in the list and stay manual.

set -euo pipefail
umask 077

readonly ROOT_DIR="/home/joonha/coco"
readonly ENV_FILE="${ROOT_DIR}/.env.production"
readonly ALLOWED_FILES=(compose.production.yaml)

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

# GNU tar refuses absolute paths and ".." members unless -P is given.
if ! tar xzf - -C "${staging}" --no-same-owner --no-same-permissions; then
    echo "Could not read the operations bundle." >&2
    exit 65
fi

for name in "${ALLOWED_FILES[@]}"; do
    if [[ ! -f "${staging}/${name}" ]]; then
        echo "Bundle is missing ${name}." >&2
        exit 65
    fi
done

# Reject a compose file that the current secrets cannot even resolve, so a
# broken configuration never replaces a working one.
if ! docker compose --env-file "${ENV_FILE}" \
        -f "${staging}/compose.production.yaml" config --quiet; then
    echo "Rejected: the new compose file is not valid with the current environment." >&2
    exit 65
fi

changed=false
for name in "${ALLOWED_FILES[@]}"; do
    target="${ROOT_DIR}/${name}"
    if [[ -f "${target}" ]] && cmp -s "${staging}/${name}" "${target}"; then
        continue
    fi
    if [[ -f "${target}" ]]; then
        cp -p "${target}" "${target}.previous"
    fi
    install -m 600 "${staging}/${name}" "${target}"
    echo "Updated ${name}"
    changed=true
done

if [[ "${changed}" == false ]]; then
    echo "Operations files already up to date."
fi
