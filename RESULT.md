# CoCo Development Result

## 2026-07-22 - Phase 1.1 Domain models and seed data

- Added the shared course, route point, element, user, reaction, and enum models.
- Added two deterministic Seoul seed courses for development and previews.
- Kept Apple map types out of the domain model so the server contract is not tied to MapKit.
- HIG files loaded: none; this step does not change user interface behavior or presentation.
- Verification: `xcodebuild` Debug build for the generic iOS Simulator succeeded with Xcode 26.3 and the iOS 26.2 SDK.

## 2026-07-22 - Phase 1.2 Course exploration map

- Replaced the starter screen with a MapKit course exploration experience.
- Added a persistent native sheet with collapsed and expanded detents, a two-course list, course selection and deselection, and inline element counts.
- Added selected-course route rendering, start and finish markers, category-specific element pins, a legend, and an element detail overlay.
- Kept search, filters, current-location access, and element media out of this milestone as required by `SPEC.md`.
- Used Figma Make version 20 as the visual reference. The Figma design-context API does not support Make files, so the running Make preview and its accessible structure were inspected in the signed-in browser.
- Used a native SwiftUI `Map` and system sheet. Map content is inset above the collapsed sheet so Apple Maps attribution remains visible.
- Added 44-point icon controls, SF Symbols, semantic system colors, Dynamic Type styles, VoiceOver labels and hints, and light/dark material backgrounds.

### HIG files loaded

- Tier 1: `accessibility`, `branding`, `color`, `dark-mode`, `design-principles`, `icons`, `images`, `inclusion`, `layout`, `materials`, `motion`, `privacy`, `right-to-left`, `sf-symbols`, `typography`, `writing`.
- Tier 2: `designing-for-ios`.
- Tier 3: `maps`, `sheets`, `lists-and-tables`, `buttons`, `feedback`, `gestures`, `modality`.
- Related: `multitasking`, `action-sheets`, `popovers`, `panels`, `outline-views`, `collections`, `pull-down-buttons`, `pop-up-buttons`, `toggles`, `segmented-controls`, `playing-haptics`, `playing-audio`, `drag-and-drop`, `alerts`, `activity-views`.

### Verification

- `xcodebuild` Debug build for the generic iOS Simulator succeeded with Xcode 26.3 and the iOS 26.2 SDK.
- Ran the app on an iPhone 16e simulator and visually checked the default collapsed state, selected route state, expanded course list, and element detail overlay.
- Checked the element detail state in both light and dark appearances.
- No UI test target exists yet; interaction states were verified with temporary initial state injection that was removed before the final build.

## 2026-07-22 - Phase 2.1 Server scaffold and API contract

- Added a Spring Boot 4.1.0 server project under `server/` with the Gradle 9.5.1 Wrapper.
- Added Web MVC, Validation, Data JPA, Security, Actuator, Flyway, and PostgreSQL dependencies.
- Fixed Java source, target, and compiler release compatibility at Java 21 while allowing Gradle to run on the installed JDK 22.
- Defined the Phase 2 guest-authentication, course-list, course-detail, and error response contracts in `SPEC.md`.
- HIG files loaded: none; this server-only step does not change user interface behavior or presentation.
- Verification: `./gradlew compileJava` succeeded.

## 2026-07-23 - Phase 2.2 PostgreSQL schema and seed data

- Added a localhost-only PostgreSQL 17 Compose service with health check, persistent volume, and environment-variable configuration.
- Added Flyway migrations for users, hashed auth tokens, courses, route points, elements, scraps, and reactions with ownership, uniqueness, range, and enum constraints.
- Added the two iOS seed courses to PostgreSQL with six route points and three elements each.
- Added JPA entities and detail-fetching repositories without exposing entities as API responses.
- A real PostgreSQL test exposed both a multiple-bag fetch error and joined-collection duplication; internal collections now use sets and return explicitly sorted lists.
- HIG files loaded: none; this server-only step does not change user interface behavior or presentation.
- Verification: `./gradlew test --rerun-tasks` succeeded with Testcontainers PostgreSQL 17; `docker compose config`, container health, Flyway startup, and direct seed counts were also verified.

## 2026-07-23 - Phase 2.3 Guest authentication and course APIs

- Added stateless guest authentication with 30-day bearer tokens; only SHA-256 token hashes are persisted.
- Added JSON authentication failures and stable API error responses for protected and missing resources.
- Added authenticated course-list and course-detail endpoints that return route points and course elements in deterministic order.
- Added integration coverage for guest creation, valid and invalid authentication, both seeded courses, course detail, and missing-course errors.
- Disabled Spring Boot's unused generated development user so the custom bearer-token flow is the only application authentication path.
- HIG files loaded: none; this server-only step does not change user interface behavior or presentation.
- Verification: `./gradlew test --rerun-tasks` succeeded; the Compose-backed server reported `UP`, issued a real guest token, and returned both seeded courses over HTTP.

## 2026-07-23 - Phase 4.1 iOS server-backed course loading

- Replaced the production `CourseStore` seed-data default with `URLSession` calls to guest authentication and the protected course-list API.
- Added Keychain storage for the bearer token and automatic one-time guest-token renewal after a `401` response.
- Added explicit idle, loading, loaded, empty, and failed states with inline retry actions in both sheet detents; startup failures do not present an alert or block map interaction.
- Kept deterministic seed data only for SwiftUI previews.
- Added a build-configured API base URL. Debug uses `localhost:8080` with an ATS exception limited to `localhost`; Release uses `https://api.cocorun.site`.
- Implemented this local Phase 4 slice before Phase 3 deployment to verify the server contract end to end. Mac mini, Tailscale, and HTTPS deployment remain the next infrastructure milestone.
- Phase 5 guest-token storage was pulled forward because authenticated Phase 2 reads require it. Scrap, reaction, and personal-course features remain untouched.

### HIG files loaded

- Tier 1: `accessibility`, `branding`, `color`, `dark-mode`, `design-principles`, `icons`, `images`, `inclusion`, `layout`, `materials`, `motion`, `privacy`, `right-to-left`, `sf-symbols`, `typography`, `writing`.
- Tier 2: `designing-for-ios`.
- Tier 3: `maps`, `sheets`, `lists-and-tables`, `buttons`, `feedback`, `gestures`, `modality`, `loading`, `progress-indicators`, `managing-accounts`, `launching`, `labels`, `scroll-views`, `toolbars`, `voiceover`, `alerts`.
- Related: `multitasking`, `action-sheets`, `popovers`, `panels`, `outline-views`, `collections`, `pull-down-buttons`, `pop-up-buttons`, `toggles`, `segmented-controls`, `playing-haptics`, `playing-audio`, `drag-and-drop`, `activity-views`, `in-app-purchase`, `onboarding`, `settings`, `sign-in-with-apple`, `text-views`, `page-controls`, `pointing-devices`, `sidebars`, `tab-bars`, `search-fields`, `focus-and-selection`, `charts`.

### Verification

- Signed Debug and unsigned Release simulator builds succeeded with Xcode 26.3 and the iOS 26.2 SDK.
- The generated Debug plist contains the localhost API URL and localhost-only ATS exception; the generated Release plist contains `https://api.cocorun.site`.
- On an iPhone 16e simulator, the app created a guest, stored the token, and displayed both PostgreSQL courses. Restarting the app left guest and token row counts unchanged, confirming Keychain reuse.
- Visually checked the loaded state in light and dark appearances and the compact failed/retry state. The new states use semantic colors and Dynamic Type styles.
- No iOS test target exists yet, so URL decoding and state transitions still need automated client tests in a later quality pass.

## 2026-07-23 - Phase 3.1 Production deployment package

- Added a multi-stage Java 21 image that builds the Spring Boot JAR and runs it as a non-root user with an Actuator health check.
- Kept the local PostgreSQL-only Compose workflow unchanged and added a separate production Compose stack that requires an explicit database password.
- The production PostgreSQL service has no host port. The API is published only on `127.0.0.1` for private HTTPS proxying through Tailscale Serve.
- Added guarded PostgreSQL custom-format backup and restore scripts. Restore stops the API, replaces the database contents, and waits for the API to become healthy again.
- Added Mac mini deployment, update, Tailscale Serve, iPhone verification, backup, restore, and diagnostics instructions in `DEPLOYMENT.md`.
- HIG files loaded: none; this infrastructure-only step does not change iOS behavior or presentation.

### Verification

- Built the production image and started a separate ARM64 Compose stack on port `18080`; PostgreSQL and the API both became healthy.
- Confirmed Actuator status `UP`, guest-token issuance, and retrieval of both seeded courses through the containerized API.
- Restarted the API container and confirmed it returned to healthy state.
- Created a database probe, made a custom-format backup, deleted the probe, restored the backup, and recovered the exact `verified` value.
- Confirmed the API was bound to `127.0.0.1:18080` and PostgreSQL exposed no host port.
- `./gradlew test --no-daemon` succeeded. Actual Mac mini Tailscale HTTPS and iPhone verification remain pending target-machine access.

## 2026-07-23 - Phase 3.2 Cloudflare home-server foundation

- Revised the V2 scope around TestFlight beta distribution, Sign in with Apple, guest-account migration, Cloudflare public API access, Tailscale-only operations, CI/CD, and server resource protection.
- Replaced the planned public Tailscale path with a remotely managed Cloudflare Tunnel that connects directly to the private Compose API service; no Spring or PostgreSQL application port is published on the Mac mini.
- Moved Actuator to a separate loopback-only management port so Cloudflare cannot route health and management endpoints.
- Added request-body, Tomcat thread/connection/queue, Hikari connection-pool, container memory/CPU/PID, and log-rotation limits with environment-variable overrides.
- Added a servlet request-size guard that handles both declared and streamed bodies and returns a stable `413 REQUEST_BODY_TOO_LARGE` response.
- Documented the Cloudflare hostname, WAF and rate-limit baseline, Tailscale administration path, production environment setup, deployment, verification, backup, restore, and rollback flow.
- HIG files loaded: none; this infrastructure and server-protection step does not change iOS behavior or presentation.

### Verification

- `./gradlew test --no-daemon --rerun-tasks` succeeded, including an oversized JSON integration test.
- `docker compose config --quiet` accepted the production configuration with required secrets supplied.
- Started the ARM64 production API and PostgreSQL services and confirmed both became healthy.
- Confirmed the API issued a real guest token while the host exposed only `127.0.0.1:19090` for Actuator; the API port did not expose Actuator.
- Confirmed API and PostgreSQL memory, CPU, and PID limits were applied by Docker.
- Pulled `cloudflare/cloudflared:2026.7.2` and confirmed the resolved image is Linux ARM64.
- Actual Cloudflare hostname routing and Mac mini installation remain pending Cloudflare domain/tunnel configuration and target-machine access.

## 2026-07-23 - Phase 3.3 Fedora Asahi host hardening

- Confirmed the Mac mini runs Fedora Asahi Remix 44 directly on ARM64 with Docker Engine 29.5.2 and Compose 5.1.4.
- Enabled the existing Tailscale 1.98.3 service at boot, assigned the stable `coco-mac-mini` hostname, and verified direct MacBook-to-server connectivity.
- Added a dedicated `coco-management` firewalld zone for `tailscale0` that permits only OpenSSH and Cockpit; removed both services from the Wi-Fi zone.
- Kept the existing n8n and PostgreSQL containers untouched and confirmed n8n remains bound to localhost only.
- Disabled and masked the unused Passim local caching service and removed its port 27500 listener.
- Added a version-controlled OpenSSH drop-in that permits only the `joonha` public-key account, blocks root and password login, disables X11 and agent forwarding, and limits authentication pressure.
- Preserved Cockpit on Tailscale port 9090 and moved the planned CoCo Actuator host binding to loopback port 19090.
- HIG files loaded: none; this host infrastructure step does not change iOS behavior or presentation.

### Verification

- A fresh public-key SSH connection over Tailscale succeeded after the firewall and SSH reloads.
- Password-only and root SSH attempts were rejected.
- Cockpit returned HTTP 200 through Tailscale while Wi-Fi access to ports 22 and 9090 was blocked.
- Port 27500 was blocked through the management zone before Passim was stopped and masked.

## 2026-07-23 - Phase 3.4 GitHub Actions and GHCR image delivery

- Added a server workflow that runs Gradle integration tests for pull requests and main-branch pushes on GitHub-hosted Linux ARM64 runners.
- Added a main-only publish job that packages the Spring Boot JAR in a non-root ARM64 image and pushes both `latest` and immutable `sha-<commit>` tags to GHCR.
- Upgraded the Docker Actions to their Node 24 runtimes after the first successful run exposed Node 20 deprecation warnings.
- Changed production Compose to pull `ghcr.io/joooooonha/coco-api` instead of building server source on the Mac mini.
- Kept local image builds available through `compose.production.build.yaml`.
- Added a deployment-bundle script that includes only Compose, environment examples, backup/restore scripts, and host configuration while excluding application source and macOS extended attributes.
- HIG files loaded: none; this CI and server-delivery step does not change iOS behavior or presentation.

### Verification

- `./gradlew test --no-daemon --rerun-tasks` succeeded locally with PostgreSQL Testcontainers.
- A local Linux ARM64 image build succeeded and resolved to user `coco` with the JAR entrypoint.
- GitHub Actions run `29944082265` passed without annotations: server tests completed in 1m31s and the cached image publish completed in 25s.
- Anonymous GHCR inspection found the Linux ARM64 image plus provenance/SBOM attestation and matching `latest` and commit-SHA digests.
- The Fedora Asahi Mac mini anonymously pulled the commit-SHA image and confirmed `architecture=arm64,user=coco`.
- The Mac mini `~/coco` directory contains only five deployment files and no Spring source.

## 2026-07-23 - Phase 3.5 Production domain activation

- Registered `cocorun.site` through Gabia and delegated authoritative DNS to Cloudflare.
- Fixed the public production API hostname at `api.cocorun.site` across deployment examples and the iOS Release configuration.
- Created the remotely managed `coco-production` tunnel and routed `api.cocorun.site` to the private Compose service at `http://api:8080`.
- Started PostgreSQL 17, the GHCR ARM64 Spring image, and pinned `cloudflared` on the Fedora Asahi Mac mini with no public origin ports.
- Enabled Always Use HTTPS, the default Free Managed Ruleset, a custom non-API-path block rule, and the single Free-plan rate limit for guest creation.
- Kept HSTS disabled until the HTTPS deployment and recovery process have a longer stable operating history.
- Kept the tunnel token and database password out of version control.
- HIG files loaded: none; this infrastructure configuration does not change iOS presentation.

### Verification

- Public DNS returned both assigned Cloudflare nameservers for `cocorun.site`.
- An unsigned Release simulator build succeeded and its generated plist contains `https://api.cocorun.site`.
- PostgreSQL and Spring became healthy, local Actuator reported `UP`, and three redundant Seoul Cloudflare tunnel connections registered.
- Public HTTPS guest creation returned `201`; authenticated course retrieval returned `200` with both seeded courses.
- Plain HTTP returned `301` to the same HTTPS path.
- `/` and `/actuator/health` returned Cloudflare `403`, while valid `/api/` traffic continued to reach Spring.
- Eight rapid guest-creation requests returned five `201` responses followed by three `429` responses; a request after the 10-second mitigation window returned `201`.
