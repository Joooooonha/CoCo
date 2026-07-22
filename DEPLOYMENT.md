# CoCo Mac mini 홈서버 배포

CoCo의 일반 사용자 API는 Cloudflare Tunnel로 공개하고, Mac mini 관리와 CI/CD는 Tailscale 사설망으로 분리한다.

```text
iPhone -> Cloudflare HTTPS -> Cloudflare Tunnel -> cloudflared -> Spring:8080 -> PostgreSQL
MacBook/GitHub Actions -> Tailscale -> Mac mini SSH
Mac mini localhost:9090 -> Spring Actuator
```

PostgreSQL과 Spring API 포트는 호스트 공용 네트워크에 노출하지 않는다. Actuator `9090`만 `127.0.0.1`에 연결한다.

## 1. 준비물

- Apple Silicon Mac mini
- Docker Desktop과 Docker Compose
- Cloudflare에서 DNS를 관리하는 도메인
- Cloudflare Tunnel 생성 권한
- Mac mini와 개발 MacBook에 설치된 Tailscale
- Mac mini의 macOS 원격 로그인(SSH)

Docker Desktop에서 **Settings > General > Start Docker Desktop when you sign in to your computer**를 활성화한다. Mac mini는 잠자기를 끄고 가능하면 유선 네트워크를 사용한다.

참고:

- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/
- https://developers.cloudflare.com/tunnel/setup/
- https://tailscale.com/docs/install/mac
- https://docs.docker.com/desktop/settings-and-maintenance/settings/

## 2. Cloudflare Tunnel 생성

1. Cloudflare Dashboard의 **Networking > Tunnels**에서 `coco-production` 터널을 만든다.
2. Docker 환경을 선택하고 표시되는 터널 토큰을 별도로 보관한다.
3. 공개 호스트 이름을 `api.<보유한-도메인>`으로 만든다.
4. 서비스 주소를 `http://api:8080`으로 지정한다.
5. 일반 iOS 사용자가 접근해야 하므로 이 API 호스트에 Cloudflare Access 로그인을 요구하지 않는다.

터널 토큰을 가진 사람은 터널 커넥터를 실행할 수 있으므로 Git에 커밋하거나 로그에 출력하지 않는다.

## 3. Mac mini 환경 설정

```bash
git clone https://github.com/Joooooonha/CoCo.git
cd CoCo
cp .env.production.example .env.production
openssl rand -base64 32
```

`.env.production`에서 다음 값을 실제 값으로 바꾼다.

```dotenv
COCO_DB_PASSWORD=<생성한 긴 비밀번호>
CLOUDFLARE_TUNNEL_TOKEN=<Cloudflare 터널 토큰>
COCO_PUBLIC_API_BASE_URL=https://api.<보유한-도메인>
```

나머지 값은 1차 홈서버 보호 기본값이다. Mac mini 사양과 부하 측정 없이 상한을 높이지 않는다.

## 4. 시작과 확인

```bash
docker compose --env-file .env.production -f compose.production.yaml config
docker compose --env-file .env.production -f compose.production.yaml up -d --build --wait
docker compose --env-file .env.production -f compose.production.yaml ps
curl --fail --silent --show-error http://127.0.0.1:9090/actuator/health
curl --fail --silent --show-error https://api.<보유한-도메인>/api/v1/auth/guest -X POST
```

기대 상태:

- `postgres`, `api`, `cloudflared`가 실행 중이다.
- `postgres`는 호스트 포트가 없다.
- `api`는 `127.0.0.1:9090` 관리 포트만 가진다.
- 로컬 Actuator 응답 상태가 `UP`이다.
- 공개 HTTPS 게스트 인증이 성공한다.
- `https://api.<보유한-도메인>/actuator/health`는 접근되지 않는다.

## 5. Cloudflare 보호 설정

Cloudflare Security에서 실제 트래픽을 관찰하며 다음 순서로 적용한다.

1. HTTP DDoS Managed Rules 기본 활성 상태를 유지한다.
2. WAF Managed Rules를 활성화한다.
3. `/api/v1/auth/guest`에 IP 기준의 낮은 Rate Limit을 둔다.
4. 코스 등록과 반응 같은 쓰기 경로에 읽기보다 낮은 Rate Limit을 둔다.
5. `/actuator*` 경로를 Edge에서도 차단한다.

Cloudflare Rate Limit은 짧은 집계 지연이 있을 수 있으므로 Spring의 인증, 요청 크기와 자원 상한을 제거하지 않는다.

참고:

- https://developers.cloudflare.com/ddos-protection/managed-rulesets/http/
- https://developers.cloudflare.com/waf/
- https://developers.cloudflare.com/waf/rate-limiting-rules/

## 6. Tailscale 관리 경로

Tailscale Serve는 일반 앱 요청에 사용하지 않는다. MacBook과 Mac mini를 같은 tailnet에 연결하고, macOS 원격 로그인으로 SSH만 허용한다.

```bash
tailscale status
ssh <mac-mini-user>@<mac-mini-tailscale-hostname>
```

공유기의 `22`, `8080`, `9090`, `5432` 포트를 포워딩하지 않는다. 후속 GitHub Actions 배포도 임시 Tailscale 노드에서 이 SSH 경로를 사용한다.

## 7. iOS 서버 주소

Xcode Target의 Release 빌드 설정 `COCO_API_BASE_URL`을 다음 값으로 변경한다.

```text
https://api.<보유한-도메인>
```

Debug의 `http://localhost:8080`은 MacBook 로컬 개발용으로 유지한다.

## 8. 업데이트

현재 수동 배포 단계:

```bash
git pull --ff-only
docker compose --env-file .env.production -f compose.production.yaml up -d --build --wait
curl --fail --silent --show-error http://127.0.0.1:9090/actuator/health
```

CI/CD 단계에서는 Mac mini 빌드를 제거하고 GHCR의 커밋 SHA 이미지를 `pull`하도록 전환한다.

## 9. 백업과 복구

```bash
./scripts/backup-postgres.sh
./scripts/restore-postgres.sh backups/coco-YYYYMMDDTHHMMSSZ.dump --confirm
```

백업은 `backups/`에 생성되며 Git에서 제외된다. 정기 백업은 Mac mini와 다른 저장 장치에도 복사한다. 복구 스크립트는 API를 중지하고 DB를 교체한 뒤 API가 다시 healthy가 될 때까지 기다린다.

## 10. 진단

```bash
docker compose --env-file .env.production -f compose.production.yaml ps
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 api
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 postgres
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 cloudflared
curl --fail --silent --show-error http://127.0.0.1:9090/actuator/health
```
