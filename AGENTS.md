# AGENTS.md — Autopal OBD for iPhone, iPhone Duo and CarPlay

Kept short: it is read at the start of every agent task. Details are in `docs/` and `.agents/skills/`.
Module rules: `AutopalCore/AGENTS.md`, `Autopal/AGENTS.md`. (`CLAUDE.md` files import these for Claude Agent.)

## Before any task
1. Read `docs/STATUS-iOS.md` (what is proven) and `docs/ARCHITECTURE-iOS.md` (the design).
2. Read `docs/TESTING-iOS.md` before tests; `docs/UI_DESIGN-iOS.md` before any UI, widget, Live Activity or CarPlay work.
3. Anything larger than one file: use plan mode (`/plan`) and wait for approval.

## What this is
The iOS version of Autopal OBD: reads engine data and fault codes from an ELM327-compatible OBD-II adapter over BLE or Wi-Fi,
turns them into a health verdict and alerts, and shows them on iPhone, iPhone Duo, iPad, CarPlay, Live Activities and widgets.
The Android app exists and uses the same protocol and the same test fixtures. The owner is an experienced engineer, newer to iOS:
explain non-obvious iOS decisions in one or two lines.

## Commands
```bash
swift test --package-path AutopalCore                 # protocol core; must pass before every commit; no device needed
xcodebuild -scheme Autopal -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
scripts/check-guardrails.sh                           # same checks as the pre-commit hook and CI
python3 scripts/tokens_to_swift.py                    # regenerate AutopalTokens.swift from docs/design/tokens.json
```
Adjust simulator names to what `xcrun simctl list devices` shows (iPhone Duo once Device Hub provides it).

## Rules that apply everywhere
1. **One ELM327 command in flight.** All adapter I/O goes through `ElmSession.send(_:)`.
2. **A command ends at the `>` prompt**, never when a write completes.
3. **Never send Mode 04 (clear fault codes)** or anything that changes vehicle state.
4. **BLE UUIDs only in `BleUartCandidates.swift`.** A pipe is accepted only after `ATZ` returns `ELM327`.
5. **No Bluetooth Classic / External Accessory code.** iOS uses BLE and Wi-Fi only.
6. **Test fixtures are read-only.** Never change or delete existing lines in `AutopalCore/Tests/AutopalCoreTests/Resources/`.
   They are shared with the Android app. Appending rows via `autopal-add-pid` and adding files under `elm-sessions/recorded/` is allowed.
7. **Hardware bug → fixture first.** Reproduce as a fixture, watch it fail, then fix.
8. **CarPlay:** templates only; never more than one data refresh every 10 seconds; no live RPM/speed on CarPlay; no settings,
   account setup or Demo mode on CarPlay; template depth ≤ 3. Never use `CPMapTemplate` (we are not a navigation app).
9. **Design first.** UI follows `docs/UI_DESIGN-iOS.md` (incl. §4a Motion) and `docs/design/`. Colours only from the generated `AutopalTokens.swift`.
   Use standard SwiftUI bars, tab views and toolbars so the system applies Liquid Glass; no custom glass behind numbers.
10. **No fixed screen sizes or orientations.** Layout by size class and container size (iPhone Duo folds, unfolds and splits).
11. No third-party dependencies (Swift packages, CocoaPods) without asking.
12. **English only; no payments in stage 1.** No StoreKit code, paywalls or "Pro" labels until stage 2; gate future features only through `Entitlements`.

## Honesty rules
- Status words: "compiles" < "passes fixtures" < "works on <device / car / adapter>". Only a file in `docs/evidence/` supports "works on".
- Tag uncertain claims [Certain] / [Likely] / [Guessing]. Say what you could not run (no device, no car, no adapter, no CarPlay unit).
- End every task by updating `docs/STATUS-iOS.md` (evidence link or "unverified").

## Build order (one step per task; skill `autopal-build-step`)
0. Project scaffold: `AutopalCore` package, app target, widget extension, App Group, capabilities, Info.plist keys (ARCHITECTURE §6.6).
1. Core: `Hex`, `ElmReply`, `ElmSession`, `TrafficLog` → tests green.
2. Core: `PidCatalog`, `SupportedPids`, `Dtc`, `Readiness`, `Vin` → vectors green.
3. Core: `PollScheduler`, `AlertEngine`, `HealthCheck` → scheduler, alert scenarios, health-check tests green.
4. Core: `ObdClient` + `FixtureTransport` → every `.elm` fixture green.
5. Core: `SimulatedElm327Transport`.
6. App: `AppModel`, `VehicleStore`, `ConnectionManager`, Demo mode; theme + components from the design.
7. App: `BleTransport` → owner runs T-iBLE-1/2 on `IOS-VLINK` → evidence.
8. App: screens (Setup first run, Home incl. not-connected, Health check, Faults, Settings, Adapter, Engine off, Traffic log) for compact and regular widths; `SettingsStore` (appearance, units, alerts).
9. App: `WifiTransport`.
10. Live Activity + widgets.
11. CarPlay templates (CarPlay Simulator; entitlement request in parallel).
12. iPhone Duo pass: folded, unfolded, Split View, fold/unfold continuity.

## Project skills (`.agents/skills/`, also visible as `.claude/skills/`)
| Skill | Use for |
|---|---|
| `autopal-build-step` | Implementing exactly one build-order step |
| `autopal-add-pid` | Adding a new OBD value end to end |
| `autopal-elm-fixture` | Turning an exported traffic log into a fixture |
| `autopal-ble-debug` | CoreBluetooth / Wi-Fi adapter problems on a real iPhone |
| `autopal-carplay` | CarPlay templates, Live Activity and widgets on CarPlay, CarPlay Simulator |
| `autopal-apply-design` | Building any screen, widget or Live Activity from the design |
| `autopal-review` | Reviewing a diff before commit (new conversation) |
| `autopal-status-update` | Updating `docs/STATUS-iOS.md` with evidence |

## Settled — do not reopen
- No custom-drawn gauges inside CarPlay templates; custom visuals on CarPlay come only from the Live Activity and widgets.
- Alert thresholds come from `alert_scenarios.csv` (provisional until the mechanical engineer's review), same as Android.
