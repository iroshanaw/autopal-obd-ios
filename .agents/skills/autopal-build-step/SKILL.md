---
name: autopal-build-step
description: Implement exactly one step of the Autopal iOS build order (AGENTS.md), test-first, and stop. Use when asked to build, implement or continue the iOS app, or do "the next step".
---

# Implement one iOS build-order step

## 1. Pick the step
- Read `docs/STATUS-iOS.md`. Do the earliest step in the AGENTS.md build order that is not ✅, unless the owner named one.
- If an earlier step's evidence is missing, say so first. One step per task; large steps go through `/plan`.

## 2. Read before writing
- ARCHITECTURE-iOS.md sections for this step's types; TESTING-iOS.md for its tests; the module's `AGENTS.md`.
- For UI steps also `docs/UI_DESIGN-iOS.md` and the matching PNGs in `docs/design/screens/`.

## 3. Tests first (core steps)
- Swift Testing, parameterised over `Resources/vectors/*.csv` and `Resources/elm-sessions/*.elm`.
- Run `swift test --package-path AutopalCore`; confirm the new tests fail for the right reason.
- Never edit existing fixture lines. If one looks wrong, stop and show the byte arithmetic.

## 4. Implement
- Smallest code that passes and follows the architecture. Core: no Apple UI/radio imports; injected clock; `Sendable`.
- No new dependencies without asking.

## 5. Verify
```bash
swift test --package-path AutopalCore
scripts/check-guardrails.sh
xcodebuild -scheme Autopal -destination 'platform=iOS Simulator,name=<an installed iPhone>' build   # app steps
```
UI steps: render the SwiftUI previews you added (both themes, compact and regular) and compare with the design PNGs.

## 6. Report (exact format)
```
Step <n>: <name>
Result: compiles | passes fixtures | works on <device/car>   (highest that is TRUE)
Tests: <passed>/<total>   (paste the summary line)
Not verified: <what needs a device, car, adapter or CarPlay unit; test IDs from TESTING-iOS.md>
Files changed: <list>
```
Then `autopal-status-update`. Suggest `autopal-review` in a new conversation before committing.

## Step 0 details (scaffold)
- Xcode: iOS App (SwiftUI), name `Autopal`, bundle id `com.autopal.obd`, iOS 26.0 minimum, Swift 6.
- Local Swift package `AutopalCore` (File › New › Package) added to the project; app depends on it.
- Widget Extension `AutopalWidgets` with "Include Live Activity".
- Capabilities: App Groups `group.com.autopal.obd` (app + widgets), Background Modes › Uses Bluetooth LE accessories.
- Info.plist keys and scene manifest per ARCHITECTURE-iOS §6.6. CarPlay entitlement is added only after Apple grants it; keep the CarPlay scene behind a build flag until then.
- Done when the app and widget build and `swift test` runs (0 tests is fine).
