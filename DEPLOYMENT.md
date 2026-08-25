# CoCo Mac mini 홈서버 배포

CoCo의 일반 사용자 API는 Cloudflare Tunnel로 공개하고, Mac mini 관리와 CI/CD는 Tailscale 사설망으로 분리한다.

```text
GitHub main -> GitHub Actions test -> GHCR ARM64 image
                                      |
                                      v
iPhone -> Cloudflare HTTPS -> Cloudflare Tunnel -> cloudflared -> Spring:8080 -> PostgreSQL
MacBook -> Tailscale -> Mac mini SSH -> GHCR image pull
Mac mini localhost:19090 -> Spring Actuator
MacBook -> Tailscale -> Mac mini Cockpit:9090
```

PostgreSQL과 Spring API 포트는 호스트 공용 네트워크에 노출하지 않는다. Actuator 컨테이너 포트 `9090`은 호스트의 `127.0.0.1:19090`에만 연결한다. Fedora Cockpit의 `9090`은 Tailscale 관리 존에서만 접근한다.

## 1. 준비물

- Apple Silicon Mac mini
- Fedora Asahi Remix Server와 Docker Engine/Compose
- Cloudflare에서 DNS를 관리하는 도메인
- Cloudflare Tunnel 생성 권한
- Mac mini와 개발 MacBook에 설치된 Tailscale
- Mac mini의 OpenSSH 서버와 공개키 인증

현재 운영 기준은 Fedora Asahi Remix 44, Linux ARM64, Docker Engine 29 이상이다. Docker와 Tailscale 데몬은 systemd에서 부팅 시 자동 시작한다. 가능하면 유선 네트워크를 사용한다.

참고:

- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/
- https://developers.cloudflare.com/tunnel/setup/
- https://tailscale.com/docs/install/linux
- https://docs.docker.com/engine/install/

## 2. Fedora 호스트 보호

Mac mini의 Tailscale 이름은 `coco-mac-mini`로 고정한다. `tailscale0`은 `coco-management` firewalld 존에 배치하고 SSH와 Cockpit만 허용한다. Wi-Fi의 `FedoraServer` 존에서는 두 서비스를 제거한다.

```bash
sudo firewall-cmd --permanent --new-zone=coco-management
sudo firewall-cmd --reload
sudo firewall-cmd --permanent --zone=coco-management --add-interface=tailscale0
sudo firewall-cmd --permanent --zone=coco-management --add-service=ssh
sudo firewall-cmd --permanent --zone=coco-management --add-service=cockpit
sudo firewall-cmd --permanent --zone=FedoraServer --remove-service=ssh
sudo firewall-cmd --permanent --zone=FedoraServer --remove-service=cockpit
sudo firewall-cmd --reload
```

SSH는 저장소의 드롭인을 설치한 뒤 문법 검사를 통과한 경우에만 다시 불러온다.

```bash
sudo install -o root -g root -m 0644 \
  ops/fedora/sshd/00-coco-hardening.conf \
  /etc/ssh/sshd_config.d/00-coco-hardening.conf
sudo sshd -t
sudo systemctl reload sshd
```

이 설정은 `joonha`의 공개키 로그인만 허용하고 root, 비밀번호, 키보드 대화식 로그인, X11, 에이전트 전달과 원격 TCP 포워딩을 차단한다. 로컬 TCP 포워딩은 localhost 관리 작업을 위해 유지한다.

기본 설치의 `passim` 로컬 캐시를 사용하지 않으면 불필요한 `27500` 리스너를 중지한다.

```bash
sudo systemctl mask --now passim.service
```

## 3. Cloudflare Tunnel 생성

1. Cloudflare Dashboard의 **Networking > Tunnels**에서 `coco-production` 터널을 만든다.
2. Docker 환경을 선택하고 표시되는 터널 토큰을 별도로 보관한다.
3. 공개 호스트 이름을 `api.cocorun.site`로 만든다.
4. 서비스 주소를 `http://api:8080`으로 지정한다.
5. 일반 iOS 사용자가 접근해야 하므로 이 API 호스트에 Cloudflare Access 로그인을 요구하지 않는다.

터널 토큰을 가진 사람은 터널 커넥터를 실행할 수 있으므로 Git에 커밋하거나 로그에 출력하지 않는다.

## 4. Mac mini 환경 설정

Mac mini는 전체 소스를 clone하거나 Gradle 빌드를 수행하지 않는다. MacBook에서 운영에 필요한 파일만 번들로 만들어 전송한다.

MacBook:

```bash
./scripts/create-deployment-bundle.sh
scp build/deployment/coco-deployment.tar.gz joonha@coco-mac-mini:~/
```

Mac mini:

```bash
tar -xzf ~/coco-deployment.tar.gz -C ~
cd ~/coco
cp .env.production.example .env.production
openssl rand -base64 32
```

`.env.production`에서 다음 값을 실제 값으로 바꾼다.

```dotenv
COCO_DB_PASSWORD=<생성한 긴 비밀번호>
CLOUDFLARE_TUNNEL_TOKEN=<Cloudflare 터널 토큰>
COCO_PUBLIC_API_BASE_URL=https://api.cocorun.site
COCO_API_IMAGE=ghcr.io/joooooonha/coco-api:latest
COCO_MANAGEMENT_PORT=19090
```

나머지 값은 1차 홈서버 보호 기본값이다. Mac mini 사양과 부하 측정 없이 상한을 높이지 않는다.

### 요소 사진 저장소 (Cloudflare R2)

사진 바이트는 서버를 통과하지 않고 앱이 사전 서명 URL로 R2에 직접 올린다. 서버에는 R2 자격 증명만 필요하다.

Cloudflare 대시보드에서:

1. R2를 활성화한다. 무료 등급에도 결제 수단 등록이 필요하다.
2. 버킷 `coco-element-photos`를 만든다. 위치는 APAC, 공개 접근은 끄고 둔다.
3. R2 API 토큰을 발급한다. 권한은 해당 버킷에 대한 Object Read & Write까지만 준다.
4. 발급 화면에 한 번만 보이는 Access Key ID와 Secret Access Key, 그리고 계정 ID를 받아 둔다.

`.env.production`에 다음을 채운다. 값을 비워 두면 서버는 정상 기동하고 사진 API만 `503 PHOTO_STORAGE_UNAVAILABLE`을 반환한다.

```dotenv
COCO_STORAGE_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
COCO_STORAGE_REGION=auto
COCO_STORAGE_BUCKET=coco-element-photos
COCO_STORAGE_ACCESS_KEY_ID=<R2 액세스 키 ID>
COCO_STORAGE_SECRET_ACCESS_KEY=<R2 시크릿 액세스 키>
```

R2에는 결제 한도를 강제하는 기능이 없다. 대시보드의 Notifications에서 사용량 알림을 걸어 두는 것으로 대신한다.

## 5. 시작과 확인

```bash
docker compose --env-file .env.production -f compose.production.yaml config
docker compose --env-file .env.production -f compose.production.yaml pull
docker compose --env-file .env.production -f compose.production.yaml up -d --wait
docker compose --env-file .env.production -f compose.production.yaml ps
curl --fail --silent --show-error http://127.0.0.1:19090/actuator/health
curl --fail --silent --show-error https://api.cocorun.site/api/v1/auth/guest -X POST
```

기대 상태:

- `postgres`, `api`, `cloudflared`가 실행 중이다.
- `api`는 Mac mini에서 빌드하지 않고 GHCR ARM64 이미지를 사용한다.
- `postgres`는 호스트 포트가 없다.
- `api`는 `127.0.0.1:19090` 관리 포트만 가진다.
- 로컬 Actuator 응답 상태가 `UP`이다.
- 공개 HTTPS 게스트 인증이 성공한다.
- `https://api.cocorun.site/actuator/health`는 접근되지 않는다.

## 6. Cloudflare 보호 설정

현재 Free 플랜 운영 기준은 다음과 같다.

1. **Always Use HTTPS**를 켜서 모든 HTTP 요청을 HTTPS로 리디렉션한다.
2. HTTP DDoS Managed Rules와 Free Managed Ruleset의 기본 보호를 유지한다.
3. `Block non-API paths` 사용자 지정 규칙으로 `api.cocorun.site`에서 `/api/`로 시작하지 않는 경로를 차단한다.
4. `Limit guest creation` 속도 제한 규칙으로 `/api/v1/auth/guest`를 IP당 10초에 5회로 제한하고 초과 시 10초간 차단한다.
5. 일반 iOS 사용자가 접근해야 하므로 API 호스트에는 Cloudflare Access 로그인을 요구하지 않는다.

사용자 지정 규칙 표현식:

```text
http.host eq "api.cocorun.site" and not starts_with(http.request.uri.path, "/api/")
```

Free 플랜은 속도 제한 규칙 1개와 10초 집계/차단 기간만 지원한다. 이후 코스 등록, 반응, 소셜 로그인 같은 쓰기 API가 추가되면 애플리케이션 내부 제한을 우선 추가하고 Cloudflare 플랜 변경 여부를 트래픽 근거로 결정한다.

HSTS는 초기 운영 안정화와 복구 절차 검증 전까지 켜지 않는다. 브라우저에 장기간 캐시되는 정책이므로 HTTPS 구성을 되돌릴 가능성이 없어진 뒤 별도 적용한다.

Cloudflare Rate Limit은 짧은 집계 지연이 있을 수 있으므로 Spring의 인증, 요청 크기와 자원 상한을 제거하지 않는다.

참고:

- https://developers.cloudflare.com/ddos-protection/managed-rulesets/http/
- https://developers.cloudflare.com/waf/
- https://developers.cloudflare.com/waf/rate-limiting-rules/

## 7. Tailscale 관리 경로

Tailscale Serve는 일반 앱 요청에 사용하지 않는다. MacBook과 Mac mini를 같은 tailnet에 연결하고, Fedora OpenSSH를 Tailscale 관리 존에서만 허용한다.

```bash
tailscale status
ssh <mac-mini-user>@<mac-mini-tailscale-hostname>
```

공유기의 `22`, `8080`, `9090`, `19090`, `5432` 포트를 포워딩하지 않는다. 후속 GitHub Actions 배포도 임시 Tailscale 노드에서 이 SSH 경로를 사용한다.

## 8. iOS 서버 주소

Xcode Target의 Release 빌드 설정 `COCO_API_BASE_URL`을 다음 값으로 변경한다.

```text
https://api.cocorun.site
```

Debug의 `http://localhost:8080`은 MacBook 로컬 개발용으로 유지한다.

## 9. 업데이트와 자동 배포

`main`에 서버 변경이 push되면 `.github/workflows/server-ci.yml`이 테스트 후 다음 이미지를 발행한다.

- `ghcr.io/joooooonha/coco-api:latest`
- `ghcr.io/joooooonha/coco-api:sha-<전체-커밋-SHA>`

`COCO_CD_ENABLED=true`인 경우 publish job 성공 후 deploy job이 이어서 실행된다.

### 무엇이 자동으로 배포되고 무엇이 수동인가

| 대상 | 전달 방식 | 자동 여부 |
|---|---|---|
| 애플리케이션 코드(JAR) | GHCR 이미지 | 자동 |
| `compose.production.yaml` | 배포 job의 `sync-ops` 단계 | 자동 |
| `.env.production` (비밀값) | Mac mini에서 직접 편집 | 수동. Git에 두지 않는다 |
| `scripts/*.sh`, systemd 유닛, sshd 드롭인 | `scp` 또는 배포 번들 | 수동 |

호스트에서 실행되는 스크립트와 systemd 유닛은 배포 경로의 보안 경계 자체이므로 의도적으로 자동 동기화 대상에서 제외한다. 이 파일들을 바꾸면 Mac mini에 직접 전송하고 `chmod +x`를 확인한다.

`sync-ops`는 `scripts/sync-ops.sh`의 허용 목록에 있는 파일만 교체한다. 무엇을 덮어쓸 수 있는지는 푸시된 내용이 아니라 Mac mini가 결정한다. 새 compose 파일은 현재 `.env.production`으로 `docker compose config` 검증을 통과해야 하며, 실패하면 기존 파일을 유지한다. 교체 시 직전 파일은 `compose.production.yaml.previous`로 남는다.

1. GitHub Actions가 Tailscale Workload Identity로 `tag:ci` 임시 노드를 만든다.
2. `tag:ci`는 Tailscale 정책에서 `coco-mac-mini:22`만 접근할 수 있다.
3. GitHub 전용 SSH 키는 Mac mini의 `authorized_keys`에서 강제 명령으로 제한된다.
4. workflow는 `sync-ops`와 `deploy sha-<커밋>` 두 명령만 전달할 수 있다.
5. `deploy-api.sh`는 immutable 이미지를 pull하고 이미지 revision 라벨을 커밋 SHA와 대조한다.
6. API가 healthy가 아니면 이전 로컬 이미지 digest로 자동 롤백한다.

Tailscale Admin Console의 **Trust credentials**에서 GitHub Actions OpenID Connect 자격 증명을 만든다.

- Subject: `repo:Joooooonha@165540848/CoCo@1308896306:ref:refs/heads/main`
- Scope: `auth_keys`
- Tag: `tag:ci`

이 tailnet의 GitHub issuer는 저장소 이름뿐 아니라 owner와 repository의 numeric ID도 Subject에 포함한다. Tailscale 상세 화면의 `Received ... from issuer` 값을 기준으로 맞춘다.

발급된 값은 다음 GitHub repository secrets에 저장한다. Client ID와 Audience는 장기 비밀이 아니지만 workflow 설정을 한곳에서 관리하기 위해 secrets로 둔다.

- `TS_OAUTH_CLIENT_ID`
- `TS_AUDIENCE`
- `COCO_DEPLOY_SSH_KEY`
- `COCO_DEPLOY_KNOWN_HOSTS`

repository variable `COCO_CD_ENABLED`는 현재 `true`다. GitHub Actions가 만드는 Tailscale 노드는 workflow 종료 후 제거되는 ephemeral 노드다. Tailscale 정책은 사용자 계정의 기존 접근을 유지하면서 `tag:ci`에서 `host:coco-mac-mini`의 `tcp:22`로 향하는 연결만 추가 허용한다.

수동 배포와 장애 대응은 다음 명령을 사용한다.

```bash
./scripts/deploy-api.sh sha-<전체-커밋-SHA>
```

필요하면 정상 동작했던 SHA 태그로 같은 스크립트를 다시 실행한다. 자동 배포 스크립트 자체가 실패한 경우 `.env.production`의 `COCO_API_IMAGE`를 정상 이미지 digest나 SHA 태그로 바꾸고 Compose의 pull/up 명령을 실행한다.

## 10. 백업과 복구

코스 등록 기능이 열려 실제 사용자 데이터가 저장되므로 정기 백업을 운영 기본값으로 활성화한다.

### 정기 백업

`ops/fedora/systemd/`의 systemd 유닛이 매일 04:30 KST(10분 지연 허용, 놓친 실행은 부팅 후 보충)에 `backup-postgres.sh`를 실행한다. 스크립트는 성공한 백업 이후 `COCO_BACKUP_RETAIN`(기본 14) 개수를 넘는 오래된 덤프를 삭제한다.

Mac mini에 배포 번들을 풀어 둔 상태에서 한 번만 설치한다.

```bash
sudo install -o root -g root -m 0644 \
  ~/coco/ops/fedora/systemd/coco-backup.service \
  ~/coco/ops/fedora/systemd/coco-backup.timer \
  /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now coco-backup.timer
```

상태와 이력 확인:

```bash
systemctl list-timers coco-backup.timer --no-pager
journalctl -u coco-backup.service --no-pager | tail -20
ls -la ~/coco/backups/
```

### 수동 백업과 복구

```bash
./scripts/backup-postgres.sh
./scripts/restore-postgres.sh backups/coco-YYYYMMDDTHHMMSSZ.dump --confirm
```

백업은 `backups/`에 생성되며 Git에서 제외된다. 복구 스크립트는 API를 중지하고 DB를 교체한 뒤 API가 다시 healthy가 될 때까지 기다린다.

### 사진 오프사이트 백업 (R2 → S3)

PostgreSQL 덤프에는 사진의 객체 키만 있고 이미지 바이트는 없다. R2에 유실이 생기면 DB를 복원해도 사진은 돌아오지 않으므로 사진은 별도로 백업한다.

`coco-photo-sync.timer`가 매일 04:45 KST에 `sync-photos-offsite.sh`를 실행한다. R2 버킷을 S3 버킷으로 단방향 `rclone sync` 한다. S3 쪽 값이 비어 있으면 아무 일도 하지 않고 건너뛴다.

#### AWS 콘솔에서

1. S3 버킷을 만든다. 리전은 `ap-northeast-2`(서울), 퍼블릭 액세스는 전부 차단한 채로 둔다.
2. 버킷 속성에서 **버전 관리를 켠다.** 아래 삭제 정책이 여기에 의존한다.
3. 수명 주기 규칙을 추가한다. **비현행 버전을 30일 뒤 영구 삭제**한다. DB 백업 보존이 14일이므로 사진 쪽이 먼저 사라지지 않도록 더 길게 잡았다.
4. IAM 사용자를 만들고 이 버킷에만 적용되는 정책을 붙인다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:ListBucketVersions"
      ],
      "Resource": "arn:aws:s3:::<버킷 이름>"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::<버킷 이름>/*"
    }
  ]
}

동기화만 놓고 보면 `ListBucket`, `PutObject`, `GetObject`, `DeleteObject` 넷이면 된다. 나머지 셋은 읽기 전용이며 복구와 점검에 쓴다. `GetBucketVersioning`으로 안전망이 실제로 켜져 있는지 확인하고, `ListBucketVersions`와 `GetObjectVersion`으로 지워진 사진의 이전 버전을 찾아 되돌린다. 이 권한이 없으면 복구가 콘솔 수작업으로만 가능하다.

`DeleteObjectVersion`은 넣지 않는다. 이 자격 증명이 유출돼도 이전 버전은 지울 수 없어야 안전망이 의미를 갖는다. 비현행 버전 정리는 수명 주기 규칙이 대신한다.
```

5. 액세스 키를 발급한다. 시크릿은 발급 화면에서만 보인다.
6. Billing → Budgets에서 월 $1 정도의 예산 알림을 걸어 둔다. R2와 달리 AWS는 예산 알림을 제공한다.

#### Mac mini에서

```bash
sudo dnf install -y rclone
```

`.env.production`에 다음을 채운다.

```dotenv
COCO_OFFSITE_BUCKET=<S3 버킷 이름>
COCO_OFFSITE_REGION=ap-northeast-2
COCO_OFFSITE_ACCESS_KEY_ID=<IAM 액세스 키 ID>
COCO_OFFSITE_SECRET_ACCESS_KEY=<IAM 시크릿 액세스 키>
```

스크립트와 유닛 파일을 새로 배포한다. MacBook에서:

```bash
./scripts/create-deployment-bundle.sh
scp build/deployment/coco-deployment.tar.gz joonha@coco-mac-mini:~/
```

Mac mini에서:

```bash
tar -xzf ~/coco-deployment.tar.gz -C ~
sudo install -o root -g root -m 0644 \
  ~/coco/ops/fedora/systemd/coco-photo-sync.service \
  ~/coco/ops/fedora/systemd/coco-photo-sync.timer \
  /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now coco-photo-sync.timer
```

#### 확인

```bash
~/coco/scripts/sync-photos-offsite.sh
systemctl list-timers coco-photo-sync.timer --no-pager
cat ~/coco/logs/photo-sync.log
```

로그는 실행마다 한 줄씩 쌓인다.

```
2026-08-19T19:45:03Z ok copied=3 deleted=0
```

대량 삭제를 막는 임계값은 두지 않았다. 임계값에 걸리면 그날 백업이 통째로 실패하는데, 매일 로그를 확인하는 사람이 없으면 재앙을 막으려던 장치가 조용히 백업을 멈춰 세운다. 대신 건수를 남기고 잘못된 삭제는 버전 관리로 되돌린다. 근거는 `DECISIONS.md` D29.

#### 사진 복구

S3 사본은 평소에 읽지 않는다. R2에 유실이 생겼을 때만 되돌린다.

```bash
cd ~/coco
set -a && . ./.env.production && set +a
export RCLONE_CONFIG_R2_TYPE=s3 RCLONE_CONFIG_R2_PROVIDER=Cloudflare
export RCLONE_CONFIG_R2_REGION="$COCO_STORAGE_REGION" RCLONE_CONFIG_R2_ENDPOINT="$COCO_STORAGE_ENDPOINT"
export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$COCO_STORAGE_ACCESS_KEY_ID"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$COCO_STORAGE_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_OFFSITE_TYPE=s3 RCLONE_CONFIG_OFFSITE_PROVIDER=AWS
export RCLONE_CONFIG_OFFSITE_REGION="$COCO_OFFSITE_REGION"
export RCLONE_CONFIG_OFFSITE_ACCESS_KEY_ID="$COCO_OFFSITE_ACCESS_KEY_ID"
export RCLONE_CONFIG_OFFSITE_SECRET_ACCESS_KEY="$COCO_OFFSITE_SECRET_ACCESS_KEY"

# 먼저 무엇이 돌아오는지만 본다.
rclone copy "offsite:$COCO_OFFSITE_BUCKET" "r2:$COCO_STORAGE_BUCKET" --dry-run --verbose

# 확인한 뒤 실제로 되돌린다. sync가 아니라 copy를 쓴다.
rclone copy "offsite:$COCO_OFFSITE_BUCKET" "r2:$COCO_STORAGE_BUCKET" --verbose
```

복구에는 `sync`가 아니라 `copy`를 쓴다. 방향이 반대인 `sync`는 S3에 없는 R2 객체를 지우므로, 부분 유실 상황에서 살아남은 사진까지 없앨 수 있다.

이미 지워진 사진을 되살려야 한다면 S3 콘솔에서 해당 객체의 삭제 표시를 먼저 제거한 뒤 위 명령을 돌린다. 비현행 버전은 30일까지만 남는다.

### 외부 복사

Mac mini에는 현재 외장 저장장치가 없다. 디스크 장애에 대비한 외부 복사는 별도 저장 위치(외장 SSD 또는 개발 MacBook으로의 주기적 `scp`)를 결정한 뒤 활성화한다. 그 전까지 중요한 변경 전에는 수동으로 최신 덤프를 MacBook으로 복사한다.

```bash
scp joonha@coco-mac-mini:~/coco/backups/coco-*.dump ~/coco-backups/
```

## 11. 진단

```bash
docker compose --env-file .env.production -f compose.production.yaml ps
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 api
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 postgres
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 cloudflared
curl --fail --silent --show-error http://127.0.0.1:19090/actuator/health
```
