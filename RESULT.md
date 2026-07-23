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

## 2026-07-23 - Phase 3.6 Restricted continuous deployment foundation

- Added an immutable-SHA deployment script that verifies the image revision label, serializes deployments with `flock`, waits for API health, and rolls back to the previous image digest on failure.
- Added a forced-command SSH entrypoint that accepts only `deploy sha-<40-character-commit>`.
- Added a main-only GitHub Actions deploy job using Tailscale Workload Identity Federation and `tailscale/github-action@v4`.
- Prevented main-branch workflows from being cancelled during deployment while retaining cancellation for superseded pull-request runs.
- Stored the restricted deployment private key, pinned Mac mini host key, and Tailscale OIDC values in GitHub Secrets; CD is enabled with `COCO_CD_ENABLED=true`.
- Added Tailscale `tag:ci` and `host:coco-mac-mini` definitions, preserving owner-device access while allowing CI only to `tcp:22` on the Mac mini.
- Deferred scheduled backups because production currently contains only reproducible seed data; backups become mandatory before user-created data or the next Flyway migration.
- HIG files loaded: none; this deployment automation does not change iOS behavior or presentation.

### Verification

- Removed nine guest users created by HTTPS and rate-limit verification while preserving the two seeded course owners and both courses.
- `bash -n` passed for all deployment scripts, and the forced-command entrypoint rejected an unsupported SSH command with exit code `64`.
- Deployed the current immutable SHA image on the Mac mini and confirmed the API became healthy.
- Deliberately deployed a nonexistent valid-format SHA; the pull failed, the script restored the previous image digest, and Actuator returned `UP`.
- Verified the GitHub OIDC Subject against the numeric owner and repository IDs received from the issuer.
- GitHub Actions run `29952359896` passed server tests, published the ARM64 image, joined Tailscale as an ephemeral `tag:ci` node, and deployed through the restricted SSH command.
- Confirmed Mac mini container `coco-api-1` is healthy and runs revision `0ce7891613f6287425a9bf19404aead8a6dac0c3` after the workflow.
- Confirmed the public API remains reachable through Cloudflare and returns the expected authenticated response boundary.

## 2026-07-23 - Phase 5.1 Scrap, reaction, and personal course APIs

- Added idempotent scrap save/remove and reaction select/remove endpoints keyed to the authenticated user; duplicate requests do not create duplicate rows or errors.
- Added `GET /api/v1/me/scraps` (newest scrap first) and `GET /api/v1/me/courses` (newest course first).
- Course list and detail responses now return real `scrapCount`, `reactionCounts`, `isScrapped`, and `myReactions` values computed with grouped aggregate queries instead of hardcoded zeros; no per-course N+1 queries.
- Reaction type is validated as a path enum; unknown values return the stable `400 INVALID_REQUEST` response, and scrap or reaction requests against missing courses return `404 COURSE_NOT_FOUND`.
- Reused the existing `course_scraps` and `course_reactions` tables from migration V1; no schema change was needed.
- HIG files loaded: none; this server-only step does not change user interface behavior or presentation.

### Verification

- `./gradlew test --no-daemon --rerun-tasks` succeeded with Testcontainers PostgreSQL 17.
- New integration tests cover scrap idempotency, per-user scrap isolation, reaction counts across two guests, reaction idempotency, invalid reaction enum rejection, missing-course errors, and the empty personal course list.
- The pre-existing deprecation compile note in `ApiIntegrationTest` was confirmed to exist before this change.

## 2026-07-23 - Phase 5.2 iOS scrap, reaction, and library

- Confirmed the top-level structure with the user: an iOS tab bar with 탐색 and 보관함 tabs, and scrap/reaction controls on the selected course summary card.
- Replaced the modal course sheet with a two-stage bottom panel inside the explore tab because a presented `.sheet` covers the tab bar and blocks tab switching; the panel keeps the collapsed/expanded stages, the never-fully-closed rule, background map interaction, a grabber, a chevron button, and a drag gesture.
- Added scrap and reaction toggle chips (bookmark, thumbs-up, flame, mountain SF Symbols) with per-type counts on the selected course card; on-state uses filled symbols plus a green tinted capsule so state is not conveyed by color alone.
- Added optimistic updates with rollback and an inline error caption on failure; per-course and per-reaction pending sets prevent duplicate in-flight toggles.
- Added `LibraryView` with a segmented 스크랩/내 코스 picker, loading, failure-with-retry, per-segment empty states, and pull-to-refresh; library lists are read-only in this milestone.
- Extended `CourseAPIClient` with scrap/reaction writes and `me/scraps`, `me/courses` reads through a shared 401-renewal wrapper.
- Updated `SPEC.md` 4.1 and 4.3 to record the confirmed tab-bar structure and the panel-instead-of-modal-sheet decision.

### HIG files loaded

- Tier 1: `accessibility`, `branding`, `color`, `dark-mode`, `design-principles`, `icons`, `images`, `inclusion`, `layout`, `materials`, `motion`, `privacy`, `right-to-left`, `sf-symbols`, `typography`, `writing`.
- Tier 2: `designing-for-ios`.
- Tier 3: `tab-bars`, `buttons`, `lists-and-tables`, `sheets`, `feedback`, `toggles`, `maps`, `segmented-controls`.

### Verification

- Debug builds succeeded with Xcode 26.3 and the iOS 26.2 SDK after each step.
- The Claude Code simulator panel and tap tools were unavailable on this host, so states were verified headlessly on an iPhone 16e simulator with temporary initial-state injection (selected course, expanded stage, library tab) that was fully removed before the final build; the final build contains no injection code.
- Screenshots confirmed: collapsed panel with visible tab bar, selected course with route/markers/legend and fully visible action chips at the taller collapsed height, expanded list in light and dark mode, and the library scrap list showing the scrapped course.
- Exercising the scrap and LIKE toggles against the local Spring server persisted real `course_scraps` and `course_reactions` rows; a stale pre-Phase-5 dev server on port 8080 was identified and replaced after the first toggle attempt failed with 401 and correctly rolled back with an inline error message, which also verified the failure path.
- iOS automated tests still do not exist; decoding and state-transition tests remain a later quality-pass item.

## 2026-07-23 - Phase 6.1 Course registration and element APIs

- Added `POST /api/v1/courses`: the server assigns ownership from the bearer token, validates name/summary/difficulty/distance/duration lengths and ranges with Bean Validation, requires at least two route points and one element, and enforces contiguous zero-based route sequences with a stable `ROUTE_POINTS_INVALID` error.
- Restricted `routeSource` to `PLANNED_MAPKIT` (`ROUTE_SOURCE_UNSUPPORTED` otherwise) and defaulted a blank `locationLabel` to `서울` because geocoding is out of MVP scope.
- Added owner-only element `POST`/`PATCH`/`DELETE` endpoints; non-owners receive `403 COURSE_OWNER_ONLY`, and deleting a course's last element is rejected with `409 ELEMENT_MINIMUM_REQUIRED` to preserve the one-element product rule.
- Added resource caps (2,000 route points, 50 elements per course) in line with the V2 server-protection baseline.
- Recorded the third 등록 tab decision and the Phase 6 registration contract in `SPEC.md`.
- HIG files loaded: none; this server-only step does not change user interface behavior or presentation.

### Verification

- `./gradlew test --no-daemon --rerun-tasks` succeeded with Testcontainers PostgreSQL 17.
- New integration tests cover successful registration appearing in `me/courses` and the shared list, missing-element and duplicated-sequence and unsupported-source rejections, owner element add/patch/delete, the last-element conflict, and S10 non-owner rejections against seeded course elements.
- Tests that create courses clean them up so seed-count assertions stay deterministic.

## 2026-07-23 - Phase 6.2 iOS registration tab and route planning

- Added the third 등록 tab (user decision) between 탐색 and 보관함 with a two-step push flow, matching the confirmed wire structure.
- Step 1 is a full-map planner: taps append 출발 → 경유(≤5) → 도착 waypoints (7 total max), with 되돌리기/순환 코스/지우기 controls, per-segment `MKDirections` walking calculation, an inline distance·duration·point summary, a calculation progress state, a retry action on failure, and a camera that fits the computed route.
- Step 2 is a form: name, one-line summary, segmented difficulty, a route preview map where tapping snaps a new element to the nearest route vertex with its cumulative distance from the start, an element list with edit sheet (category/title/description) and swipe-to-delete, and a submit button that stays disabled with a hint listing missing requirements.
- Successful registration resets the planner, switches to the explore tab, force-reloads courses, and selects the new course; submission failures show an inline error and keep the draft.
- Route coordinates are downsampled to the server's 2,000-point cap before upload; `locationLabel` is omitted so the server default applies.
- Kept all MapKit types inside the Register feature boundary; the API payload uses plain latitude/longitude values.

### HIG files loaded

- Tier 1: `accessibility`, `branding`, `color`, `dark-mode`, `design-principles`, `icons`, `images`, `inclusion`, `layout`, `materials`, `motion`, `privacy`, `right-to-left`, `sf-symbols`, `typography`, `writing`.
- Tier 2: `designing-for-ios`.
- Tier 3: `tab-bars`, `buttons`, `lists-and-tables`, `sheets`, `feedback`, `toggles`, `maps`, `segmented-controls`, `entering-data`, `text-fields`, `pickers`, `progress-indicators`.

### Verification

- Debug builds succeeded with Xcode 26.3 and the iOS 26.2 SDK.
- With the simulator input tools still unavailable, a temporary scripted walkthrough (removed afterward; zero TEMP markers remain) drove the full flow headlessly on an iPhone 16e simulator against the local Spring server: three Yeouido waypoints produced a real 1.2 km walking route, the step-2 form rendered the draft element snapped to the route at 536 m, and submission created the course.
- The local database showed the created course with 26 route points and the element at 536 m; after submission the app switched to the explore tab with the new course selected, its route, element pin, and legend visible, and the shared list showing three courses.
- The verification course was deleted from the local development database afterward; production was not used for this UI verification.
- S7, S8 (server-side), and S9 scenario behavior is now implemented; on-device manual verification and iOS automated tests remain for the Phase 7 quality pass.

## 2026-07-23 - Phase 6.3 Owner element management in explore

- Added owner-only element management for registered courses in the explore tab, completing the Phase 6 scope.
- The app now stores the guest user id (UserDefaults; the bearer token stays in the Keychain) from guest issuance, course creation, and my-courses responses, so ownership can be decided client-side; the server continues to enforce it authoritatively.
- The selected-course action bar shows a green 요소 추가 button only for owned courses; it enters an add mode with a dismissible top banner, collapses the sheet, and snaps the next map tap to the nearest route vertex with its cumulative distance before opening the shared element editor sheet.
- The element detail overlay gains 수정 and 삭제 buttons for owned courses. Edit reuses the shared editor; delete asks for confirmation in a confirmation dialog and handles the server's last-element `409` with the friendly message from the stable error code.
- Extracted `ElementDraftEditorView` from the registration flow into `Features/Shared` so registration drafts and post-registration editing use one editor.
- Element mutations update the loaded course in place (insert sorted by distance, replace, or remove) without a full list reload; API error codes `ELEMENT_MINIMUM_REQUIRED` and `COURSE_OWNER_ONLY` map to user-facing Korean messages.

### HIG files loaded

- Same set as Phase 6.2 this session, plus `alerts` guidance applied through the native confirmation dialog for destructive deletion.

### Verification

- Debug builds succeeded with Xcode 26.3 and the iOS 26.2 SDK; zero TEMP markers remain.
- A temporary scripted walkthrough (removed afterward) against the local Spring server verified on an iPhone 16e simulator: the owned course showed the 요소 추가 action, the add-mode banner rendered over the map, the element detail overlay showed 수정/삭제, a PATCH renamed the element to `수정된 전망`, a POST added a second element, and a DELETE removed it.
- PostgreSQL confirmed the final state: exactly one element titled `수정된 전망` at 400 m. The verification course was then deleted and the local server stopped.
- Seed courses owned by other users continue to show no management controls; the server-side S10 rejection remains covered by integration tests.
- Real map-tap snapping still needs an on-device pass in Phase 7, since simulator tap injection is unavailable in this environment.

## 2026-07-23 - Phase 6.4 Pinned course submit action

- User feedback from device testing: the 코스 등록 button was only reachable by scrolling to the bottom of the step-2 form and read as missing.
- Moved the submit action out of the form into a bottom `safeAreaInset` bar with a material background, matching the step-1 다음 button, so the primary action is always visible above the tab bar.
- The bar shows the submission error, or the validation hint listing missing requirements while the button is disabled.
- HIG basis: forms should keep the primary action readily accessible; progression stays disabled until required data exists (`entering-data`).
- Verification: Debug build succeeded; a temporary scripted run (removed afterward) captured step 2 on an iPhone 16e simulator with the pinned disabled 코스 등록 button and the 요소-필요 hint visible without scrolling.

## 2026-07-23 - Phase 6.5 Register map camera fix

- Device feedback: the register map appeared to only zoom in. Cause: every route recalculation re-fitted the camera to the route, undoing the user's own zoom-out after each waypoint tap.
- The camera now auto-fits only on the first successful calculation per planning session (flag resets when the route is cleared); later recalculations never override user pan/zoom.
- Verification: Debug build succeeded. Physical pinch verification on device remains with the user; simulator pinch injection needs `xcode-select` pointing at Xcode.app first.

## 2026-07-23 - Phase 6.6 GPX route import

- User request: use Naver Map's course-maker quality routes in CoCo. Confirmed that no public API exists for external walking-route engines (NAVER Cloud Directions 15 is documented as car-only; Kakao pedestrian routing remains partner-only), so file-based GPX import is the official path for external routes. `SPEC.md` moved GPX import into MVP scope (GPX export stays excluded) and now allows `IMPORTED_GPX` alongside `PLANNED_MAPKIT`.
- Server: course creation accepts `IMPORTED_GPX` (no Flyway change needed — the `route_source` check constraint already included it) with a new integration test; other sources still return `ROUTE_SOURCE_UNSUPPORTED`.
- iOS: added a `GPXParser` (Foundation `XMLParser`) that reads `trkpt` sequences plus Naver `walkCourse` distance/duration extensions, with fallback distance from coordinates and duration at 1.25 m/s walking pace; stable Korean error messages for invalid files.
- The register tab toolbar gains a GPX import button backed by `fileImporter`; an imported route enters the existing flow as a ready route with 출발/도착 markers, an import-specific summary line, and the unchanged step-2 info/element/submit path. Clearing the route returns to tap planning.
- HIG files loaded: same session set; `entering-data` (avoid manual entry when data exists) and `alerts` guided the import error alert.

### Verification

- `./gradlew test --no-daemon` passed including the new `IMPORTED_GPX` acceptance test.
- Debug build succeeded; zero TEMP markers remain.
- A temporary scripted run imported the user's actual Naver Map 남산 GPX (324 trkpt) from the app container: step 1 showed the imported route with `4.5 km · 약 87분 · GPX 경로` (matching Naver's 4.5 km / 1시간 26분), and submission created the course with `route_source=IMPORTED_GPX`, distance 4455 m, duration 5194 s, and all 324 route points in PostgreSQL.
- The verification course and container file were removed and the local server stopped. Real file-picker selection needs an on-device pass.

## 2026-07-23 - Backup automation prepared (timer activation deferred)

- Added backup retention (`COCO_BACKUP_RETAIN`, default 14) to `backup-postgres.sh`, version-controlled `coco-backup.service`/`coco-backup.timer` systemd units (daily 04:30 KST, persistent), and bundle-script inclusion.
- Shipped the files to the Mac mini and took the first verified manual backup: the custom-format dump lists all 8 tables.
- The one sudo-requiring step — installing and enabling the timer — is documented in `DEPLOYMENT.md` and deferred by user decision; it must run before TestFlight testers create real data or the next Flyway migration.
- External off-site copy remains manual (`scp` to the MacBook) until an external storage location is chosen.

## 2026-07-23 - Phase 7.1 iOS unit test target

- Added a `CoCoTests` unit test bundle target by editing the objectVersion-77 project directly: a synchronized `CoCoTests` root group, host-app `TEST_HOST`/`BUNDLE_LOADER` settings, and a dependency on the app target. A hand-written shared scheme crashed `xcodebuild`, so the target relies on Xcode's auto-generated scheme, which picks up the test bundle via `TestTargetID`.
- Wrote 15 Swift Testing cases over the pure logic that previously had no coverage:
  - `GPXParserTests`: Naver-style extensions (distance/duration/name), plain GPX without metadata, invalid XML, single-point rejection, out-of-range coordinate skipping.
  - `CourseModelTests`: server-contract JSON decoding (enums, reactions, scrap state), idempotent scrap/reaction mutations with count clamping, element upsert ordering and removal.
  - `RoutePlannerStoreTests`: waypoint cap and loop closing, imported-route metadata use, derived distance/duration fallbacks (1.25 m/s), nearest-vertex snapping with cumulative distance, clear-route origin reset, submit validation gating.
- `GPXParseError` gained `Equatable` for typed `#expect(throws:)` assertions.
- HIG files loaded: none; this test-infrastructure step does not change user interface behavior.

### Verification

- `xcodebuild test` on an iPhone 16e simulator: 15 of 15 test cases passed.
- CourseStore/LibraryStore state-machine tests remain future work because `CourseAPIClient` needs protocol-based injection first.

## 2026-07-23 - Phase 7.2 Dynamic Type accessibility pass

- Audited every main state at the largest accessibility text size (AX5) on an iPhone 16e simulator with a scripted walkthrough. The iOS 26 runtime no longer ships an iPhone SE simulator, so the 16e is the smallest supported device.
- Found and fixed four clipping/overflow defects:
  - The map legend covered most of the map at accessibility sizes; it now hides for accessibility type sizes since the same information is exposed through each pin's VoiceOver label.
  - The collapsed explore panel used fixed heights (190/252 pt) that clipped the selected-course row; the height now scales with `dynamicTypeSize` tiers and is capped at 55% of screen height.
  - The element detail card overflowed the screen and clipped the description; content now falls back to an internal `ScrollView` via `ViewThatFits` under a 460 pt card cap.
  - The register step-1 control row (되돌리기/순환 코스/지우기) overflowed one line; `ViewThatFits` now drops it to a vertical stack when needed.
- The step-2 form, library list, and expanded course list already wrapped correctly and needed no changes.
- HIG basis: Tier 1 `accessibility`/`typography`/`layout` — text must remain legible and unclipped at all Dynamic Type sizes; decorative duplicates may be hidden when redundant accessible labels exist.

### Verification

- AX5 screenshots after the fixes show the legend hidden, the larger collapsed panel showing the full course row header, the element card scrolling internally, and the planner buttons stacked vertically with 다음 fully visible.
- A default-size screenshot confirmed the standard layout is unchanged, and all 15 unit tests still pass.
- VoiceOver labels/hints existed already on interactive controls; a device VoiceOver sweep remains a manual follow-up.

## 2026-07-23 - Simulator QA round 1: library sync, display name, free-stop sheet

- User-reported bug: unscrapping a course in explore left it visible in the library. The library loaded once and cached; it now silently re-fetches on every tab entry, keeping current content visible during refresh instead of flashing a spinner, and keeping stale content if a background refresh fails.
- User-requested feature: guests can rename themselves. Added `PATCH /api/v1/me` (1-20 chars, blank rejected, server-side trim) with an integration test asserting the new name appears as `ownerName` on newly created courses. iOS caches the display name from guest issuance, adds a 보관함 toolbar person button with a rename alert, and force-reloads after a rename.
- User-requested UX change: the two-stage half sheet became a free-stop panel. Dragging the grabber/header follows the finger and stays at any height between a minimum (header always visible) and full height; the course list below is always scrollable, with the selected course sorted first so it stays visible at low heights. Selecting a course still animates up to a peek height that reveals the action bar. `SPEC.md` 4.3 was revised accordingly, and F11/PATCH me were added.
- HIG basis: `gestures` (direct manipulation follows the finger), `lists-and-tables`, `entering-data` for the rename alert field.

### Verification

- Server tests passed including the rename integration test; all 15 iOS unit tests still pass and the Debug build succeeded.
- The new panel renders correctly in the simulator with header, scrollable list, and selected-course peek. Drag feel and the rename flow are being checked interactively in the ongoing simulator QA session.
