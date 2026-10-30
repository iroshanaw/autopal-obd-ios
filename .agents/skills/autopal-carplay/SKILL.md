---
name: autopal-carplay
description: Build or change Autopal's CarPlay presence — driving-task templates, the Drive monitor Live Activity, the vehicle health widget — and test them in CarPlay Simulator. Use for any CarPlay, ActivityKit or WidgetKit work.
---

# CarPlay, Live Activity and widgets

## What Apple allows (Oct 2026 CarPlay Developer Guide)
- Driving-task apps: templates only; **no data refresh more than once every 10 s ("no realtime engine data")**; depth ≤ 3 (iOS 26.4+);
  no settings or account setup on CarPlay. Templates: tab bar, list, grid, alert, action sheet, voice control (confirm others in the guide).
- Custom drawing exists only for navigation apps' map base view. We never use `CPMapTemplate`.
- The `com.apple.developer.carplay-driving-task` entitlement must be granted by Apple. Until then the CarPlay scene stays behind a build flag.

## CarPlay templates (UI_DESIGN-iOS §6)
- `CarPlaySceneDelegate` → `CPTabBarTemplate` [Health, Faults].
- Health: `CPListTemplate`; first row = verdict; then Coolant, Battery, Fuel, Engine. Row titles constant; detail text carries values
  ("114 °C · HOT"); row image from `ImageRenderer(GaugeView(...))` at the car's scale.
- Faults: plain-language title, detail "P0420 · Service soon".
- `CarPlayThrottle` (unit-tested): coalesce updates; apply at most every 10 s; alert start/end allowed immediately only if ≥ 10 s since last.
- Critical alert: one `CPAlertTemplate` with "OK"; once per alert.

## Drive monitor Live Activity
- `DriveActivityAttributes` shared by app and widget extension. Start on `LIVE` (if enabled), end on `NO_ECU`/disconnect.
- Update ≤ every 10–15 s and on alert change; include `staleDate`.
- Layouts: Lock Screen, Dynamic Island (compact / minimal / expanded), and the small family used by CarPlay
  (`.supplementalActivityFamilies([.small])` [Likely]; verify on CarPlay Simulator).
- Content: verdict word, coolant gauge, battery value, alert line. Colours from `AutopalTokens`. Text never only colour.

## Vehicle health widget
- `systemSmall` (CarPlay, Home Screen, StandBy) and `accessoryRectangular` (Lock Screen). Reads `SharedSnapshot` only.
- Shows "updated <age> ago"; never claims to be live.

## Testing
- CarPlay Simulator (Device Hub in Xcode 27 / Additional Tools) at small, wide and portrait sizes, light and dark; also with knob/touchpad input.
- Checks CP-1…CP-8 in TESTING-iOS.md; record videos into `docs/evidence/`.
- Report which checks ran in the simulator and which need the real head unit (Lenovo D1 in the Wigo).
