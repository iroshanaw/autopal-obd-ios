# Autopal OBD — iOS, iPhone Duo & CarPlay Architecture

Version 1.0 · 27 October 2026 · Companion to the Android architecture (same product, same protocol, same tests).
Confidence tags: **[Certain]** verified fact, **[Likely]** strong inference, **[Guessing]** must be tested.

---

## 1. Constraints that shape the iOS design

| # | Constraint | Confidence | Consequence |
|---|---|---|---|
| I1 | CarPlay lets only **navigation** apps draw custom UI (the map base view, and only a map). Every other category uses Apple's templates. | [Certain] CarPlay Developer Guide, Oct 2026 | No custom gauges through the CarPlay framework. |
| I2 | Driving-task apps must not refresh data "more than once every 10 seconds (for example, no realtime engine data)"; templates only; template depth 3 on iOS 26.4+. | [Certain] same guide | CarPlay screens show **health and alerts**, refreshed ≤ every 10 s. No live RPM on CarPlay. |
| I3 | An OBD health app may or may not be accepted as a driving-task app ("tasks must actually help with the drive"). | [Guessing] | Request the `com.apple.developer.carplay-driving-task` entitlement early with a clear description. Build so CarPlay still has a presence without it (I5). |
| I4 | Live Activities and WidgetKit widgets from iPhone apps appear on CarPlay (iOS 26+), with no CarPlay entitlement. | [Likely] Apple/press coverage; confirm in CarPlay Simulator | The **custom visual** on CarPlay is a Live Activity ("Drive monitor") and a widget, both drawn in SwiftUI by us. |
| I5 | iOS can't talk Bluetooth Classic SPP without Apple's MFi programme. | [Certain] | iOS transports: **BLE** and **Wi-Fi** only. The adapter's `ANDROID-VLINK` (Classic) persona is unusable on iPhone. |
| I6 | The test adapter's iOS persona `IOS-VLINK` uses UART service `0x18F0`, notify `0x2AF0`, write `0x2AF1`. A full `ATZ → 010C` round trip on iOS is **not yet confirmed**. | [Certain] / open | Phase 0 is that round trip, with evidence. |
| I7 | The clone adapter must be unplugged and replugged when switching between an Android and an iOS phone. | [Certain] observed | Connect screen tells the user; troubleshooting step 1. |
| I8 | iPhone Duo (foldable, 5.4" outer and 7.6" inner, iOS 27.1, Split View) is on sale from 23 Oct 2026. Apps built with the latest SDK are opted in to resizability. | [Certain] Apple newsroom; WWDC26 coverage | No fixed sizes or orientations; layouts by size class and container size; state survives fold/unfold. |
| I9 | Liquid Glass is the system design language since iOS 26 and continues in iOS 27. | [Certain] | Use standard SwiftUI navigation, tab bars and toolbars so the system applies Liquid Glass; custom glass only on floating controls. |
| I10 | iOS suspends background apps; BLE keeps running only with the `bluetooth-central` background mode and may be restored by state restoration. | [Certain] | Connection lives in a long-lived actor; CoreBluetooth state restoration on; Live Activity keeps the drive visible. |

> Correction to earlier notes: a "carplay-electric" entitlement is not listed in the October 2026 CarPlay Developer Guide. The real blockers are I1 and I2. The conclusion is unchanged: no custom gauges in CarPlay templates.

---

## 2. System context

```
 Vehicle ECUs ◄──CAN/K-Line──► Autopal Link (ELM327 clone)
                                   │ BLE (IOS-VLINK)  or  Wi-Fi TCP 192.168.0.10:35000
                                   ▼
 ┌──────────────────────────── iPhone / iPhone Duo ───────────────────────────────┐
 │  Autopal app                                                                  │
 │   ConnectionManager (actor) ─► ObdClient (AutopalCore) ─► VehicleStore (@Observable)
 │                                                             │                 │
 │      ┌──────────────────────┬───────────────────────┬───────┴────────┬────────┐│
 │      ▼                      ▼                       ▼                ▼        ││
 │  SwiftUI app UI      CarPlay scene (templates)  Live Activity   App Group     ││
 │  (phone, Duo, iPad)  health list, faults,       "Drive monitor" snapshot ──► Widgets
 │                      alerts ≤ 1 update / 10 s   (ActivityKit)             (WidgetKit)
 └───────────────────────────────────────────────────────────────────────────────┘
                 │ CarPlay                          │ Live Activity + widgets also shown in CarPlay
                 ▼                                  ▼
            Car head unit (Lenovo D1 on the test Toyota Wigo)
```

One connection, one store. Every surface reads from `VehicleStore` or, for out-of-process widgets, the App Group snapshot.

---

## 3. Project structure (Xcode)

```
Autopal.xcodeproj
├── AutopalCore/                  Swift package. Pure Swift + Foundation. No UIKit, SwiftUI, CoreBluetooth, Network.
│   ├── Sources/AutopalCore/
│   │   ├── Transport/            ObdTransport protocol, SimulatedElm327Transport
│   │   ├── Elm/                  ElmSession (actor), ElmReply, TrafficLog
│   │   ├── Obd/                  Hex, PidCatalog, SupportedPids, Dtc, Readiness, Vin, DtcDescriptions
│   │   ├── Poll/                 PollScheduler
│   │   ├── Alerts/               AlertEngine, AlertRules, HealthCheck
│   │   ├── Vehicle/              VehicleSnapshot, VehicleProfile, ConnectionPhase
│   │   └── ObdClient.swift
│   └── Tests/AutopalCoreTests/   Swift Testing; Resources/vectors/*.csv, Resources/elm-sessions/*.elm (shared with Android)
├── Autopal/                      iOS app target (iOS 26.0+)
│   ├── App/                      AutopalApp, AppModel (process-wide singletons), scenes
│   ├── Transport/                BleTransport, BleUartCandidates, WifiTransport
│   ├── Connection/               ConnectionManager (actor), BackgroundSupport
│   ├── Data/                     VehicleStore (@Observable, @MainActor), SettingsStore, SharedSnapshot (App Group)
│   ├── Theme/                    AutopalTokens.swift (GENERATED), AutopalTheme
│   ├── Components/               GaugeView, VerdictCard, StatusChip, CheckRow
│   ├── Screens/                  Home, HealthCheck, Faults, Adapter, EngineOff, TrafficLog, VehicleProfile
│   ├── CarPlay/                  CarPlaySceneDelegate, HealthTemplate, FaultsTemplate, CarPlayThrottle
│   ├── LiveActivity/             DriveActivityAttributes (shared with widget extension), DriveActivityController
│   └── Intents/                  App Intents: "Check my car", "Car health status"
└── AutopalWidgets/               Widget extension: VehicleHealthWidget, DriveActivity UI (Lock Screen, Dynamic Island, CarPlay)
```

**Rule:** if code can be written without Apple UI or radio frameworks, it goes in `AutopalCore`. `AutopalCore` is tested with `swift test` on any Mac and in CI, with no phone, adapter or car.

`GaugeView` (SwiftUI) is the one gauge drawing used by the app, widgets, the Live Activity, and, through `ImageRenderer`, the CarPlay row images.

---

## 4. Transports (app target)

### 4.1 Protocol (AutopalCore)
```swift
public protocol ObdTransport: Sendable {
    var label: String { get }
    var linkState: AsyncStream<LinkState> { get }
    var incoming: AsyncStream<Data> { get }   // fragmented, in order; subscribe before first write
    func connect() async throws
    func write(_ bytes: Data) async throws
    func close() async
}
```

### 4.2 BleTransport (CoreBluetooth)
- `CBCentralManager` with `CBCentralManagerOptionRestoreIdentifierKey` (state restoration) and `UIBackgroundModes = bluetooth-central`.
- Scan without a service filter (clones often don't advertise their UART service), show names matching `VLINK|OBD|ELM|Vgate` first.
- Connect → `discoverServices(nil)` → `discoverCharacteristics` → pick a pipe (§4.3) → `setNotifyValue(true)` → **wait for `didUpdateNotificationStateFor`** → only then write.
- Write type from the characteristic's properties (`.writeWithoutResponse` preferred if offered); chunk to `maximumWriteValueLength(for:)`.
- All delegate callbacks are bridged into the actor; one operation at a time.

### 4.3 BLE pipe candidates (`BleUartCandidates.swift`, the only file with BLE UUIDs)
| Order | Service | Notify | Write | Source |
|---|---|---|---|---|
| 1 | Pipe saved for this peripheral identifier | | | after a confirmed `ATZ` |
| 2 | `18F0` | `2AF0` | `2AF1` | Confirmed on `IOS-VLINK` [Certain] |
| 3 | `FFF0` | `FFF1` | `FFF2` | Common clones [Likely] |
| 4 | `FFE0` | `FFE1` | `FFE1` | HM-10 style [Likely] |
| 5 | `E7810A71-73AE-499D-8C15-FAA9AEF0C3F2` | `BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F` | same | Genuine Vgate [Guessing]; **ruled out** on this clone's iOS persona |
| 6 | Heuristic: any non-standard service with notify + write | | | |

A pipe is accepted only when `ATZ` returns text containing `ELM327`; it is then saved for that peripheral.

### 4.4 WifiTransport (Network.framework)
- `NWConnection` TCP to host/port (default `192.168.0.10:35000`), editable.
- Needs `NSLocalNetworkUsageDescription`; handle the Local Network permission prompt and denial.
- The phone joins the adapter's Wi-Fi in Settings; cellular data keeps working on iOS [Likely]. Optional `NEHotspotConfiguration` to join from the app.

### 4.5 SimulatedElm327Transport (AutopalCore)
Same scenarios as Android: `normal`, `ignitionOff`, `overheat`, `chargingFault`, `vacuumLeak`, `misfire`, `dropout`. Powers Demo mode, previews, CarPlay Simulator work and tests.

---

## 5. Protocol layer (AutopalCore) — identical behaviour to Android

The `.elm` fixtures and CSV vectors in `Tests/AutopalCoreTests/Resources` are byte-for-byte the Android ones. Both apps must pass the same fixtures.

### 5.1 ElmSession (`actor`)
1. One command in flight (actor isolation + a pending continuation).
2. A command ends at `>`; accumulate across fragments; drop NUL; accept `\r`, `\n`, `\r\n`.
3. Subscribe to `incoming` before the first write.
4. After a timeout, wait 300 ms and discard buffered bytes.
5. Timeouts: 2.5 s default, 5 s for `ATZ`, 15 s for the first OBD request after `ATSP0`.
6. Every TX/RX into `TrafficLog`; export format identical to Android:
   ```
   # autopal-traffic-log v1
   # adapter=ELM327 v1.5 transport=BLE device=IOS-VLINK app=0.1.0 exported=2026-10-27T15:58:00+05:30
   1729591080123 TX ATZ
   1729591080456 RX ATZ\r\r\rELM327 v1.5
   ```
- Time comes from an injected `any Clock<Duration>` (production `ContinuousClock`, tests a manual test clock). No `Date()` or `Task.sleep` without the injected clock in `AutopalCore`.

### 5.2 Reply classification
`ok(lines)`, `noData`, `unableToConnect`, `unknown` (`?`), `error(kind)` (CAN ERROR, BUS ERROR, BUS BUSY, BUFFER FULL, DATA ERROR, STOPPED, LV RESET), `timeout`. Echo, `SEARCHING...` and `BUS INIT: ...OK` stripped.

### 5.3 Init and discovery
`ATZ ATE0 ATL0 ATS0 ATH0 ATAT1 ATSP0 ATRV 0100 ATDPN [0120 0140 0160 while bit set] 0902 0101 03 07` → live.
Optional (tolerate `?`): `ATL0 ATS0 ATAT1 ATRV 0902`.
CAN only: append `1` to Mode 01 data PIDs in the poll tiers (`010C1`); never to range, `0101`, `03`, `07`, `0902`; on `?` disable for the session and resend.
Cache the detected protocol per VIN; next connect sends `ATSPn` directly (fast reconnect).

### 5.4 Polling tiers
| Tier | Interval | PIDs |
|---|---|---|
| FAST (fixed order) | every cycle | `010C`, `010D`, `0111`, `0104` |
| MEDIUM | 2 s | `0105`, `010F`, `015C`, `0142`, `0110`, `0106`, `0107` |
| SLOW | 30 s | `012F`, `010A`, `0146`, `ATRV` if `0142` unsupported |
| DIAG | 30 / 60 s | `0101` / `03` + `07` |
Only supported PIDs; 3× `NO DATA` drops a PID for the session.

### 5.5 Decoding (SAE J1979; A, B = first, second data byte)
| PID | Value | Formula | Unit |
|---|---|---|---|
| 04 | Engine load | A×100/255 | % |
| 05 / 0F / 46 / 5C | Coolant / intake / ambient / oil | A−40 | °C |
| 06 / 07 | Short / long fuel trim B1 | (A−128)×100/128 | % |
| 0A | Fuel pressure | A×3 | kPa |
| 0C | RPM | (256A+B)/4 | rpm |
| 0D | Speed | A | km/h |
| 10 | MAF | (256A+B)/100 | g/s |
| 11 / 2F | Throttle / fuel level | A×100/255 | % |
| 42 | Control module voltage | (256A+B)/1000 | V |
DTCs: 2 bytes each, top 2 bits P/C/B/U; CAN Mode 03 = `43 <count> …` possibly multi-frame; non-CAN = 3 codes per line, zero-padded. Readiness from `0101` (MIL bit 7, count bits 0–6, spark vs compression monitors). VIN from `0902` (CAN multi-frame or 5 non-CAN lines).

### 5.6 Alerts (provisional until the mechanical engineer's review)
Same rules, sustain times and hysteresis as Android (`alert_scenarios.csv` is the contract): coolant 112 / 118 °C and rising > 2 °C/min at speed; charging < 13.0 V or > 15.2 V when running; battery < 12.0 V engine off; over-rev > 92 % of profile redline; fuel 15 % / 7 %; long trim beyond ±10 %; total trim beyond ±25 %; new stored / pending DTC; misfire codes P0300–P0312 critical. Families show only the highest severity.

### 5.7 HealthCheck (new, both platforms)
A 60-second, parked, engine-idling procedure in `AutopalCore`:
1. Fault codes (03, 07, MIL) → severity per code.
2. Readiness (0101).
3. Battery and charging: voltage at idle 13.2–14.8 V [Likely; engineer to confirm].
4. Cooling: coolant at idle after warm-up within the normal band, not rising.
5. Fuel mixture: long trim within ±10 %, total within ±25 %.
6. Sensors live: every supported PID answered at least once.
Verdict = worst item: `healthy` / `serviceSoon` / `stopAndCheck`. Result is a value type, serialisable for "Share with mechanic". Thresholds live in `AlertRules`; fixture-driven tests required before UI work.

---

## 6. App layer

### 6.1 State
- `AppModel`: process-wide, created once in `AutopalApp`; owns `ConnectionManager`, `VehicleStore`, `SettingsStore`.
- `SetupModel` (first run): drives `ConnectionManager` through the same connect path as the Adapter screen (no second implementation); maps connection phases to setup steps; writes `setupDone` and the vehicle profile to the App Group. Bluetooth permission is triggered by creating the `CBCentralManager` at step 3, never at launch.
- `SettingsStore`: appearance (system/light/dark), units, alert switches, mute duration, remembered adapters; `UserDefaults(suiteName:)` in the App Group so widgets and the Live Activity read the same appearance and units. Units convert in the UI only; core stays metric.
- `Entitlements` (stage 2 hook): one protocol, `isPro(_ feature:) -> Bool`; stage 1 implementation returns `true` for everything. StoreKit 2 replaces it in stage 2, so no screen checks purchases directly.
- `VehicleStore` is `@Observable @MainActor`, fed by an `AsyncStream<VehicleSnapshot>` from `ObdClient`; UI, CarPlay and the Live Activity controller observe it.
- `SharedSnapshot` writes a small Codable summary (verdict, coolant, battery, fuel, alert, timestamp) to the App Group container for widgets; `WidgetCenter.shared.reloadTimelines` only when the verdict or an alert changes (widget budgets are limited [Likely]).

### 6.2 Phone, iPhone Duo and iPad layout
- SwiftUI, iOS 26.0 minimum (Liquid Glass, CarPlay widgets and Live Activities).
- **Compact width** (iPhone, iPhone Duo folded, either half of Duo Split View): `TabView` with four tabs (Home, Check, Faults, Settings; Adapter is pushed from Settings or Home); system Liquid Glass tab bar; `.tabBarMinimizeBehavior(.onScrollDown)`.
- **Regular width** (iPhone Duo unfolded full screen, iPad): `NavigationSplitView`: sidebar (Home, Check, Faults, Settings), content = live readings, detail = health and faults.
- No fixed frames for screens; gauges size with `containerRelativeFrame`/`ViewThatFits`. Fold/unfold and Split View resizing must keep scroll position and state (state lives in the store, not the views).
- Liquid Glass: standard bars and toolbars only; `.glassEffect()` only on custom floating controls (e.g., a floating "Run health check" button); content cards stay solid `surface`. Never put glass behind numbers.
- Dynamic Type up to AX5; VoiceOver labels identical to Android ("Coolant 114 degrees, warning, hot").

### 6.3 CarPlay (driving-task category, pending entitlement)
- `CPTemplateApplicationSceneDelegate` in its own scene configuration.
- Root `CPTabBarTemplate` with two tabs:
  - **Health:** `CPListTemplate`: verdict row first, then Coolant, Battery, Fuel, Engine. Row image = `GaugeView` rendered by `ImageRenderer`; detail text "114 °C · HOT". Titles constant.
  - **Faults:** `CPListTemplate`: one row per code, title = plain words, detail = code · severity.
- `CarPlayThrottle`: at most one template update every **10 s**, plus immediate update when an alert starts or ends (still ≥ 10 s apart). Unit-tested.
- Critical alerts: `CPAlertTemplate` with one action ("OK"); at most once per alert; never stacked.
- No account setup, settings or Demo mode on CarPlay. Depth ≤ 3.
- If the entitlement is refused: no CarPlay scene; CarPlay presence via §6.4 only.

### 6.4 Live Activity and widgets (CarPlay, Lock Screen, Dynamic Island)
- **Drive monitor Live Activity** starts when a live connection reaches `LIVE` and the user has enabled it; ends at `NO_ECU` or disconnect.
  - Content: verdict, coolant gauge, battery value, active alert. Updates from the app process while connected, at most every 10–15 s and on alert changes [Likely: ActivityKit budgets].
  - Presentations: Lock Screen, Dynamic Island (compact: coolant value; expanded: gauges), CarPlay (`.supplementalActivityFamilies([.small])` [Likely]).
- **Vehicle health widget** (`systemSmall`, plus `accessoryRectangular` for Lock Screen): verdict + last-known coolant/battery + "updated 5 min ago". Allowed in CarPlay widget stacks.
- Both draw with `GaugeView` and `AutopalTokens`; both show the age of the data.

### 6.5 App Intents
- "Check my car" → starts a health check if connected, else explains how to connect.
- "Car health" → speaks the last verdict and its age. Siri and Shortcuts; also usable from CarPlay via Siri [Likely].

### 6.6 Info.plist and capabilities
| Key / capability | Value |
|---|---|
| `NSBluetoothAlwaysUsageDescription` | "Autopal connects to your OBD adapter to read your car's health." |
| `UIBackgroundModes` | `bluetooth-central` |
| `NSLocalNetworkUsageDescription` | For Wi-Fi adapters |
| `NSSupportsLiveActivities` | `YES` |
| App Groups | `group.com.autopal.obd` (app + widgets) |
| CarPlay entitlement | `com.apple.developer.carplay-driving-task` (requested from Apple) |
| Scene manifest | Application scene + CarPlay template scene (`CPTemplateApplicationSceneSessionRoleApplication`) |
| Privacy manifest | `PrivacyInfo.xcprivacy` declaring required-reason APIs used (e.g., UserDefaults) |

---

## 7. Reliability (iOS-specific additions to the Android error matrix)

| Situation | Response |
|---|---|
| App suspended while driving | BLE background mode keeps receiving; Live Activity keeps the latest values visible; on restoration, re-run init from `ATZ` |
| Bluetooth permission denied or off | Adapter screen explains and links to Settings |
| Local Network permission denied (Wi-Fi adapter) | Explain and link to Settings; offer BLE |
| Adapter silent after switching phones | "Unplug the adapter for 5 seconds and plug it back in" (I7) |
| CarPlay connected but phone app never opened | CarPlay scene starts `ConnectionManager`; if no saved adapter, show "Open Autopal on your iPhone to set up" |
| Fold/unfold or Split View resize | No reconnect, no state loss; layout only |

Mode 04 (clear codes) is never sent. Data stays on the device.

---

## 8. Decisions

| ID | Decision | Rejected | Reason |
|---|---|---|---|
| D-i1 | Pure-Swift `AutopalCore` with the shared fixtures | Kotlin Multiplatform shared core | Xcode agents and Swift Testing work best with native Swift; fixtures keep both platforms honest |
| D-i2 | BLE + Wi-Fi only | MFi Classic | MFi needs hardware certification [Certain] |
| D-i3 | CarPlay = templates for health/faults + Live Activity/widget for visuals | Navigation category with map base view | Base view is map-only (I1) and an OBD app isn't a navigation app |
| D-i4 | iOS 26 minimum | iOS 17 | Liquid Glass, CarPlay widgets/Live Activities; Apple's adoption curve [Likely] |
| D-i5 | Size classes + container-relative layout | Device-specific layouts | iPhone Duo and resizable apps (I8) |
| D-i6 | Settings tab; Adapter inside Settings; one-tap Connect on Home | Adapter tab, 5 tabs | Owner decision 28 Oct; Settings needed for appearance/units now and the Plan section in stage 2 |
| D-i7 | English only | English + Sinhala + Tamil | Owner decision 28 Oct; several countries, English-speaking market |
| D-i8 | Payments in stage 2 behind `Entitlements` | Paywall in v1 | Owner decision; stage 1 ships everything free |
| D-i9 | Guided first-run setup ending connected; skippable to Demo; system push transitions | Feature slides; Android-style shared-axis | Same flow as Android (D11); iOS motion conventions |

## 9. Phases and exit evidence

| Phase | Deliverable | Exit evidence (in `docs/evidence/`) |
|---|---|---|
| 0 | iOS BLE round trip on `IOS-VLINK` | Log: `ATZ` → `ELM327 v…` and `010C` → `41 0C …` with ignition on |
| 1 | `AutopalCore` + all fixtures green | `swift test` output: all vector and `.elm` tests pass |
| 2 | Phone UI in Demo mode, both themes, compact and regular | Screenshots vs `docs/design/screens/ios-*.png` |
| 3 | Real data on the Wigo | Exported traffic log; RPM/speed/coolant within ±2 % of the dashboard |
| 4 | CarPlay entitlement requested | Copy of the request; Apple's reply |
| 5 | CarPlay templates in CarPlay Simulator (small, wide, portrait sizes) | Recordings |
| 6 | Live Activity + widget on Lock Screen, Dynamic Island and CarPlay | Screenshots / recordings |
| 7 | iPhone Duo: folded, unfolded, Split View | Simulator recordings (device when available) |
| 8 | TestFlight build | Build number, tester feedback |
