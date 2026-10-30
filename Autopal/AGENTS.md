# Autopal/AGENTS.md — iOS app, widgets, Live Activity, CarPlay

Applies to the app target and `AutopalWidgets/`. The root `AGENTS.md` still applies.
UI work: use `autopal-apply-design`. CarPlay, Live Activity, widgets: `autopal-carplay`. Radio problems: `autopal-ble-debug`.

## Architecture
- `AppModel` is created once in `AutopalApp` and owns `ConnectionManager` (actor), `VehicleStore` (`@Observable @MainActor`), `SettingsStore`.
  Views, the CarPlay scene and the Live Activity controller observe `VehicleStore`. No per-view connections.
- Widgets run out of process: they read only the App Group snapshot (`SharedSnapshot`). Reload timelines only when verdict or alert changes.
- `GaugeView` (SwiftUI) is the only gauge drawing; CarPlay row images come from `ImageRenderer(content: GaugeView(...))`.

## CoreBluetooth
- One `CBCentralManager` with a restore identifier; `bluetooth-central` background mode.
- Enable notify and wait for `didUpdateNotificationStateFor` before the first write.
- UUIDs only in `BleUartCandidates.swift`. Save the confirmed pipe per peripheral identifier.
- Bridge delegate callbacks into the actor; never block the main thread.

## Layout (iPhone Duo, iPad, Split View)
- Compact width: `TabView` (Home, Check, Faults, Adapter). Regular width: `NavigationSplitView` (sidebar, readings, health).
- No `UIScreen.main`, no fixed frame sizes for screens, no orientation locks. Use size classes, `containerRelativeFrame`, `ViewThatFits`.
- Fold/unfold/resize must not reconnect or lose state.

## Liquid Glass
- Standard `TabView`, `NavigationStack`/`NavigationSplitView`, `.toolbar`, sheets: the system draws Liquid Glass.
- `.glassEffect()` only on custom floating controls (inside a `GlassEffectContainer` when several). Content cards are solid `surface`.
- Never put glass behind gauges or numbers. Respect Reduce Transparency and Increase Contrast.

## CarPlay
- Templates only (`CPTabBarTemplate`, `CPListTemplate`, `CPAlertTemplate`, `CPActionSheetTemplate`); never `CPMapTemplate`.
- `CarPlayThrottle`: ≤ 1 update / 10 s; constant row titles; depth ≤ 3; no settings or Demo on CarPlay.

## UI rules
- Colours only from `AutopalTokens.swift` (generated). No `Color(red:…)`, `UIColor(red:…)`, `Color(hex:)`, `.red`, `.green` for status.
- Every string in the String Catalog (English only for now). Numbers use `.monospacedDigit()`.
- Stale readings grey with "stale"; unsupported readings hidden, never 0.
- Dynamic Type to AX5; VoiceOver labels on every gauge.
