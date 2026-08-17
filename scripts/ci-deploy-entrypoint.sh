#!/usr/bin/env bash

set -euo pipefail

readonly DEPLOY_SCRIPT="/home/joonha/coco/scripts/deploy-api.sh"
readonly SYNC_SCRIPT="/home/joonha/coco/scripts/sync-ops.sh"
readonly ORIGINAL_COMMAND="${SSH_ORIGINAL_COMMAND:-}"

if [[ "${ORIGINAL_COMMAND}" =~ ^deploy[[:space:]](sha-[0-9a-f]{40})$ ]]; then
    exec "${DEPLOY_SCRIPT}" "${BASH_REMATCH[1]}"
fi

# Installs the operations files the deploy job sends on stdin. The script itself
# enforces which files may be replaced.
if [[ "${ORIGINAL_COMMAND}" == "sync-ops" ]]; then
    exec "${SYNC_SCRIPT}"
fi

echo "Rejected unsupported deployment command." >&2
exit 64
