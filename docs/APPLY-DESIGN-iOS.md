# Building Autopal for iPhone, iPhone Duo and CarPlay in Xcode (28 Oct 2026)

Same product as the Android app: same screens, flows, words, alerts, setup and settings. Different platform rules:
SwiftUI with system Liquid Glass bars, iPhone Duo layouts by width, BLE/Wi-Fi only, CarPlay templates (≤ 1 update / 10 s),
Live Activity and widgets for visuals on CarPlay. Unlike Android, the iOS app does not exist yet, so the design goes in
while each screen is built (no separate "apply design" pass) and motion is built with the components.

**Design (private until you share):**
- iOS canvas *Autopal OBD — iOS, iPhone Duo & CarPlay Screens*: https://claude.ai/artifact/1EVLifiE2rqddFeAGhc92R (pages iPhone, Setup (first run), iPhone Duo, CarPlay, Live Activity & widgets)
- Autopal Design System: https://claude.ai/artifact/DNLaTgsZUDWXboXPhd6fWL (same `tokens.json` as Android)

The Xcode agent can't open these links; it reads the repo and what you attach.

---

## Part A — set up (you)

1. Follow `docs/SETUP-Xcode.md`: Xcode 26.3 or later with the Claude Agent, project + `AutopalCore` package, App Group, capabilities, Apple's agent skills export, permissions. **Request the CarPlay driving-task entitlement now** (text in SETUP-Xcode.md); it takes weeks.
2. Export the iOS boards (select board → Share › Export › PNG, 2× if offered) into `docs/design/screens/` with these names (same style as your Android files):

| Page | File names (add `.png`) |
|---|---|
| iPhone (18) | `ios-Home-dark` (board "Home · healthy · dark"), `ios-Home-Warning-dark`, `ios-Home-Disconnected-dark`, `ios-HealthCheck-dark`, `ios-HealthCheck-Running-dark`, `ios-Faults-dark`, `ios-Settings-dark`, `ios-Adapter-dark`, `ios-NoEngine-dark`, `ios-TrafficLog-dark`, `ios-Home-light`, `ios-Home-Warning-light`, `ios-HealthCheck-light`, `ios-Faults-light`, `ios-Settings-light`, `ios-Adapter-light`, `ios-NoEngine-light`, `ios-TrafficLog-light` |
| Setup (first run) (12) | `ios-setup-Welcome-dark`, `ios-setup-Plug-dark`, `ios-setup-Permission-dark`, `ios-setup-Connect-dark`, `ios-setup-Car-dark`, `ios-setup-Error-NoEcu-dark`, `ios-setup-Error-Bluetooth-dark`, `ios-setup-Error-NoAdapter-dark`, `ios-setup-Welcome-light`, `ios-setup-Plug-light`, `ios-setup-Connect-light`, `ios-setup-Car-light` |
| iPhone Duo (4) | `ios-duo-Folded-dark`, `ios-duo-Unfolded-dark`, `ios-duo-SplitView-dark`, `ios-duo-Landscape-dark` |
| CarPlay (5) | `ios-carplay-Health-Night`, `ios-carplay-Faults-Night`, `ios-carplay-Alert-Night`, `ios-carplay-Dashboard-Night`, `ios-carplay-Widgets-Night` |
| Live Activity & widgets (3) | `ios-glance-LockScreen-dark`, `ios-glance-DynamicIsland-dark`, `ios-glance-Widgets` (shows both themes) |

   42 files. If the export used other names, run `python3 scripts/rename-ios-exports.py` (dry run), then add `--apply`. Then `python3 scripts/check-design-exports.py` must say 42 of 42. Optional: `ios-Adapter-Wifi-dark`, `ios-Adapter-Demo-dark`.
3. `python3 scripts/tokens_to_swift.py`, then `scripts/check-guardrails.sh`. Commit before any code.
4. In Xcode: Intelligence › Claude Agent. New conversation per prompt; use `/plan` for anything over one file. Attach the listed PNGs.

**Every prompt:** read the plan before approving. Reject plans that change the shared fixtures, add packages, use Classic Bluetooth/External Accessory, or put settings, Demo or setup on CarPlay.

---

## Part B — core (no UI; same behaviour as Android's `core`)
Run each in a new conversation:
```
Use the autopal-build-step skill. Do step <N> only, test-first, then update docs/STATUS-iOS.md and stop.
```
N = 0 (scaffold), 1, 2, 3, 4, 5. `swift test --package-path AutopalCore` must be green after each. The fixtures are the Android ones, so a green core means both apps decode identically.

Then step 6 (app model + Demo) and step 7 (BLE): after step 7 **you** run T-iBLE-1/2 on `IOS-VLINK` with the car (TESTING-iOS §2) and save the traffic log in `docs/evidence/`. Don't build screens on an unproven connection.

---

## Part C — screens (build-order step 8, split into tasks)

### I1 · Theme, motion tokens, settings storage
Attach: `ios-Home-dark.png`, `ios-Home-light.png`, `ios-Settings-dark.png`
```
Use the autopal-apply-design skill, section 1. Plan first.
AutopalTheme from the generated AutopalTokens.swift (dynamic light/dark), Archivo for verdict and numbers with monospaced digits
(system font if not bundled; say which), app tint = primary. AutopalMotion.swift with fast/medium/slow/alert from UI_DESIGN-iOS §4a.
SettingsStore in the App Group: appearance (system/light/dark, default system, applied with preferredColorScheme), units
(°C/°F, km/mi, kPa/psi, default from region), driving alerts, alert sound, mute minutes (10), setupDone.
Entitlements protocol that returns true for everything (stage 2 hook). UnitFormatter (core stays metric) with tests.
CarPlay must not use the appearance setting. Verify and report.
```

### I2 · Components with their motion
Attach: `ios-Home-dark.png`, `ios-Home-Warning-dark.png`, `ios-HealthCheck-dark.png`, `ios-Settings-dark.png`
```
Use the autopal-apply-design skill, section 2, and UI_DESIGN-iOS §4 and §4a. Components only, each with #Previews
(light + dark, Dynamic Type L and AX3): GaugeView (animatable arc, number changes instantly, status colour animation,
single ring pulse on entering warning/critical), VerdictCard (healthy / service soon / stop and check / alert / not connected,
with the §4a transition), StatusChip, CheckRow (badge transition), LiveDot (breathing only while live), grouped list rows.
Honour Reduce Motion. No screens yet. Verify and report.
```

### I3 · Navigation shell
Attach: `ios-Home-dark.png`, `ios-Settings-dark.png`, `ios-Adapter-dark.png`, `ios-duo-Landscape-dark.png`
```
Use the autopal-apply-design skill, section 3. TabView with Home, Check, Faults, Settings (system Liquid Glass tab bar,
tabBarMinimizeBehavior on scroll) for compact width; NavigationSplitView with the same four for regular width.
Adapter is pushed from Settings › Adapter and from the Home "Not connected" card. Placeholder content is fine. Verify.
```

### I4 · Home (healthy, warning, not connected) + Engine off
Attach: `ios-Home-*.png`, `ios-NoEngine-*.png`
```
Use the autopal-apply-design skill for Home and Engine off (UI_DESIGN-iOS §5). States: healthy, coolant warning
(alert card with §4a transition and haptic, Mute 10 min), not connected (Connect → Adapter, Try demo, "—"/stale gauges),
engine off (replaces Home while the adapter answers but the car doesn't). Values through UnitFormatter.
#Preview per state × theme from fixed VehicleSnapshots with the PNG values. Verify and report differences.
```

### I5 · Health check (running + result)
Attach: `ios-HealthCheck-*.png`
```
Use the autopal-apply-design skill for Health check: running (ring, rows done/running/waiting, glass Cancel) and result
(verdict, six rows, Share with mechanic prominent + Details glass). Use AutopalCore HealthCheck; don't change it. Previews. Verify.
```

### I6 · Faults
Attach: `ios-Faults-*.png`
```
Use the autopal-apply-design skill for Faults. No clear-codes action anywhere (rule 3). Previews in both themes. Verify.
```

### I7 · Settings, Adapter, Traffic log
Attach: `ios-Settings-*.png`, `ios-Adapter-*.png`, `ios-TrafficLog-*.png`
```
Use the autopal-apply-design skill for Settings (all sections in UI_DESIGN-iOS §5 and §8a; critical alerts can be muted, never
switched off; Delete all data asks first), Adapter (Bluetooth / Wi-Fi / Demo segments, replug tip, Local Network note) and
Traffic log (share sheet export). No plans, prices or "Pro" anywhere. Previews. Verify.
```

### I8 · First-run setup
Attach: all `ios-setup-*.png`
```
Use the autopal-apply-design skill for the Setup flow in UI_DESIGN-iOS §5a: fullScreenCover with a NavigationStack, system push
transitions, Welcome → Plug in → Permission → Connecting → Connected, errors NO_ECU / Bluetooth off or denied / no adapter in 30 s.
SetupModel must reuse ConnectionManager and the Adapter screen's connect path. Bluetooth alert only at step 3 (create the
CBCentralManager there), notification permission only at step 4. Skip / Try demo dismiss to Home; Home "Not connected" resumes at
step 2; shown only until setupDone. Previews for every board in both themes. Verify; then I run TESTING-iOS UI-14…UI-17.
```

### I9 · iPhone Duo and iPad
Attach: `ios-duo-*.png`
```
Use the autopal-apply-design skill for container widths in UI_DESIGN-iOS §6 (< 300, 300–499, 500–839, ≥ 840 pt).
No fixed sizes or orientation locks. Fold/unfold keeps state and connection. Check in the resizable simulator and report.
```

---

## Part D — glanceable and car surfaces

### I10 · Live Activity and widgets (build step 10)
Attach: `ios-glance-*.png`, `ios-carplay-Dashboard-Night.png`, `ios-carplay-Widgets-Night.png`
```
Use the autopal-carplay skill (Live Activity and widget parts) and UI_DESIGN-iOS §8. Drive monitor Live Activity
(Lock Screen, Dynamic Island compact/minimal/expanded, CarPlay Dashboard via supplemental small family) and the vehicle
health widget (systemSmall, accessoryRectangular) reading the App Group snapshot. Always show data age; system animations only.
Verify in the simulator and report.
```

### I11 · CarPlay (build step 11)
Attach: `ios-carplay-Health-Night.png`, `ios-carplay-Faults-Night.png`, `ios-carplay-Alert-Night.png`
```
Use the autopal-carplay skill. CPTabBarTemplate with Health and Faults CPListTemplates, CPAlertTemplate for critical alerts,
CarPlayThrottle (≤ 1 update / 10 s, constant titles, depth ≤ 3). No settings, Demo or setup on CarPlay; if setup isn't done show
"Open Autopal on your iPhone to set up". Never CPMapTemplate. Test in CarPlay Simulator (Device Hub) and report CP-1…CP-9.
```

### I12 · Review (new conversation)
```
Use the autopal-review skill on everything since the last review. Compare previews with docs/design/screens/ios-*.png and list
every difference in order, hierarchy, colour role, text, spacing > 4 pt or motion vs UI_DESIGN-iOS §4a.
```

---

## Part E — done means
- `swift test`, `scripts/check-guardrails.sh` and `python3 scripts/check-design-exports.py` pass.
- Every exported state has a `#Preview` in both themes; TESTING-iOS UI-1…UI-18 checked in the simulator.
- On hardware: T-iBLE-1/2 and UI-14 on the Wigo with `IOS-VLINK`; CP-10 on the Lenovo D1 once the entitlement arrives.
- `docs/STATUS-iOS.md` uses "compiles" / "passes fixtures" / "works on …" with evidence files only.

**Parity check with Android** (same app, two platforms):
| Area | Android | iOS |
|---|---|---|
| Tabs | Home · Check · Faults · Settings | same |
| Setup | 4 steps, errors NO_ECU / not paired / no adapter | 4 steps, errors NO_ECU / Bluetooth off or denied / no adapter |
| Transports | Classic SPP, BLE, Wi-Fi, Demo | BLE, Wi-Fi, Demo |
| Car screen | Android Auto: custom gauges (showcase) or templates (store) | CarPlay: templates + Live Activity/widget; no live engine data |
| Motion | Compose, §3a | SwiftUI, §4a (system push in setup) |
| Settings, units, alerts, copy, thresholds | shared | shared |
