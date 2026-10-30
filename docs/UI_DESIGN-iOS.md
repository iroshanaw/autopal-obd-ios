# Autopal OBD (iOS) — UI Design Spec v1.2 (28 Oct 2026)

**v1.2 (28 Oct, later):** parity with the Android app: first-run Setup (§5a), Health check running, Engine off and Traffic log boards, Motion (§4a); export names `ios-<Screen>[-<State>]-<theme>.png`.
**v1.1 (28 Oct):** Settings replaces the Adapter tab; Adapter is pushed from Settings or from the Home "Not connected" card; Appearance setting (System / Light / Dark); English only; Pro/payments are stage 2.

**Source of truth:** the *Autopal Design System* and the *Autopal OBD — iOS, iPhone Duo & CarPlay Screens* canvas in Claude Design.
This file, `docs/design/tokens.json` and the PNG exports in `docs/design/screens/` (named `ios-<Screen>[-<State>]-<theme>.png`, theme `dark`/`light`; CarPlay `-Night`; full list in `docs/APPLY-DESIGN-iOS.md`) carry that design into Xcode.
**Design-first rule:** change the design, re-export, regenerate tokens, then implement. Readings are fixture values; severities and advice are **provisional** until the mechanical engineer's review.

## 1. Principles
1. **Verdict first:** Healthy · Service soon · Stop and check, in plain words.
2. **Colour is never the only signal:** every status has a word and an icon.
3. **Unknown ≠ zero; stale is visible:** unsupported readings hidden; stale readings `inkStale` + "stale · <age>".
4. **Native iOS, Autopal brand:** standard SwiftUI structure (system Liquid Glass bars), brand colour and numbers inside the content.
5. **Any size:** iPhone, iPhone Duo folded/unfolded/Split View, iPad. Layout by container width, never by device.

## 2. Tokens and type
- `python3 scripts/tokens_to_swift.py` → `Autopal/Theme/AutopalTokens.swift` (dynamic light/dark `Color`s, spacing, radii). App + widget targets.
- App tint `AutopalTokens.primary`. Status colours from tokens only; never `.red`/`.green`.
- **Type:** system font (SF Pro) for all UI text and navigation (Dynamic Type styles). **Archivo** for the verdict word and all numbers, with `.monospacedDigit()` (bundle Archivo, open question in STATUS; fallback = SF Pro Rounded is **not** used: fall back to SF Pro with monospaced digits).

| Use | SwiftUI style | Notes |
|---|---|---|
| Screen title | `.largeTitle` bold (system large title) | "Toyota Wigo", "Faults" |
| Verdict word | Archivo 34 bold, scales with Dynamic Type (`relativeTo: .largeTitle`) | |
| Gauge value | Archivo 30 bold mono digits (`relativeTo: .title`) | 72 on large layouts |
| Row title / body | `.body` / `.headline` | |
| Caption, units | `.caption` / `.footnote` | never below 12 pt |

Spacing 4/8/12/16/24/32; radii 12 (controls), 22 (cards; iOS uses 22 instead of Android's 20 to sit with system corner curves), 28 (hero cards), capsule (chips, buttons). Use `.containerShape`/continuous corners.

## 3. Liquid Glass usage
| Element | Glass? | How |
|---|---|---|
| Tab bar (compact) | Yes, system | `TabView` with `Tab` items; `.tabBarMinimizeBehavior(.onScrollDown)` |
| Sidebar (regular) | Yes, system | `NavigationSplitView` |
| Toolbar buttons (profile, back, share) | Yes, system | `.toolbar` items; circular glass buttons are drawn by iOS |
| Segmented control on Adapter | Yes | system `Picker(.segmented)` |
| Floating bottom actions on Health check | One glass, one prominent | `.buttonStyle(.glassProminent)` for "Share with mechanic", `.glass` for "Details" [Likely API names in iOS 26] |
| Verdict card, gauge tiles, lists | **No** | solid `surface` / containers so numbers stay legible |
| Live Activity on Lock Screen | System material | don't fake glass inside the activity |
Reduce Transparency and Increase Contrast must leave every screen readable.

## 4. Components (match the canvas)
| Component | Spec |
|---|---|
| `GaugeView` | 270° arc from 135°, round caps; phone tile 120×104 pt at default size, ×1.45 unfolded Duo, ×0.85 in narrow Split View; track `gaugeTrack`; rpm `redlineBand` from 92 % of redline; value arc `gaugeNormal/Warning/Critical` or `inkStale`; value Archivo mono, unit caption. Warning/critical tiles get a 2 pt inner stroke + caption word. Accessibility: one combined element "Coolant 114 degrees, warning, hot". Used by app, widgets, Live Activity and (via `ImageRenderer`) CarPlay rows. |
| `VerdictCard` | 28 pt radius, 18 pt padding. Healthy `primaryContainer`; Service soon `warningContainer` + `warning` icon; Stop and check `criticalContainer` + `critical` icon. Home shows the active alert here ("Coolant hot · 114 °C", "What this means", "Mute 10 min"). |
| `StatusChip` | capsule 32 pt; neutral `surface`, warning `warningContainer`. |
| `CheckRow` | 58 pt min; 30 pt badge (check / "!"), title `.headline`, detail `.footnote` (`warning` when attention), value mono. |
| Grouped lists | `surface` cards, 22 pt radius, 0.5 pt `outline` separators (inset-grouped look). |

## 4a. Motion (same intent as Android §3a, done the iOS way)
Motion shows **what changed**; nothing decorative, nothing that keeps moving. Tokens in `Autopal/Theme/AutopalMotion.swift`; no inline durations.

| Token | SwiftUI | Use |
|---|---|---|
| `fast` | `.easeOut(duration: 0.15)` | Checkmarks, colour changes |
| `medium` | `.smooth(duration: 0.25)` | Gauge arcs, card state changes, lists |
| `slow` | `.smooth(duration: 0.4)` | Progress bar, larger layout changes |
| `alert` | `.spring(response: 0.35, dampingFraction: 0.8)` | Alert card entering |

| Element | Behaviour |
|---|---|
| Gauge arc | Arc `Shape` with `animatableData` = fraction; `.animation(AutopalMotion.medium, value: fraction)`. The **number changes instantly**: no `.contentTransition(.numericText())`, no rolling digits. |
| Status colour (normal → warning → critical / stale) | `.animation(AutopalMotion.fast, value: status)` on arc, ring, caption. Entering warning/critical: **one** ring pulse (`.keyframeAnimator` or `.phaseAnimator` with a trigger, scale 1.00 → 1.03 → 1.00, 0.3 s). Never repeats. |
| Alert card on Home | `.transition(.move(edge: .top).combined(with: .opacity))` with `alert`; critical also `.sensoryFeedback(.warning, trigger: alertID)`. |
| VerdictCard | Content swaps with `.transition(.opacity)` inside `withAnimation(medium)`; height animates. |
| Live dot | Opacity 1.0 ↔ 0.45, 1.6 s, repeating, **only while live**; static when stale/disconnected. The only looping animation. |
| Health check | Ring progress animates with `medium`; each row badge appears with `.transition(.scale(scale: 0.6).combined(with: .opacity))` (`fast`). |
| Setup | Steps are pushes inside a `NavigationStack` in a `.fullScreenCover`: use the **system push animation** (iOS users expect it; don't copy Android's shared-axis). Progress bar fills with `slow`. Errors replace the progress list with `.transition(.opacity)`; no shake. |
| Lists | `List`/`ForEach` default insert/remove animations. |
| Navigation, tab bar, sheets, Liquid Glass | System animations only. |
| Theme change | Instant. |

**Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`): replace moves/scales with crossfades, skip the ring pulse, stop the live dot. **CarPlay, Live Activity, widgets:** no custom animation (the system animates Live Activity updates); CarPlay templates update at most every 10 s.

## 5. Screens (canvas page "iPhone")
| Screen | Content | Designed states |
|---|---|---|
| Home | Status line (live · transport · adapter), large title, glass vehicle button (opens vehicle details), VerdictCard + "Run health check", 2×2 gauges (Engine, Coolant, Battery, Fuel), "More readings" | healthy dark/light; coolant warning dark/light; **not connected** (Home-Disconnected): card "Not connected" + **Connect** (pushes Adapter) + "Try demo", gauges "—" or stale values with age |
| Health check | Glass back + share, large title, verdict, 6 check rows, bottom "Share with mechanic" (prominent) + "Details" (glass) | result dark/light; **running** dark (progress ring 45 %, rows done / running / waiting, glass Cancel) |
| Faults | Large title, chips (check-engine light, counts), list with plain title, code, severity tag, readiness grid, never-clears note | dark/light |
| Settings (tab) | Large title; vehicle card (name, year, engine, VIN read) › vehicle details; **Connection**: Adapter › (pushes the Adapter screen), Demo mode ›; **Appearance**: segmented System / Light / Dark; **Units**: temperature, distance and speed, pressure; **Alerts**: Driving alerts switch, Alert sound switch, Mute for ›; **Data**: Traffic log, Share last health check, Delete all data (critical colour, confirms first); **About**: version, privacy policy, terms, "does not replace a mechanic" | dark/light; Appearance and switches interactive |
| Adapter (pushed from Settings or Home) | Glass back button "Settings"; connected card (adapter, version, BLE, protocol, "keeps reading when locked"), segmented Bluetooth / Wi-Fi / Demo; BLE list with **replug tip**; Wi-Fi steps + address/port + Local Network note; Demo scenarios | dark/light, interactive |
| Engine off (NO_ECU) | Replaces Home while the adapter answers but the car doesn't: "Turn the ignition on", retry countdown, battery at rest (ATRV), expandable troubleshooting, battery-drain note; tab bar stays | dark/light |
| Traffic log (Settings › Data) | Glass back "Settings" + glass share; large title; chips (ELM version, BLE · adapter, protocol); monospaced log (TX `primary`, RX `ink`, INFO `warning`); privacy note | dark/light |

## 5a. Setup (first run) — canvas page "Setup (first run)"
Same steps, words and rules as Android (UI_DESIGN.md §4a). Shown once (flag in the App Group), as a `.fullScreenCover` with its own `NavigationStack`. Success metric: time from install to first live reading.

| Step | Board | iOS specifics |
|---|---|---|
| 1 Welcome | `ios-setup-Welcome` | No step indicator. **Set up adapter** (prominent capsule), **Try demo first** (glass). |
| 2 Plug in | `ios-setup-Plug` | Glass back · "Step 1 of 3" · glass **Skip**; under-dash drawing; three numbered steps; "Using a Wi-Fi adapter?" → Adapter screen, Wi-Fi segment. |
| 3a Permission | `ios-setup-Permission` | Rationale, then **Continue** creates the `CBCentralManager`, which shows the iOS Bluetooth alert. Only ask once; after denial show the Bluetooth error. Wi-Fi path: the Local Network alert appears on first connect. |
| 3b Connecting | `ios-setup-Connect` | BLE adapters found (tags CONNECTING / FOUND), progress rows: Adapter found ✓ → Talking to the car → Reading your car; opens step 4 by itself. |
| 3c Errors | `ios-setup-Error-NoEcu`, `-Bluetooth`, `-NoAdapter` | **NO_ECU** as Android. **Bluetooth off / not allowed** (replaces Android's Classic-pairing error; iOS has no Classic): Open Settings (`UIApplication.openSettingsURLString`), Try again. **No adapter in 30 s:** light on, ignition on, **replug if used with an Android phone**; Scan again / Use Wi-Fi adapter. Every error offers **Try demo**. |
| 4 Connected | `ios-setup-Car` | Car name, VIN-read tick, Fuel segmented, units line, "Warn me" **Allow** → `UNUserNotificationCenter.requestAuthorization` (consider `.timeSensitive` alerts for overheat: needs the Time Sensitive capability [Likely]). **Run first health check** / Go to Home. |

Rules: Skip/Try demo dismiss the cover to Home; Home "Not connected" card resumes at step 2; CarPlay never shows setup ("Open Autopal on your iPhone to set up"); no account, paywall or review prompt in setup.

## 6. iPhone Duo and iPad (canvas page "iPhone Duo")
Point sizes are **estimates** (5.4"/7.6", same aspect ratio) until Device Hub ships the device; layout uses container width, so exact sizes don't matter.

| Container width | Layout | Board |
|---|---|---|
| < 300 pt (narrow Split View) | One column, gauges 2×2 at 0.85×, title 28 pt | Duo-SplitView |
| 300–499 pt (folded, iPhone) | Standard compact layout, tab bar | Duo-Folded |
| 500–839 pt (unfolded portrait) | Compact structure, gauges 1.45×, more rows visible | Duo-Unfolded |
| ≥ 840 pt (unfolded landscape, iPad) | `NavigationSplitView`: sidebar (Home, Health check, Faults, Settings), readings pane, health pane | Duo-Landscape |
Folding/unfolding: same scene, no reconnect, scroll position kept; Split View: both halves fully usable.

## 7. CarPlay (canvas page "CarPlay")
Templates are drawn by iOS; the boards approximate them. Driving-task rules: ≤ 1 update / 10 s, no real-time engine data, depth ≤ 3, no settings.

| Board | Template | Content |
|---|---|---|
| Health | `CPTabBarTemplate` › `CPListTemplate` | Rows: Health (verdict), Coolant, Battery, Fuel, Faults. Titles constant; detail "114 °C · HOT"; row image = `GaugeView` via `ImageRenderer` (or SF Symbol-like icon for verdict/faults) |
| Faults | `CPListTemplate` | Plain title; detail "P0420 · Service soon" |
| Alert | `CPAlertTemplate` | "Coolant hot · 114 °C", "Ease off and switch the A/C off", one action "OK" |
| Dashboard | Live Activity (system places it) | Drive monitor: app mark, verdict, coolant gauge, battery, "updated 8 s ago" |
| Widgets | WidgetKit `systemSmall` in CarPlay | Vehicle health widget: verdict, coolant, battery, age |
System areas on these boards (dock, navigation app, now playing, other widgets) are labelled placeholders; we don't draw them.

## 8. Live Activity and widgets (canvas page "Live Activity & widgets")
| Surface | Content |
|---|---|
| Lock Screen Live Activity | App mark + vehicle, age; coolant gauge (warning colours when hot); headline ("Coolant hot"), advice, battery and fuel line |
| Dynamic Island compact | Leading: mini gauge; trailing: "114° HOT" (or "Healthy") |
| Dynamic Island minimal | Mini gauge in status colour |
| Dynamic Island expanded | Gauge + headline + advice + battery/fuel |
| Lock Screen widget (`accessoryRectangular`) | "Wigo healthy · 88° · 14.1 V" |
| Home Screen / CarPlay widget (`systemSmall`) | Vehicle, verdict, mini gauge, values, "5 min ago"; light and dark |
Always show data age; never imply live data in widgets.

## 8a. Navigation and Settings rules
- Tabs (compact): **Home · Check · Faults · Settings**. Sidebar (regular): same four.
- Reconnecting is never more than one tap from Home: the "Not connected" card's **Connect** opens the Adapter screen directly.
- **Appearance:** System (default) / Light / Dark, stored in the App Group so widgets and the Live Activity follow it; apply with `.preferredColorScheme(nil / .light / .dark)`. CarPlay ignores it and follows the car.
- **Units:** temperature °C/°F, distance km/mi (speed follows), pressure kPa/psi. Conversion happens only in the UI layer; `AutopalCore` and fixtures stay metric. Default from the iPhone's region.
- **Alerts:** critical alerts can be muted (10 min default) but not switched off.
- **Stage 2 (Pro):** a "Plan" section goes at the top of Settings (current plan, Upgrade, Restore purchases, Manage subscription) using StoreKit. Never on CarPlay, the Live Activity or widgets. Not designed yet; do not build it in stage 1.

## 9. Copy rules
Same as Android: plain words before codes; advisory language ("ease off", "stop when safe", never "safe to drive"); units always; strings in the String Catalog; **English only** at launch (other languages are not planned, but keep every string in the catalog so adding one later needs no code change).

## 10. Handoff checklist
1. Export each board as PNG into `docs/design/screens/` with the names in `docs/APPLY-DESIGN-iOS.md`; `python3 scripts/check-design-exports.py` must report all present.
2. `python3 scripts/tokens_to_swift.py`.
3. Agent: `autopal-apply-design` with the PNGs attached; `#Preview` per state × theme × width.
4. TESTING-iOS UI-1…UI-18 and CP-1…CP-10.
