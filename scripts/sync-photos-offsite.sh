#!/usr/bin/env bash

# R2의 요소 사진을 오프사이트 S3 버킷으로 단방향 동기화한다.
#
# DB 덤프에는 사진의 객체 키만 있고 이미지 바이트는 없다. R2 자체에 유실이
# 생기면 DB를 복원해도 사진은 돌아오지 않으므로 사진은 따로 백업한다.
#
# 대량 삭제를 막는 임계값은 두지 않는다. 임계값에 걸리면 그날 백업이 통째로
# 실패하는데 아무도 매일 로그를 보지 않기 때문에, 재앙을 막으려던 장치가
# 조용히 백업을 멈춰 세우는 쪽이 더 위험하다. 대신 매 실행의 추가·삭제 건수를
# 남기고, 잘못된 삭제는 S3 버전 관리로 되돌린다.

set -euo pipefail
umask 077

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${COCO_ENV_FILE:-${ROOT_DIR}/.env.production}"
LOG_DIR="${COCO_LOG_DIR:-${ROOT_DIR}/logs}"
SUMMARY_LOG="${LOG_DIR}/photo-sync.log"
SUMMARY_RETAIN_LINES="${COCO_PHOTO_SYNC_LOG_LINES:-365}"

if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "${ENV_FILE}"
    set +a
fi

if ! command -v rclone > /dev/null 2>&1; then
    echo "rclone is not installed; see DEPLOYMENT.md 사진 오프사이트 백업." >&2
    exit 1
fi

missing=()
for name in COCO_STORAGE_ENDPOINT COCO_STORAGE_BUCKET COCO_STORAGE_ACCESS_KEY_ID COCO_STORAGE_SECRET_ACCESS_KEY; do
    [[ -n "${!name:-}" ]] || missing+=("${name}")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "R2 is not configured (${missing[*]}); nothing to back up." >&2
    exit 1
fi

# 오프사이트 쪽이 아직 준비되지 않은 상태는 실패가 아니다. 콘솔 작업 전까지
# 타이머가 매일 실패로 기록되면 진짜 실패가 묻힌다.
offsite_missing=()
for name in COCO_OFFSITE_BUCKET COCO_OFFSITE_ACCESS_KEY_ID COCO_OFFSITE_SECRET_ACCESS_KEY; do
    [[ -n "${!name:-}" ]] || offsite_missing+=("${name}")
done
if [[ ${#offsite_missing[@]} -gt 0 ]]; then
    echo "SKIPPED: offsite storage is not configured yet (${offsite_missing[*]})."
    exit 0
fi

# 자격 증명을 rclone 설정 파일에 복사해 두지 않는다. 시크릿이 저장되는 곳은
# .env.production 하나로 유지한다.
export RCLONE_CONFIG_R2_TYPE=s3
export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
export RCLONE_CONFIG_R2_REGION="${COCO_STORAGE_REGION:-auto}"
export RCLONE_CONFIG_R2_ENDPOINT="${COCO_STORAGE_ENDPOINT}"
export RCLONE_CONFIG_R2_ACCESS_KEY_ID="${COCO_STORAGE_ACCESS_KEY_ID}"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="${COCO_STORAGE_SECRET_ACCESS_KEY}"

export RCLONE_CONFIG_OFFSITE_TYPE=s3
export RCLONE_CONFIG_OFFSITE_PROVIDER=AWS
export RCLONE_CONFIG_OFFSITE_REGION="${COCO_OFFSITE_REGION:-ap-northeast-2}"
export RCLONE_CONFIG_OFFSITE_ACCESS_KEY_ID="${COCO_OFFSITE_ACCESS_KEY_ID}"
export RCLONE_CONFIG_OFFSITE_SECRET_ACCESS_KEY="${COCO_OFFSITE_SECRET_ACCESS_KEY}"

mkdir -p "${LOG_DIR}"
run_log="$(mktemp)"
trap 'rm -f "${run_log}"' EXIT

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
status=0
# 사진은 5 MiB 이하 단일 파트 업로드라 ETag가 곧 MD5다. 그래서 제공자가 서로
# 달라도 체크섬 비교가 성립하고, 수정 시각 차이로 매번 다시 올리는 일이 없다.
rclone sync \
    "r2:${COCO_STORAGE_BUCKET}" \
    "offsite:${COCO_OFFSITE_BUCKET}" \
    --checksum \
    --transfers 4 \
    --checkers 8 \
    --verbose \
    --stats 0 \
    > "${run_log}" 2>&1 || status=$?

copied="$(grep -c ': Copied' "${run_log}" || true)"
deleted="$(grep -c ': Deleted' "${run_log}" || true)"

if [[ "${status}" -eq 0 ]]; then
    summary="${started_at} ok copied=${copied} deleted=${deleted}"
else
    summary="${started_at} FAILED exit=${status} copied=${copied} deleted=${deleted}"
fi

echo "${summary}"
echo "${summary}" >> "${SUMMARY_LOG}"

# 실패했을 때만 rclone의 전체 출력을 남긴다. 성공한 날의 파일 목록까지 쌓으면
# 정작 봐야 할 실패가 묻힌다.
if [[ "${status}" -ne 0 ]]; then
    cat "${run_log}" >&2
fi

if [[ "${SUMMARY_RETAIN_LINES}" -gt 0 ]]; then
    tail -n "${SUMMARY_RETAIN_LINES}" "${SUMMARY_LOG}" > "${SUMMARY_LOG}.tmp"
    mv "${SUMMARY_LOG}.tmp" "${SUMMARY_LOG}"
fi

exit "${status}"
