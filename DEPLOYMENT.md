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

## 9. 업데이트

`main`에 서버 변경이 push되면 `.github/workflows/server-ci.yml`이 테스트 후 다음 이미지를 발행한다.

- `ghcr.io/joooooonha/coco-api:latest`
- `ghcr.io/joooooonha/coco-api:sha-<전체-커밋-SHA>`

현재 Mac mini 반영 단계는 수동 pull이다.

```bash
docker compose --env-file .env.production -f compose.production.yaml pull api
docker compose --env-file .env.production -f compose.production.yaml up -d --wait api
curl --fail --silent --show-error http://127.0.0.1:19090/actuator/health
```

롤백은 `.env.production`의 `COCO_API_IMAGE`를 정상 동작했던 `sha-<전체-커밋-SHA>` 태그로 바꾸고 같은 pull/up 명령을 실행한다. 다음 단계에서 GitHub Actions가 임시 Tailscale 노드로 접속해 이 반영과 헬스 체크를 자동화한다.

## 10. 백업과 복구

```bash
./scripts/backup-postgres.sh
./scripts/restore-postgres.sh backups/coco-YYYYMMDDTHHMMSSZ.dump --confirm
```

백업은 `backups/`에 생성되며 Git에서 제외된다. 정기 백업은 Mac mini와 다른 저장 장치에도 복사한다. 복구 스크립트는 API를 중지하고 DB를 교체한 뒤 API가 다시 healthy가 될 때까지 기다린다.

## 11. 진단

```bash
docker compose --env-file .env.production -f compose.production.yaml ps
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 api
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 postgres
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 cloudflared
curl --fail --silent --show-error http://127.0.0.1:19090/actuator/health
```
