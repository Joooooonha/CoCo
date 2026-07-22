# CoCo Mac mini deployment

CoCo runs as two Docker Compose services on the Mac mini. PostgreSQL is reachable only from the Compose network. The Spring API binds to `127.0.0.1`, and Tailscale Serve provides private HTTPS access to devices in the same tailnet.

## 1. Prerequisites

- Docker Desktop or Docker Engine with Compose
- Tailscale for macOS, signed in to the same tailnet as the iPhone
- Tailscale CLI integration enabled

In Docker Desktop, enable **Settings > General > Start Docker Desktop when you sign in to your computer** so the Compose restart policies can take effect after a Mac login. Tailscale's standalone macOS client can install the CLI from **Settings > CLI integration**. Do not enable Tailscale Funnel for CoCo; Funnel makes a service public.

References:

- https://tailscale.com/docs/install/mac
- https://tailscale.com/docs/reference/tailscale-cli?tab=macos
- https://tailscale.com/docs/features/tailscale-serve
- https://docs.docker.com/desktop/settings-and-maintenance/settings/

## 2. Configure and start

```bash
git clone https://github.com/Joooooonha/CoCo.git
cd CoCo
cp .env.production.example .env.production
openssl rand -base64 32
```

Put the generated value in `COCO_DB_PASSWORD` inside `.env.production`. Keep that file only on the Mac mini.

```bash
docker compose --env-file .env.production -f compose.production.yaml config
docker compose --env-file .env.production -f compose.production.yaml up -d --build --wait
docker compose --env-file .env.production -f compose.production.yaml ps
curl --fail --silent --show-error http://127.0.0.1:8080/actuator/health
```

The final command must return a JSON response whose status is `UP`. PostgreSQL has no host port, and the API host port is loopback-only.

## 3. Enable private HTTPS

```bash
tailscale status
tailscale serve --bg 8080
tailscale serve status
```

The first Serve command may ask you to enable HTTPS certificates for the tailnet. Copy the printed `https://<machine>.<tailnet>.ts.net` URL and verify this endpoint from the iPhone while Tailscale is connected:

```text
https://<machine>.<tailnet>.ts.net/actuator/health
```

Set the Xcode target's Release build setting `COCO_API_BASE_URL` to the printed HTTPS base URL before installing the app on the iPhone.

## 4. Update

```bash
git pull --ff-only
docker compose --env-file .env.production -f compose.production.yaml up -d --build --wait
curl --fail --silent --show-error http://127.0.0.1:8080/actuator/health
```

## 5. Backup and restore

Create a timestamped PostgreSQL custom-format backup:

```bash
./scripts/backup-postgres.sh
```

Backups are written to `backups/`, which is ignored by Git. Move copies to storage outside the Mac mini on a regular schedule.

Restoring replaces the current database contents. The script requires an explicit confirmation flag, stops the API during the restore, then waits for it to become healthy again:

```bash
./scripts/restore-postgres.sh backups/coco-YYYYMMDDTHHMMSSZ.dump --confirm
```

## 6. Diagnostics

```bash
docker compose --env-file .env.production -f compose.production.yaml ps
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 api
docker compose --env-file .env.production -f compose.production.yaml logs --tail=200 postgres
tailscale serve status
```
