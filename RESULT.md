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
