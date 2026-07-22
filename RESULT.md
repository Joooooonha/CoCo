# CoCo Development Result

## 2026-07-22 - Phase 1.1 Domain models and seed data

- Added the shared course, route point, element, user, reaction, and enum models.
- Added two deterministic Seoul seed courses for development and previews.
- Kept Apple map types out of the domain model so the server contract is not tied to MapKit.
- HIG files loaded: none; this step does not change user interface behavior or presentation.
- Verification: `xcodebuild` Debug build for the generic iOS Simulator succeeded with Xcode 26.3 and the iOS 26.2 SDK.
