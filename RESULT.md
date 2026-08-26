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

## 2026-07-23 - Simulator QA round 2: surface layering and independent map

- User feedback: the tab bar, half sheet, and floating element modal stacked into three competing bottom surfaces, and raising the sheet squeezed the map (legend and pins shifted upward).
- Element details moved from a floating dimmed overlay into the half sheet itself, following the Apple Maps annotation pattern: the sheet header switches to a back button, category badge, and title, and the content area shows distance, description, and owner edit/delete actions. Visible surfaces are now capped at map, sheet, and tab bar.
- The map now keeps a fixed bottom inset equal to the sheet's minimum height, so dragging the sheet slides it over the map instead of resizing the map. Selecting an element raises the sheet to peek height when needed.
- Owner element editing and delete confirmation moved into the sheet; the map keeps only the add-element tap flow.
- `SPEC.md` 4.3 records the independent map/sheet rule and the in-sheet element detail with the three-surface cap.
- HIG basis: `modality` (avoid stacked modal surfaces), `sheets`, `maps` (annotation details belong to the map's companion sheet).

### Verification

- Debug build succeeded; zero TEMP markers remain after the scripted screenshot pass.
- The screenshot shows the element detail inside the sheet with the full-bleed map behind it, no dimming layer, and unshifted map annotations.
- Drag feel and the back-to-list flow continue under interactive simulator QA.

## 2026-07-23 - Simulator QA round 3: element paging, highlights, full-bleed map, photo slot

- Element details now page horizontally: swiping left/right in the sheet moves through the course's elements in distance order with page dots, keeping the header category and title in sync.
- The selected course card gets a soft green row background in addition to the checkmark; the list keeps its order and the card expands in place (previous round's reorder removed).
- The explore navigation bar is hidden so the map runs full-bleed to the top; the tab bar carries the app identity, removing the awkward empty title band.
- Element detail shows a photo-slot placeholder box announcing the future image feature; upload and S3 stay out of scope, recorded in `SPEC.md` 3.5.
- Copied the user's two Naver GPX files into the simulator app's Documents and enabled `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` so the Files app shows an On My iPhone > CoCo folder for GPX import testing on simulator and device alike.

### Verification

- Debug build succeeded; the full-bleed screenshot shows the map under the status bar with the sheet and tab bar as the only other surfaces.
- Element swipe paging, the selection highlight, and Files-app GPX selection continue under interactive simulator QA.

## 2026-07-23 - Simulator QA round 4: map-area filter and course search

- User feedback: the sheet header promised "이 지도 영역에서" but always listed every course, and there was no search. Both were SPEC-excluded; the user approved adding them (F12, F13) while geocoding stays out.
- Added an SDK-free `MapViewport` domain type; the map reports its visible region at the MapKit boundary via `onMapCameraChange`, and `CourseStore.visibleCourses` filters by route bounding-box overlap plus a free-text query over name, summary, location, and owner. The selected course always stays listed, and the header count now reflects the filtered list.
- The sheet gains a search field with a clear button and an empty-filter state ("지도를 움직이거나 검색어를 바꿔 보세요").
- Four new unit tests cover viewport filtering, selected-course pinning, text search fields, and the combined filter (19 total tests pass).
- Also this round: explore now silently refreshes on tab entry so display-name changes reach the shared list, the element editor sheet gained the photo-slot placeholder, and the file-sharing Info.plist keys were fixed by declaring them in the plist file directly (the `INFOPLIST_KEY_UIFileSharingEnabled` build setting was silently ignored).

## 2026-07-23 - Simulator QA round 5: library navigation and course deletion

- Library cards (both scraps and my courses) were inert; tapping now switches to the explore tab with that course selected on the map, where owner element tools live. Rows gained a chevron affordance.
- User-requested: course deletion. Added owner-only `DELETE /api/v1/courses/{courseId}` (404 unknown, 403 non-owner, cascade removes route points, elements, scraps, reactions) with an integration test covering the non-owner rejection and delete-then-404 flow.
- iOS: 내 코스 rows support swipe-to-delete with a destructive confirmation dialog that spells out the cascade, local list removal on success, and an error alert on failure. `SPEC.md` gains F14 and the DELETE row in the API table.
- The floating iOS 26 tab bar position was questioned; confirmed it is the system Liquid Glass design (not adjustable via public API) and the user chose to keep the default over the legacy compatibility mode.

## 2026-08-13 - Phase 8 준비: 정기 백업 활성화와 소셜 로그인 범위 확정

### 정기 백업 활성화

- 사용자가 Mac mini에서 systemd 유닛을 설치하고 `coco-backup.timer`를 활성화했다. 다음 실행은 매일 04:31 KST.
- 타이머 등록만으로는 실행을 보장하지 못하므로, systemd와 같은 최소 환경(`env -i` + 기본 PATH)에서 백업 스크립트를 직접 실행해 검증했다. 종료 코드 0, 새 덤프 생성, `pg_restore --list`로 8개 테이블 데이터 확인.
- 이로써 `DEPLOYMENT.md` 10장에서 "다음 Flyway 변경 전까지" 유예했던 백업 조건이 해소되어 V2 스키마 마이그레이션을 진행할 수 있다.

### 소셜 로그인 제공자 변경

- Sign in with Apple은 capability 활성화에 유료 Apple Developer Program 가입이 필요하고 현재 이 머신에는 서명 인증서와 팀 설정이 없다. 사용자 결정으로 제공자를 Naver와 Kakao로 교체했다.
- 같은 제약으로 TestFlight(V2-F1)도 가입 전까지 진행할 수 없다. 검증은 시뮬레이터와 Xcode 서명 실기기 설치로 계속한다.
- App Store 심사 규정이 서드파티 소셜 로그인 제공 시 Sign in with Apple을 함께 요구하는 점은 공개 배포가 범위에 들어올 때 다시 검토하도록 미결정 사항에 남겼다.

### SPEC 개정 내용

- 2장 용어에 회원 사용자와 외부 신원을 추가했다.
- V2-F2를 Naver·Kakao 소셜 로그인으로 교체하고 V2-F3의 승계 대상을 로그인 계정으로 일반화했다.
- 6.6에 OAuth 2.0 Authorization Code 흐름, 계정 결정 규칙, 수집 범위와 비밀값 관리 기준을 정의했다. 외부 SDK 없이 iOS 네이티브 `ASWebAuthenticationSession`을 사용하고, 클라이언트 비밀값은 서버에만 둔다. 두 제공자 모두 리디렉션 주소를 `https`로 제한하므로 서버 콜백이 커스텀 스킴으로 전달한다.
- 5장에 `AccountType`을 `GUEST`/`MEMBER`로 재정의하고 `linkedProviders`를 추가했다. `external_identities` 신규 테이블과 `account_type` 제약 교체를 마이그레이션 목록에 넣었다.
- 7.3에 로그인·로그아웃·계정 삭제 API 계약과 오류 코드를 정의했다.
- 확인 시나리오 V2-S14~S18(게스트 승계, 재설치 복구, `state` 불일치, 기존 연결 계정, 삭제 후 재로그인)을 추가했다.

## 2026-08-13 - Phase 8 완료: 소셜 로그인과 프로필 화면

### 서버

- Flyway V3: `users.account_type`을 `GUEST`/`MEMBER`로 교체하고 `external_identities` 테이블 추가. 실제 로컬 DB에 적용해 8개 테이블에 마이그레이션이 반영됨을 확인.
- `SocialProviderClient` 인터페이스와 Naver/Kakao 구현체. `RestClient`에 연결·읽기 타임아웃 5초를 명시적으로 설정.
- `SocialLoginService`가 계정 결정 3규칙(이미 연결됨 → 그 계정 / 게스트 승격 / 신규 생성)을 하나의 트랜잭션에서 처리. 게스트 승격 시 표시 이름과 소유 코스가 그대로 유지됨을 테스트로 확인.
- 인가 URL 발급을 서버 책임으로 옮겨 앱 번들에 provider client_id를 넣지 않음.
- `AuthTokenService`로 게스트·소셜 로그인의 토큰 발급/인증/폐기를 통합. `auth`와 `user` 패키지에 중복돼 있던 `UserResponse`를 하나로 정리.
- 계정 삭제: `courses.owner_id ON DELETE RESTRICT` 때문에 코스를 먼저 명시적으로 지운 뒤 사용자를 삭제하는 순서를 트랜잭션으로 보장.
- 통합 테스트 10개 신규(게스트 승계, 신규 회원 생성, 재로그인, 이미 연결된 계정 보호, 로그아웃 범위, 계정 삭제 후 재가입, 프로바이더/리다이렉트 오류, 인가 URL 조립, 콜백 전달). 실제 프로바이더 없이 `SocialProviderClient`를 빈 이름으로 교체하는 스텁으로 검증.
- 서버 테스트 27개 전체 통과.

### iOS

- `User`에 `linkedProviders` 추가, 이전 형태의 응답도 디코딩되도록 커스텀 이니셜라이저 사용.
- `AccountType.apple`을 `member`로 교체.
- `SocialLoginSession`이 `ASWebAuthenticationSession`으로 인가 단계를 수행하고 `state`를 검증. `prefersEphemeralWebBrowserSession`으로 매번 로그인 화면을 명시적으로 띄움.
- `AccountStore`가 로그인/로그아웃/계정 삭제와 세션 초기화 신호를 관리.
- `ProfileView`: 게스트 상태 안내, 제공자별 로그인 버튼, 표시 이름 변경, 로그인 상태에서만 보이는 로그아웃, 계정 삭제 확인 다이얼로그.
- `Info.plist`에 `coco://` URL 스킴 등록.
- 로그인·로그아웃·계정 삭제 후 탐색·보관함이 새 세션으로 갱신되도록 `onSessionReset` 콜백 연결.
- iOS 유닛 테스트 4개 신규(디코딩, 하위 호환, provider 경로/표시명). 전체 23개 통과.

### 검증

- 서버: 로컬 PostgreSQL에 마이그레이션 적용 확인, `./gradlew test` 27개 통과.
- iOS: `xcodebuild test` 23개 통과, 시뮬레이터에서 보관함 → 프로필 화면 진입, 게스트 안내 문구·로그인 버튼·이름 변경·계정 삭제 섹션 렌더링 확인.
- 실제 Naver/Kakao 로그인 종단 검증은 콘솔에 앱 등록(Redirect URI, 클라이언트 자격 증명)이 끝난 뒤 진행한다.

### SPEC과 달라진 부분

- 없음. 이번 세션에서 SPEC을 먼저 개정한 뒤 그대로 구현했다.

## 2026-08-13 - Naver·Kakao 콘솔 등록과 운영 배포

- 사용자가 Naver·Kakao 개발자 콘솔에 앱을 등록했다. Naver 콘솔의 "iOS" 환경(다운로드 URL, URL Scheme)은 네이버 네이티브 SDK 전용이라 CoCo의 `ASWebAuthenticationSession` 기반 웹 OAuth 흐름에는 불필요함을 확인하고 Mobile Web 환경(서비스 URL, Callback URL)만 등록했다.
- Mac mini의 `.env.production`에 4개 자격 증명과 `COCO_SOCIAL_*` 값을 추가했다.
- 배포 과정에서 Mac mini의 `compose.production.yaml`이 이전 버전이라 소셜 로그인 환경변수 전달 줄이 없어 자격 증명이 컨테이너에 전달되지 않는 문제를 발견했다. Mac mini는 GHCR 이미지만 받고 compose 파일은 자동 동기화되지 않는 구조이므로, 저장소의 최신 `compose.production.yaml`을 직접 전송해 해결했다.
- 값을 노출하지 않고 운영 API로 검증: 두 제공자의 `authorize-url` 응답에 실제 길이의 `client_id`가 포함되고 `redirectUri`가 운영 주소(`https://api.cocorun.site/...`)로 정확히 나옴을 확인했다. 콜백 엔드포인트가 `coco://oauth/callback`으로 정확히 리디렉션함을 확인했다. Actuator는 `UP`.
- 실제 사용자 로그인을 통한 종단 검증(제공자 로그인 화면 → 앱 복귀 → 토큰 발급)은 실기기 또는 시뮬레이터에서 다음 단계로 진행한다.

## 2026-08-17 - Phase 9 M1·M2: 자유 그리기 소스와 세그먼트 캐싱

### M1. 서버 DRAWN_FREEHAND 허용

- Flyway `V4`로 `courses_route_source_check` 제약에 `DRAWN_FREEHAND`를 추가했다. 백업 타이머가 활성화된 뒤 처음 적용한 스키마 변경이다.
- `CourseService`의 허용 소스에 추가했고, 아직 클라이언트가 만들 수 없는 `RECORDED_GPS`와 `PLANNED_KAKAO`는 계속 거부한다.
- 통합 테스트: 자유 그리기 코스 등록과 조회 왕복에서 `routeSource`가 유지되는지, 미지원 소스 두 종류가 모두 400인지 확인.
- iOS `RouteSource`에 케이스를 추가하고 M6에서 쓸 배지 문구를 함께 정의했다.

### M2. 세그먼트 캐싱

- 문제: 지점을 추가할 때마다 전체 경로를 다시 계산했다. `MKDirections.Request`가 출발지와 도착지만 받아 지점 N개는 요청 N-1회가 필요한데, 매번 처음부터 다시 요청하면 25개 지점까지 찍는 동안 누적 300회가 된다. 상한을 올리기 전에 반드시 해결해야 하는 구조였다.
- `WalkingRouteCalculator` 프로토콜과 `MapKitWalkingRouteCalculator` 구현으로 구간 계산을 분리했다. 테스트가 요청 횟수를 셀 수 있고 네트워크 없이 검증할 수 있다.
- `RoutePlannerStore`가 구간별 결과를 `[RouteSegment?]`로 보관한다. 지점 추가는 새 구간 1개만 계산하고, 되돌리기는 캐시에서 마지막 항목만 제거해 요청이 발생하지 않는다.
- 합치기(좌표 이어붙이기, 누적 거리 계산)는 로컬 연산이라 캐시가 바뀔 때마다 다시 수행한다. 중복 끝점 제거 규칙은 기존과 동일하다.
- 미해결 구간을 순서대로 처리하는 단일 태스크 구조라, 빠르게 연속 탭해도 이미 해결된 구간은 건너뛴다.
- `retryRouteCalculation()`은 첫 미해결 구간부터 재개하며 이미 받은 구간은 유지한다.

### 검증

- 서버 테스트 28개 통과, 로컬 DB에서 V4 적용과 제약 변경 확인.
- iOS 테스트 29개 통과. 캐싱 테스트 6개가 요청 횟수를 직접 검증한다: 지점 6개 추가 시 5회(캐싱 전이라면 15회), 되돌리기 0회, 되돌린 뒤 재추가 시 1회만 추가, 순환 코스 1회, 지우기 후 재계산.
- 시뮬레이터에서 실제 MapKit 경로 확인: 지점 3개로 10.2 km 경로가 인도를 따라 그려지고, 되돌리기 시 재계산 없이 즉시 2개 지점 7.7 km 경로로 갱신됐다.
- 겉보기 동작은 변하지 않았고 요청 횟수만 줄었다.

## 2026-08-17 - Phase 9 M3: 구간 실패 처리와 진행 상태

- 문제: 한 구간이라도 실패하면 전체가 `.failed`가 되어 이미 받아둔 구간까지 화면에서 사라졌다. 지점이 25개면 24개 구간 중 하나만 실패해도 전부 버리는 셈이라 SPEC의 "실패해도 전체를 버리지 않는다"에 어긋났다.
- 구간 상태를 `RouteSegmentState`(pending / resolved / failed)로 바꿔 구간별로 추적한다. 실패한 구간은 표시만 하고 나머지 구간은 계속 계산한다.
- 구간마다 최대 3회까지 지수 백오프로 재시도한다. `MKError.loadingThrottled`는 요청 폭주가 원인이므로 더 긴 대기(3초 기준)를 적용하고, 그 외 오류는 0.6초 기준으로 시작한다.
- `retryRouteCalculation()`은 실패한 구간만 `pending`으로 되돌려 재요청한다. 이미 받은 구간은 그대로 유지된다.
- `cancelRouteCalculation()`으로 계산을 중단할 수 있고, 남은 구간은 `pending`으로 남아 나중에 재개할 수 있다.
- 지도 렌더링을 정직하게 바꿨다. `resolvedPolylines`는 연속으로 해결된 구간만 묶어 실선으로 그리고, 해결되지 않은 구간을 가로질러 선을 잇지 않는다. 실패한 구간은 두 지점 사이를 빨간 점선으로 표시해 어느 지점을 고쳐야 하는지 보여준다.
- 계산 중에는 `n/m` 진행 표시와 취소 버튼을, 실패 상태에서는 실패 구간 수와 완료 구간 수, 다시 계산 버튼을 노출한다.

### 검증

- iOS 테스트 33개 통과. 실패 관련 신규 5개가 다음을 검증한다: 중간 구간 실패 시 나머지 2구간 유지, 실패 구간의 반복 재시도, 재시도 시 실패 구간만 재요청(호출 1회 증가), 문제 지점 삭제 시 실패 해소, 실패 구간을 사이에 두고 폴리라인이 두 갈래로 분리.
- 시뮬레이터에서 정상 경로와 진행 상태는 확인했으나, **실제 MapKit 실패는 재현하지 못했다.** 서울 시내에서는 임의의 지점을 찍어도 MapKit이 근처 도로로 스냅해 경로를 찾아낸다. 실패 화면(빨간 점선, 실패 안내)의 실제 렌더링은 M4에서 지점 25개로 요청 제한을 측정할 때 다시 확인한다.

## 2026-08-17 - Phase 9 M4: 지점 상한 25개와 요청 제한 측정

- `maximumWaypoints`를 7에서 25(출발 1 + 경유 23 + 도착 1)로 올렸다. 안내 문구에 남은 개수를 함께 표시한다. 지점을 촘촘히 찍는 것이 경로를 의도에 맞추는 유일한 수단이므로 남은 예산을 보여주는 편이 유용하다.
- SPEC이 요구한 요청 제한 측정을 실제 MapKit으로 수행했다. 임시 측정 코드로 구간 24개를 순차 요청한 결과:

  ```
  legs=24  succeeded=22  throttled=0  otherFailures=2  elapsed=2.1s
  실패 사유: 도보 경로를 사용할 수 없음 (leg 3, 4)
  ```

- **요청 제한은 발생하지 않았다.** 24개 구간이 2.1초에 끝나 25개 상한은 안전하다. 상한을 더 올릴 경우 요청 제한보다 계산 대기 시간이 먼저 문제가 될 가능성이 높다는 점을 `SPEC.md` 미결정 사항에 기록했다.
- 측정 부산물로 실제로 보행 경로가 없는 좌표를 확보해, M3에서 재현하지 못했던 실패 화면을 시뮬레이터에서 확인했다. 한강 위를 지나는 구간에서 실패 구간은 빨간 선, 성공 구간은 초록 선으로 끊어져 그려지고, `구간 2개의 보행 경로를 찾지 못했어요` 안내와 `2/4 구간 완료`, `다시 계산` 버튼이 표시되며 `다음` 버튼이 비활성화됐다. M3의 미검증 항목이 해소됐다.
- 측정 코드는 제거했다. 나머지 테스트는 모두 스텁을 사용해 네트워크 없이 동작한다.

### 검증

- iOS 테스트 33개 통과. 상한 확대로 기존 `waypointLimitAndLoopClosing`의 전제(10개를 넣으면 상한에 도달)가 깨져 상한보다 5개 많이 시도하도록 고쳤고, 이 참에 실제 MapKit 대신 스텁을 주입해 네트워크 의존을 없앴다.
- 시뮬레이터에서 상한 문구(`20개 더 가능`)와 실패 화면을 확인했다. TEMP 마커는 남아 있지 않다.

## 2026-08-17 - Phase 9 M5: 자유 그리기 모드

- 등록 탭에 경로 만드는 방식 전환(지점 찍기 / 직접 그리기)을 추가했다. 기본은 지점 찍기다.
- 사용자 결정에 따라 방식 A를 택했다. 그리기 모드에서는 `Map(interactionModes: [])`로 지도 이동을 막아 드래그가 항상 그리기로 해석된다. 제스처 충돌 없이 동작하고, 지도를 옮기려면 지점 찍기로 잠시 돌아가면 된다.
- 드래그 궤적을 화면 좌표 8pt 간격으로 샘플링해 좌표로 만든다. 터치 이벤트마다 좌표를 만들면 한 획이 수천 점이 되므로 샘플링이 필요하다.
- 도로 스냅과 경로 계산을 하지 않는다. 그린 선이 곧 경로이며, 거리는 좌표 간 거리의 합, 시간은 GPX 가져오기와 같은 1.25 m/s 기준 추정이다. 요약 문구에도 "예상"임을 명시한다.
- 획 단위로 누적된다(`drawnStrokes`). 손을 떼고 지점 찍기로 전환해 지도를 옮긴 뒤 다시 그리면 같은 경로에 이어진다. 되돌리기는 마지막 획만 제거한다.
- 저장 전 확인 수단으로 위성 지도 토글을 툴바에 추가했다. `.hybrid`를 써서 위성 영상 위에 도로명이 함께 보이므로 강이나 건물을 지나는지 판단할 수 있다.
- 두 모드는 배타적이다. 작업 내용이 있는 상태에서 모드를 바꾸면 확인 다이얼로그로 한 번 막는다.
- `RouteOrigin`에 `routeSource` 매핑을 두어 등록 시 `DRAWN_FREEHAND`로 저장한다.

### 검증

- iOS 테스트 42개 통과. 자유 그리기 신규 9개가 다음을 검증한다: 그리기는 라우팅 요청을 전혀 만들지 않음(호출 0회), 거리·시간이 그린 선에서 계산됨, 획 누적, 되돌리기가 마지막 획만 제거, 2점 미만 획 무시, 그리기 중 탭 무시, 모드 전환 시 초기화, `routeSource` 매핑, 요소가 그린 선에 스냅.
- 시뮬레이터에서 실제로 그려 확인했다. 남산을 가로지르는 선이 도로 스냅 없이 그대로 유지되고 `14.2 km · 약 190분 예상 · 직접 그린 경로`로 표시됐다. 위성 지도로 전환하면 같은 선이 지형 위에 겹쳐 보여 검토가 가능했다. 모드 전환 시 확인 다이얼로그가 떴다.

## 2026-08-17 - Phase 9 M6: 경로 출처 배지

- `RouteSourceBadge`를 만들어 탐색 목록과 보관함 목록에서 같은 규칙으로 표시한다. 자유 그리기는 주황색 `직접 그린 경로`, GPX 가져오기는 파란색 `가져온 경로`, 도보 경로 계산으로 만든 코스는 배지가 없다.
- 배지 문구는 `RouteSource.badgeLabel`에 두어 표시 규칙이 한곳에 모이게 했다.
- VoiceOver 레이블에도 출처를 포함해 화면을 보지 않아도 경로 출처를 알 수 있게 했다.

### 검증

- iOS 테스트 42개 통과.
- 로컬 서버에 자유 그리기 코스와 계획 코스를 각각 등록해 시뮬레이터에서 확인했다. 한 목록 안에서 `직접 그린 경로`(주황), `가져온 경로`(파랑), 배지 없음 세 종류가 구분돼 보였다. 확인 후 테스트 코스는 로컬 DB에서 삭제했다.

## Phase 9 마무리

MapKit이 출발지와 도착지만 받는 제약 위에서 정밀한 경로 생성을 가능하게 하는 것이 이번 단계의 목표였다.

- 지점 상한 7 → 25. 상한을 올리기 전에 세그먼트 캐싱으로 누적 요청을 300회에서 24회로 줄인 것이 전제였다.
- 요청 제한은 실측 결과 발생하지 않았고(24구간 2.1초), 근거를 `SPEC.md` 미결정 사항에 남겼다.
- 구간 단위 실패 처리로 일부 구간이 실패해도 나머지를 유지하고, 실패한 구간만 재시도한다.
- 자유 그리기로 도로망에 없는 숲길과 지름길을 표현할 수 있고, 출처를 배지로 드러내 다른 러너가 판단하게 한다.
- 설계 판단은 `DECISIONS.md` D1~D5에 정리했다.

남은 V2 범위는 Phase 10(요소 사진)과 Phase 11(UI 완성도)이다.

## 2026-08-17 - Phase 10a-1: 서버 사진 저장소와 API

사진 바이트가 서버를 통과하지 않는 구조를 먼저 만들었다. Spring은 권한과 한도만 검사하고 사전 서명 URL을 발급한다.

- `ObjectStorage` 인터페이스와 S3 호환 구현(`S3CompatibleObjectStorage`)을 두었다. R2와 S3가 같은 API를 쓰므로 엔드포인트와 자격 증명만 다르다. R2는 가상 호스트 방식 주소를 쓰지 않아 `pathStyleAccessEnabled`를 켠다.
- 자격 증명이 없으면 `UnconfiguredObjectStorage`가 대신 주입된다. 개발 환경에서 서버는 그대로 뜨고 사진 API만 `503 PHOTO_STORAGE_UNAVAILABLE`을 반환한다. 저장소 설정 때문에 기동이 막히면 관련 없는 작업까지 멈춘다.
- 흐름은 발급 → 직접 업로드 → 확정 3단계다. 확정에서 객체 존재와 크기를 다시 확인하므로, 발급 요청에 작은 크기를 적고 큰 파일을 올리는 우회가 막힌다. 한도를 넘긴 객체는 그 자리에서 지운다.
- 객체 키는 `courses/{courseId}/elements/{elementId}.{jpg|heic}`로 고정했다. SPEC의 초안은 업로드마다 UUID를 붙이는 형태였지만, 그러면 확정에 실패한 재시도가 그대로 잔여 객체가 된다. 고정 키에서는 같은 형식으로 다시 올리면 덮어써지고, 형식이 바뀌는 교체에서만 이전 객체가 남으므로 그때만 명시적으로 지운다.
- 코스 삭제와 요소 삭제 경로에서 저장된 객체를 함께 지운다. DB 행은 외래 키로 연쇄 삭제되지만 객체는 가리키는 것이 없어도 남는다.
- V5 마이그레이션으로 `photo_object_key`와 `photo_uploaded_at`을 추가했다. 두 컬럼이 함께 채워지거나 함께 비어 있도록 CHECK 제약을 걸어, 확정되지 않은 반쪽 상태가 저장되지 않게 했다.
- `photoURL`은 응답 매핑 단계에서 사전 서명 GET URL(유효 1시간)로 만든다. 저장소 키는 어떤 응답에도 넣지 않는다.

### 검증

- 서버 테스트 35개 통과(신규 7개). 저장소는 크기만 기억하는 인메모리 스텁으로 대체해 네트워크 없이 돌아간다.
- 신규 테스트가 검증하는 것: 발급만으로는 사진이 붙지 않음, 업로드 전 확정은 `409`, 확정 후 목록·상세에 `photoURL`이 보임, 사진 삭제가 행과 객체를 모두 지우고 재삭제는 무해함, 코스 삭제가 객체를 함께 지움, 허용하지 않는 형식은 `400`·초과 크기는 `413`, 확정 시 크기 재검사, 작성자가 아니면 `403`, JPEG를 HEIC로 교체할 때 이전 객체가 남지 않음.
- 테스트 키 이름은 사전 서명 URL에서 되읽는다. 키 생성 규칙을 테스트가 다시 쓰면 규칙이 바뀔 때 함께 틀어진다.

## 2026-08-17 - Phase 10a-1 후속: 사진 캐시 키

- 요소 응답에 `photoUploadedAt`을 추가했다. `photoURL`은 서명 시각이 들어 있어 응답마다 달라지므로 클라이언트 캐시 키로 쓸 수 없다.
- 사진 조회 방식은 사전 서명 GET URL로 확정하고 `SPEC.md` 미결정 사항에서 뺐다. 네 가지 대안과 트레이드오프는 `DECISIONS.md` D27에 정리했다.
- 서버 테스트 41개 통과. 신규 2개가 업로드 시각의 안정성(같은 사진을 두 번 읽어도 값이 같음)과 교체 시 변경, 그리고 사진이 없는 요소에는 URL도 시각도 없음을 확인한다.
- 사전 서명 URL이 실제로 시간에 따라 달라진다는 사실은 저장소 단위 테스트에서 `X-Amz-Date`와 `X-Amz-Signature`가 URL에 포함되는지로 확인한다. 통합 테스트의 스텁은 고정 문자열을 돌려주므로 그 성질을 검증할 수 없다.

## 2026-08-18 - Phase 10a-2: iOS 사진 업로드

서버가 발급한 사전 서명 URL로 앱이 직접 올리고, 조회는 자체 캐시를 거치게 했다.

### 가공과 EXIF 제거

- `ElementPhotoProcessor`가 긴 변 1600px로 축소하고 JPEG로 재인코딩한다. 품질은 0.8부터 낮춰가며 5 MiB를 맞추고 치수는 더 건드리지 않는다.
- EXIF를 "지우는" 코드는 없다. 새 비트맵에 다시 그리고 인코딩하므로 원본에서 복사되는 항목 자체가 없다. 방향 정보도 이 과정에서 픽셀에 반영돼 별도 태그가 필요 없어진다.
- 이미 작은 사진도 같은 경로를 지난다. 다시 그리는 것이 최적화가 아니라 메타데이터 제거 수단이기 때문이다.

### 업로드

- `uploadElementPhoto`가 발급 → 저장소 직접 PUT → 확정 세 단계를 수행한다.
- 저장소로 가는 PUT에는 CoCo 토큰을 붙이지 않는다. 그 요청의 권한은 URL 안의 서명이 전부다.
- 저장소가 업로드를 거부하면 확정으로 넘어가지 않는다. 확정까지 갔다면 서버가 검증할 수 없는 사진이 붙는다.

### 캐시

- `ElementPhotoCache`는 `elementId_photoUploadedAt`을 파일 이름으로 `Library/Caches`에 저장한다. 용량 80 MB, 초과 시 최근 사용 순으로 비운다.
- `AsyncImage`를 쓰지 않는다. 그 경로의 `URLCache`는 URL 전체를 키로 쓰는데 사전 서명 URL은 매번 달라져 항상 빗나간다(D27).
- 디코딩에 실패한 응답은 캐시하지 않는다. 만료된 URL이 돌려주는 오류 본문을 저장하면 그 사진이 영구히 깨진다.

### 화면

- 요소 상세와 요소 편집의 사진 자리 표시를 실제 사진으로 교체했다.
- 요소 편집에서 `PhotosPicker`로 추가·교체·제거한다. 제거는 저장 시점에 서버에 반영되므로 시트를 취소하면 기존 사진이 남는다.
- 코스 등록은 요소를 한 번에 만들기 때문에 등록 응답을 받은 뒤 사진을 올린다. 초안과 요소를 거리 순으로 짝짓고 제목·거리가 일치할 때만 보낸다(D28).

### 검증

- iOS 테스트 66개 통과(신규 24개). 서버 테스트 41개 통과.
- 위치 정보 제거는 실제로 GPS EXIF를 심은 JPEG를 만들어 검증한다. 픽스처 자체에 위치가 있는지 먼저 확인하므로, 검사 방법이 고장 나서 통과하는 경우가 걸러진다.
- 업로드 순서와 헤더는 `URLProtocol` 스텁으로 검증한다. 저장소 PUT에 `Authorization`이 없고 본문이 가공된 바이트와 같은지까지 확인한다.
- 캐시는 임시 디렉터리를 주입해 검증한다. 같은 사진을 두 번 요청하면 네트워크 호출이 1회인지, 방금 읽은 항목이 축출에서 살아남는지 확인한다.
- 실제 R2 왕복은 콘솔 작업이 끝난 뒤에 확인한다.

## 2026-08-18 - Phase 10a-2 검증: 저장소 미설정 경로

R2 자격 증명 없이 확인할 수 있는 부분을 시뮬레이터에서 먼저 돌렸다. 로컬 서버를 새 빌드로 재시작해 V5가 적용됐고, 사진 API는 `503 PHOTO_STORAGE_UNAVAILABLE`을 반환한다.

확인한 것:

- 사진이 없는 요소 상세가 "등록된 사진이 없어요"로 바뀌었다. 이전의 "들어갈 예정이에요" 자리 표시는 사라졌다.
- `PhotosPicker`로 고른 사진이 가공되어 편집 화면에 미리보기로 뜨고, 버튼이 추가에서 바꾸기·제거로 바뀐다.
- 코스 등록에서 사진 업로드가 실패하면 "코스는 등록됐지만 일부 사진을 올리지 못했어요" 알림을 띄우고, 확인을 눌러야 지도로 넘어간다. 코스 자체는 정상 등록된다.
- 요소 수정에서 사진 업로드가 실패하면 요소 상세에 "사진 기능을 잠시 사용할 수 없어요"가 뜬다.

검증 중에 찾은 결함 2개를 고쳤다.

### 코스를 바꿔도 이전 요소 상세가 남던 문제

등록 직후 새 코스로 이동하면 시트 헤더에 직전 코스의 요소 제목이 그대로 남아 있었다. 본문은 새 코스의 요소라 제목과 내용이 서로 다른 요소를 가리켰다.

원인은 `selectedElement`를 지우는 책임이 호출부마다 흩어져 있던 것이다. 보관함 경로는 지우고 있었지만 등록 완료 경로는 빠져 있었다. `selectedCourseID`의 `didSet`으로 옮겨 코스가 바뀌면 항상 함께 지워지게 했다. 회귀 테스트 3개를 붙였다.

### 요소 수정에서 사진 실패가 조용히 넘어가던 문제

편집 시트는 저장하자마자 닫히는데, 오류 문구는 코스 액션 줄에만 있어서 요소 상세에서는 보이지 않았다. 사용자 입장에서는 사진을 고르고 저장했는데 아무 일도 일어나지 않은 것처럼 보인다. 요소 상세에도 같은 문구를 띄우게 했다.

같이 고친 것으로, 사진 단계가 실패하면 이미 저장된 텍스트 수정까지 화면에 반영되지 않고 있었다. 요소 저장과 사진 업로드를 분리해 텍스트는 먼저 반영하고, 사진 실패는 "요소는 저장했지만 사진을 올리지 못했어요"로 구분해 알린다.

### 남은 것

- 실제 R2 왕복(업로드 → 조회 → 캐시 적중 → 교체 → 삭제)은 콘솔 작업 후에 확인한다.
- 보관함 "내 코스" 빈 상태 문구가 "코스 등록 기능이 열리면"으로 남아 있다. 등록은 이미 동작하므로 Phase 11에서 고친다.

## 2026-08-18 - Phase 10a-2 검증: 실제 R2 왕복

R2 자격 증명을 로컬 서버에 연결하고 실제 버킷을 상대로 확인했다.

### API 수준

발급 → PUT → 확정 → 조회 → 삭제를 순서대로 돌렸다.

- 발급된 URL의 서명 대상은 `content-length;content-type;host`, 유효 시간 300초.
- R2에 직접 PUT `200`, 사전 서명 GET으로 내려받은 바이트가 올린 파일과 정확히 일치.
- 서명 없이 같은 주소로 접근하면 `400`. 버킷이 비공개로 유지되고 있다.
- 목록 응답을 다시 받아도 `photoUploadedAt`은 그대로이고 `photoURL`의 서명만 바뀐다. 캐시 키 설계의 전제가 실제로 성립한다.
- 삭제 후 응답에서 `photoURL`·`photoUploadedAt`이 사라지고 저장소 객체도 `404`.

### 앱 수준

시뮬레이터에서 코스를 등록하며 사진을 붙였다. 경고 없이 등록됐고 요소 상세에 사진이 표시된다. 앱 캐시 디렉터리에 `{elementId}_{업로드시각}.jpg` 파일이 생긴 것도 확인했다.

### EXIF에 대한 정정

업로드된 객체를 내려받아 JPEG 세그먼트를 직접 뜯어보니 **EXIF 블록이 남아 있었다.** "재인코딩하면 메타데이터가 아무것도 남지 않는다"고 적었던 것은 사실이 아니다.

남아 있는 태그는 `Orientation`, `XResolution`, `YResolution`, `ResolutionUnit`, `ColorSpace`, `PixelXDimension`, `PixelYDimension`뿐이다. GPS IFD 포인터(`0x8825`)는 없고 촬영 시각과 기기 모델도 없다. 원본에서 복사된 것이 아니라 `UIImage.jpegData`가 비트맵을 설명하려고 새로 쓰는 값들이다.

즉 개인정보 관점의 결론은 그대로지만 근거가 달랐다. 검증도 "EXIF가 없다"가 아니라 "식별 가능한 태그가 없다"를 확인해야 맞다. 테스트를 GPS·촬영 시각·기기 제조사·모델·사용자 코멘트를 모두 심은 픽스처로 바꾸고, 각각이 사라지는지와 인코더 자신의 태그는 남는지를 함께 확인하도록 고쳤다. `SPEC.md`와 코드 주석의 문구도 정정했다.

## 2026-08-19 - 운영 배포와 캐시 키 정밀도 결함

`.env.production`에 R2 자격 증명을 넣고 `api` 컨테이너를 재생성했다. `compose.production.yaml`의 `COCO_STORAGE_*` 전달은 `7234687` 배포 때 `sync-ops`가 이미 맞춰둔 상태였다.

운영 API로 발급 → PUT → 확정 → 조회 → 코스 삭제를 돌려 전부 확인했다. 서명 없이 접근하면 `400`, 코스를 지우면 객체도 `404`가 된다.

### 로컬에서는 드러날 수 없던 결함

확정 응답이 돌려준 시각과 그 직후 조회한 시각이 서로 달랐다.

```
확정 응답 : 2026-08-19T11:56:23.301523242Z   (나노초)
재조회    : 2026-08-19T11:56:23.301523Z      (마이크로초)
```

`Instant.now()`는 Linux에서 나노초까지 주지만 `TIMESTAMPTZ`는 마이크로초까지만 저장한다. 개발 맥에서는 `Instant.now()` 자체가 마이크로초라 잘림이 일어나지 않아 같은 값이 나왔고, 그래서 로컬 검증과 테스트 모두 통과했다.

클라이언트는 이 값을 사진 캐시 키로 쓴다. 업로드 직후 캐시한 항목은 나노초 키를 갖는데 다음 조회부터는 마이크로초 키로 찾게 되어, 방금 올린 사진을 한 번 더 내려받고 처음 저장한 항목은 영영 적중하지 않는 쓰레기가 된다.

확정 시각을 `truncatedTo(ChronoUnit.MICROS)`로 컬럼 정밀도에 맞춰 기록하도록 고쳤다. 통합 테스트에는 확정 응답의 시각과 재조회한 시각이 같은지 확인하는 단언을 넣었다. 개발 맥에서는 이 단언이 결함을 잡지 못하지만 CI는 Linux에서 돌기 때문에 재발하면 거기서 걸린다.

교훈은 시각 정밀도가 플랫폼에 따라 다르고, 저장 계층이 잘라내는 값을 그대로 응답에 실으면 안 된다는 것이다. 저장할 값과 돌려줄 값을 같게 만드는 책임은 저장하는 쪽에 있다.

## 2026-08-19 - Phase 10b: 사진 오프사이트 백업 (콘솔 작업 전까지)

R2 사진을 S3로 매일 단방향 동기화하는 구성을 만들었다. AWS 콘솔 작업 전까지의 코드와 문서가 끝난 상태다.

- `scripts/sync-photos-offsite.sh` — `rclone sync`로 R2 버킷을 S3 버킷에 맞춘다. 사진은 5 MiB 이하 단일 파트라 ETag가 곧 MD5여서, 제공자가 달라도 `--checksum` 비교가 성립하고 매번 다시 올리지 않는다.
- 자격 증명은 `.env.production`에서 읽어 `RCLONE_CONFIG_*` 환경 변수로 넘긴다. rclone 설정 파일에 시크릿을 한 벌 더 두지 않는다.
- S3 값이 비어 있으면 실패가 아니라 건너뛴다. 콘솔 작업 전까지 타이머가 매일 실패로 기록되면 진짜 실패가 묻힌다.
- 실행마다 `2026-08-19T19:45:03Z ok copied=3 deleted=0` 한 줄을 남긴다. 성공한 날의 파일 목록은 남기지 않는다. 실패했을 때만 rclone 전체 출력을 낸다.
- `coco-photo-sync.timer`는 DB 백업(04:30) 다음인 04:45에 돈다.
- 대량 삭제 임계값은 두지 않기로 했다. 근거는 `DECISIONS.md` D29.
- 복구는 `sync`가 아니라 `copy`로 한다. 방향이 반대인 `sync`는 부분 유실 상황에서 살아남은 사진까지 지운다. 절차는 `DEPLOYMENT.md`에 적었다.

### 검증

로컬에 rclone을 설치해 실제 R2 버킷으로 원격 설정을 확인했다. 환경 변수만으로 remote가 구성되고 객체 목록이 조회된다. `rclone lsd r2:`(버킷 목록)는 `403`인데, 토큰 권한을 버킷 하나로 좁혀둔 결과라 정상이다. 동기화는 항상 버킷을 명시하므로 영향이 없다.

### 정리하다 발견한 고아 객체

R2에 사진 1개가 가리키는 것 없이 남아 있었다. 시뮬레이터 QA로 올린 사진인데, 뒤처리를 API가 아니라 psql로 `delete from courses`를 해서 생긴 것이다. DB 행은 연쇄 삭제됐지만 `deleteStoredPhotos`가 실행되지 않아 객체만 남았다.

코드 결함은 아니다. API의 코스 삭제 경로는 운영에서 객체까지 지워지는 것을 확인했다. 테스트 데이터는 SQL이 아니라 API로 지워야 한다는 것이 교훈이다. 남은 객체는 삭제했고 DB와 R2 양쪽이 비어 있는 것을 확인했다.

다만 같은 상황이 사람 실수 없이도 생길 수 있다. **DB 백업을 복원하면** 덤프 시점 이후에 만들어진 코스는 DB에서 사라지지만 사진은 R2에 남는다. 정합성 점검 스크립트를 `BACKLOG.md`에 후보로 적었다.

## 2026-08-25 - 재부팅 복구 검증과 Phase 10b 연결

### 37일 만의 재부팅

맥미니를 껐다 켰다. 설계상 그래야 한다고 적어둔 복구 사슬이 실제로 그렇게 동작했다.

- 컨테이너 셋(`postgres`, `api`, `cloudflared`)이 사람 개입 없이 복귀했고 `api`와 `postgres`는 healthcheck를 통과했다.
- 공개 API 게스트 발급 `201`, 코스 조회 정상.
- `Persistent=true`가 부팅 직후 놓친 백업을 보충했고 종료 코드 `0`으로 성공했다.

`depends_on`은 이 경로에 관여하지 않는다. 부팅 시 컨테이너를 되살리는 것은 compose가 아니라 Docker 데몬이라 순서 보장이 없고, 재시작 정책의 반복 시도로 수렴한다.

### 11일간 조용히 실패하던 백업

재부팅 전 점검에서 마지막 백업이 8일 전인 것을 발견했다. 원인은 SELinux였다. 스크립트 실행 권한은 정상(`-rwxr-xr-x`)인데 컨텍스트가 `user_home_t`라 systemd가 실행하지 못했다. 8/13 배포 번들을 다시 풀 때 레이블이 바뀐 것으로 보인다.

`semanage fcontext`로 `~/coco/scripts`에 `bin_t`를 지정해 해결했다. 이후 `scp`로 새로 보낸 파일도 자동으로 `bin_t`가 붙는 것을 확인했으므로 배포 때마다 `restorecon`을 돌릴 필요는 없다.

`DECISIONS.md` D29에서 "실패를 무엇으로 알아챌 것인가"를 미해결로 남겼는데, 그 사이 실제로 11번 연속 실패가 아무에게도 보이지 않았다. 가정이 아니라 실증된 문제가 됐다.

### 오프사이트 백업 검증

R2 → S3 동기화를 실제 버킷으로 확인했다.

- 복사: `copied=1`, `rclone check --checksum` 결과 0 differences.
- 삭제 전파: 코스를 지우면 R2에서 객체가 사라지고 다음 동기화가 S3에서도 지운다(`deleted=1`).
- 버전 보존: 삭제 후 현행 목록은 비지만 버전과 삭제 표시를 포함하면 객체가 남는다. 사진 두 장의 바이트 116,590이 그대로 있다.
- **복구 예행**: `--s3-version-at`으로 삭제 직전 시점을 지정해 되돌리니 원래 객체 키로 58,295 bytes가 그대로 돌아왔다.

검증 중 두 가지를 고쳤다.

**IAM 정책이 부족했다.** 처음 문서에 적은 권한으로는 동기화는 되지만 버전을 읽을 수 없었다. 백업의 존재 이유가 복구인데 그 경로가 막혀 있던 셈이라 `GetBucketVersioning`, `ListBucketVersions`, `GetObjectVersion` 세 가지 읽기 권한을 추가했다. `DeleteObjectVersion`은 넣지 않았다. 이 자격 증명이 유출돼도 이전 버전은 지울 수 없어야 안전망이 의미를 갖는다.

**중간에 잘못된 결론을 냈다.** `rclone lsl --s3-versions`가 비어 있는 것을 보고 버전이 보존되지 않는다고 판단했으나, 그 명령은 삭제 표시가 붙은 객체를 감춘다. `rclone size --s3-versions --s3-version-deleted`로 세어 보니 바이트가 그대로 있었다. 도구가 보여주지 않는 것과 존재하지 않는 것은 다르다.

## 2026-08-26 - Phase 11 시작: 접근성과 상태 완결성

UI 개선의 기준을 세 층으로 나눴다. 재는 것(접근성 수치), 세는 것(화면별 상태 완결성), 판단하는 것(HIG 원칙과 제품 목표)이다. 앞의 두 층은 통과/실패가 명확해 먼저 처리했다.

읽은 HIG 문서: `design-principles`, `accessibility`, `layout`, `writing`, `color`, `dark-mode`, `designing-for-ios`.

### 터치 대상 28pt → 44pt

요소 수정·삭제, 스크랩, 반응, 등록 화면의 보조 버튼 8곳이 `minHeight: 28`이었다. HIG의 iOS 기본값은 44×44pt이고 28pt는 절대 최소치다. 달리면서 조작하는 앱에서 바닥값에 붙여둘 이유가 없어 전부 44pt로 올렸다.

### 스와이프 전용 삭제에 화면상 대안 추가

코스 삭제가 행 스와이프로만 가능했다. HIG 접근성 문서의 "모든 제스처에 화면상 대안을 제공하라"에 어긋나고, Switch Control이나 Voice Control 사용자에게는 기능 자체가 닿지 않는다.

내 코스에 항목이 있을 때만 툴바에 편집 버튼을 두고, 편집 모드에서 행마다 삭제 컨트롤이 나오게 했다. 스와이프는 그대로 둔다.

`EditButton`은 쓰지 않았다. 그 버튼은 자기가 놓인 환경의 `editMode`를 읽는데 툴바는 리스트 바깥이라 두 상태가 따로 놀았다. 실제로 편집 모드가 켜져도 행에 삭제 컨트롤이 나오지 않았다. 직접 만든 버튼이 하나의 `@State`를 토글하게 바꿔 해결했다.

편집 버튼이 사라지는 조건(마지막 코스 삭제, 스크랩 탭 전환)에서 편집 모드를 끄지 않으면 목록이 편집 상태로 갇힌다. `canDeleteCourses` 변화를 감시해 함께 해제한다.

### 빈 상태의 행동 유도 교정

두 빈 상태의 액션이 모두 `새로 고침`이었다. 코스가 하나도 없는 사람에게 목록 갱신은 다음 단계가 아니다. HIG writing은 빈 상태에 "명확한 다음 단계와 행동"을 요구한다.

- 스크랩 → `코스 둘러보기`(탐색 탭으로)
- 내 코스 → `코스 등록하기`(등록 탭으로)

내 코스의 설명 문구가 "코스 등록 기능이 열리면 직접 계획한 코스가 여기에 표시돼요"로 남아 있었다. 등록은 오래전부터 동작하므로 사실과 다른 안내였다.

### 검증 중 발견: 앱이 스스로를 영어 앱으로 선언하고 있었다

편집 모드를 확인하다 시스템이 주는 문구가 `Edit`, `Delete`로 영어인 것을 발견했다. 앱이 쓴 문구는 전부 한국어인데 시스템 제공 문구만 영어였다.

원인은 프로젝트 설정이었다. `developmentRegion = en`, `knownRegions = (en, Base)`라 iOS가 이 앱을 영어 앱으로 보고 시스템 문자열을 영어로 제공했다. `ko`로 바꾸고 `CFBundleDevelopmentRegion`을 Info.plist에 명시하니 `삭제`로 나온다.

정적 점검으로는 찾을 수 없는 종류다. 앱 코드에 영어 문자열이 하나도 없었기 때문이다.

### 통과 확인

- 색 단독 의존 없음. 요소 카테고리는 색과 고유 SF Symbol을 함께 쓰고 반응은 채움/비움으로 상태를 구분한다.
- 하드코딩된 색값과 `.system(size:)` 고정 폰트가 없다. Dark Mode와 Dynamic Type의 토대는 이미 갖춰져 있다.

### 남은 것

Dynamic Type 200%와 VoiceOver 실기 점검, 대비비 측정은 아직이다.

## 2026-08-26 - Phase 11: Dynamic Type 최대 크기 점검

`accessibility-extra-extra-extra-large`로 올리고 화면을 하나씩 지나며 확인했다. 정적 점검으로는 하나도 나오지 않던 결함이 다섯 개 나왔다.

### 시트 헤더에서 코스 개수가 잘림

"러닝 코스 6개"가 "러닝 코스…"로 잘려 개수를 볼 수 없었다. 이 헤더의 존재 이유가 개수라 잘리면 안 된다. `fixedSize(horizontal: false, vertical: true)`로 줄바꿈해 흘려보낸다.

### 작성자 이니셜 원이 찌그러짐

44pt 고정 원 안의 글자가 원보다 커져 넘쳤다. 이 원은 장식이고 이미 VoiceOver에서 숨겨져 있으므로 접근성 크기에서는 감춘다. 덕분에 코스 이름에 쓸 가로 공간도 늘었다. `MapCanvasView`가 범례에 쓰던 것과 같은 판단이다.

### 코스 카드의 이름·난이도·배지가 한 줄에서 밀림

큰 글자에서 이름이 한 줄에 갇혀 잘렸다. 접근성 크기에서는 이름을 최대 3줄로 두고 난이도와 배지를 아래로 내린다. 작성자·지역도 2줄까지 허용했다. 어느 동네인지는 달릴지 판단하는 데 쓰이는 정보라 생략표로 날리지 않는다.

### 등록 화면에서 지도가 사라짐

`safeAreaInset`으로 붙인 조작 패널이 글자 크기만큼 자라면서 지도를 얇은 띠로 밀어냈다. 지도를 탭해 지점을 찍는 것이 이 화면의 전부인데 그 작업이 불가능해진다. 접근성 크기에서 패널 높이를 300pt로 제한하고 내부를 스크롤시켜 지도가 화면 절반을 유지하게 했다.

### 요소 상세에서 페이지 인디케이터가 본문을 덮음

`TabView`의 기본 인디케이터는 내용 위에 떠 있어 큰 글자에서 설명 문구를 가렸다. 스크롤 안쪽에 여백을 줘도 소용없었다. 인디케이터가 스크롤 위치와 무관하게 하단에 고정되기 때문이다.

인디케이터를 끄고 별도 행으로 내렸다. 이 과정에서 요소 간 이동이 스와이프 전용이었다는 것도 함께 해결된다. `‹ 1 / 3 ›` 형태로 이전·다음 버튼(각 44pt)과 현재 위치를 제공하고, VoiceOver에는 "3개 요소 중 1번째"로 읽힌다.

### 확인

표준 크기로 되돌려 회귀가 없는 것도 확인했다. iOS 테스트 73개 통과.

### 남은 것

VoiceOver 실기 점검과 대비비 측정은 아직이다. `ProfileView`의 접근성 레이블이 1개뿐이라 그쪽부터 볼 예정이다.

## 2026-08-26 - Phase 11: VoiceOver 점검과 대비비 측정

읽은 HIG 문서에 `voiceover`를 추가했다.

### VoiceOver는 대부분 이미 되어 있었다

지도 마커는 "경관, 강변 노을 전망"으로 읽히고 힌트가 붙어 있으며, 반응·스크랩 버튼은 레이블·값·힌트에 `isSelected` 트레이트까지 갖췄다. 요소 초안 행은 자식을 묶어 한 번에 읽히고 장식 글리프는 숨겨져 있다.

고친 것은 두 곳이다.

- `ProfileView`의 이름 바꾸기 버튼이 "노을러너, 바꾸기"로 읽혀 무엇을 하는 버튼인지 불분명했다. 레이블을 "표시 이름 바꾸기", 값을 현재 이름으로 나눴다.
- 등록 화면 지도의 요소 글리프가 주석 제목과 같은 내용을 한 번 더 읽게 하고 있어 숨겼다.

### 대비비는 측정해서 결론을 냈다

색 값을 문서에서 가져와 계산하는 대신 **시뮬레이터에서 iOS가 실제로 해석한 색을 재는 테스트**를 만들었다(`ColorContrastTests`). 라이트·다크와 Increase Contrast 켜짐·꺼짐을 각각 해석해 비율을 계산한다.

결과가 예상과 달랐다. 카테고리 색을 12pt 텍스트로 쓸 때, Increase Contrast를 켜도 기준(4.5:1)에 못 미쳤다.

```
경관 4.38:1   주의 3.83:1   편의 3.85:1
```

HIG는 "기본 상태에서 못 미치면 Increase Contrast에서 충족시켜라"라고 하는데, 시스템 색의 접근성 변형으로도 이 크기의 글자에는 모자랐다. 다크 모드와 마커의 흰 글리프는 통과했다.

그래서 **색을 글자에서 걷어내고 글리프와 칩에만 남겼다.** 글리프는 비텍스트라 기준이 3:1이고 그건 통과한다. 카테고리 이름과 개수, 경로 출처 배지의 글자는 시스템 라벨 색을 쓴다. 색이 사라진 것이 아니라 색이 붙는 자리를 옮긴 것이고, "색에만 의존하지 않는다"는 조건은 글리프 모양과 단어가 그대로 만족한다.

테스트는 현재 계약(글리프 3:1)을 검증하도록 맞췄다. 나중에 누군가 색을 다시 작은 글자에 쓰면 이 측정이 근거가 된다.

### 검증

iOS 테스트 76개 통과. Increase Contrast와 텍스트 크기를 기본값으로 되돌려 회귀가 없는 것도 확인했다.
