# Autopal OBD (iOS) — Test Strategy

Same philosophy as Android: capture adapter and car behaviour as byte-exact fixtures, test the core anywhere, use hardware only to confirm.
The fixtures in `AutopalCore/Tests/AutopalCoreTests/Resources/` are **identical to Android's**. If one app passes a fixture and the other fails, one of them has a bug.

```
   L6  Vehicle matrix + CarPlay head unit          §7
   L5  CarPlay Simulator, Live Activity, widgets   §5
   L4  iPhone / iPhone Duo / iPad UI               §6
   L3  Real adapter on iPhone (BLE, Wi-Fi)         §4
   L2  Fixture replays (ObdClient end to end)      §3.3
   L1  Swift Testing unit tests (AutopalCore)      §3.1–3.2
```

## 1. Ground rules
1. `swift test --package-path AutopalCore` passes before every commit (pre-commit hook + CI). No device needed.
2. Hardware bug → fixture first (`autopal-elm-fixture`), and copy the fixture to the Android repo.
3. Status claims need evidence in `docs/evidence/`.
4. Existing fixture lines are never changed; the guardrail blocks it.

## 2. Test assets
| Path (under `AutopalCore/Tests/AutopalCoreTests/Resources/`) | Contents |
|---|---|
| `vectors/pid_vectors.csv` | Mode 01 decoding incl. multi-ECU, spaces, headers-on, truncated |
| `vectors/dtc_vectors.csv` | DTC decoding, CAN vs non-CAN, multi-frame, de-duplication |
| `vectors/readiness_vectors.csv` | MIL, counts, spark vs compression monitors |
| `vectors/vin_vectors.csv` | VIN over CAN and non-CAN |
| `vectors/alert_scenarios.csv` | Time series → expected alerts (sustain, hysteresis, families) |
| `elm-sessions/*.elm` | Scripted adapter sessions; format in that folder's README |

## 3. Core tests (Swift Testing)

### 3.1 Data-driven
| Suite | Source | Asserts |
|---|---|---|
| `PidDecodeTests` | pid_vectors.csv | value within tolerance; empty expected → `nil` |
| `DtcDecodeTests` | dtc_vectors.csv | exact code set, order-insensitive |
| `ReadinessTests` | readiness_vectors.csv | MIL, count, engine type, available, incomplete |
| `VinTests` | vin_vectors.csv | VIN or `nil` |
| `ElmReplyTests` | inline table | every reply class; echo/SEARCHING/BUS INIT OK stripped |
| `SupportedPidsTests` | inline | `BE3FA813` → exact PID set; multi-ECU OR |
Use `@Test(arguments:)` over parsed rows so each row reports separately. Load resources with `Bundle.module`.

### 3.2 Behaviour
| Suite | Cases |
|---|---|
| `ElmSessionTests` | 1-byte fragments; prompt mid-chunk; concurrent sends serialised; timeout + drain; NUL ignored; every TX/RX logged |
| `PollSchedulerTests` | tier timing at 0 / 1 / 2 / 30 / 60 s; unsupported never scheduled; ATRV only without 0142; drop after 3× NO DATA |
| `AlertEngineTests` | every row of alert_scenarios.csv (raised + active) |
| `HealthCheckTests` | verdict = worst item; each of the 6 checks from fixture snapshots; serialisation round trip |
| `CommandFormatTests` | hint suffix rules |
| `CarPlayThrottleTests` (app target) | ≤ 1 update per 10 s; coalescing; alert edges respect the 10 s floor |

### 3.3 Fixture replays — `FixtureReplayTests`
Parameterised over every `.elm`: `FixtureTransport` answers strict `[init]` then the `[live]` table, chunked by `@chunk`, delayed by `@delay` on the **test clock**; run `ObdClient` for `@cycles`; assert every `@expect`; on failure print the traffic log.

### 3.4 Simulator
Each `SimulatedElm327Transport` scenario reaches its expected phase/alert in simulated minutes; its replies never parse as `unknown`.

## 4. Real adapter on iPhone
| ID | Test | Pass |
|---|---|---|
| T-iBLE-1 | nRF Connect / LightBlue: `IOS-VLINK`, subscribe `2AF0`, write `ATZ\r` to `2AF1` | Reply contains `ELM327` (screenshot) |
| T-iBLE-2 | Same through Autopal's `BleTransport` | Traffic log `ATZ` → `ELM327 v…`; pipe saved |
| T-iBLE-3 | Ignition on: init → `010C` | `41 0C …` decoded RPM ≈ dashboard |
| T-iBLE-4 | Lock the phone 10 min while LIVE | Polling continues (background mode); Live Activity updates |
| T-iBLE-5 | Kill and relaunch app; walk away and back | State restoration or clean reconnect ≤ 30 s |
| T-iBLE-6 | Use adapter with Android first, then iPhone without replug / with replug | Documents I7 behaviour |
| T-iWIFI-1 | Wi-Fi adapter: join its network, connect 192.168.0.10:35000 | `ATZ` round trip; Local Network prompt handled |
| T-iPERF-1 | 5 min LIVE on CAN car, BLE | Poll rate recorded (compare with Android SPP) |

## 5. CarPlay, Live Activity, widgets
Use **CarPlay Simulator** (Xcode 27 Device Hub, or Additional Tools for Xcode) at small, wide and portrait car screen sizes, light and dark, with touch and with knob input. Demo mode in the app.

| ID | Check | Pass |
|---|---|---|
| CP-1 | Autopal appears on the CarPlay home screen (only once the entitlement is granted) | Launches without crash |
| CP-2 | Health tab rows: verdict + 4 values, constant titles | Matches `ios-carplay-*.png` |
| CP-3 | Updates ≤ 1 per 10 s for 10 min of Demo driving | Log of update timestamps |
| CP-4 | Demo `overheat`: one `CPAlertTemplate`, not repeated | Recording |
| CP-5 | Faults tab: plain-language rows, depth ≤ 3 | Recording |
| CP-6 | Knob-only navigation reaches every row and action | Recording |
| CP-7 | Drive monitor Live Activity appears on the CarPlay dashboard and Lock Screen; Dynamic Island compact/expanded | Screenshots |
| CP-8 | Vehicle health widget in a CarPlay widget stack; shows data age | Screenshot |
| CP-9 | Phone app never opened since install, CarPlay launched: clear "Open Autopal on your iPhone" state | Screenshot |
| CP-10 | Real head unit (Lenovo D1, Wigo): CP-2, CP-4, CP-7 | Video |

## 6. iPhone, iPhone Duo, iPad UI
| ID | Check | Pass |
|---|---|---|
| UI-1 | Every designed state has a `#Preview` in light and dark | Count matches UI_DESIGN-iOS state table |
| UI-2 | Previews vs `docs/design/screens/ios-*.png` | Same order, hierarchy, colour roles, text; spacing within 4 pt |
| UI-3 | Dynamic Type AX5; Bold Text; Reduce Transparency; Increase Contrast | No truncated values; glass falls back to solid |
| UI-4 | VoiceOver on Home | Verdict, each gauge, tabs announced in order |
| UI-5 | iPhone Duo folded (outer display) | Compact layout = iPhone |
| UI-6 | iPhone Duo unfolded | Regular layout: split view with readings + health |
| UI-7 | iPhone Duo Split View with another app (both halves) | Compact layout in each half; no clipping |
| UI-8 | Fold/unfold during LIVE | No reconnect, no lost state, scroll position kept |
| UI-9 | Resizable simulator: drag through all widths | No layout breaks at any width |
| UI-10 | iPad (regular) | Same as UI-6 |
| UI-11 | Settings › Appearance System / Light / Dark | App, widgets and Live Activity switch; CarPlay unchanged (follows car) |
| UI-12 | Units °F, mi, psi | Every reading, alert text and widget converts; fixtures still pass (core metric) |
| UI-13 | Adapter unplugged on Home | "Not connected" card; Connect reaches the Adapter screen in one tap |
| UI-14 | Fresh install, adapter in, ignition on | Setup reaches step 4 without leaving the app; time to first live reading recorded (target ≤ 60 s) |
| UI-15 | Setup with ignition off / Bluetooth denied / adapter unplugged | Each shows its error board's text; Try again recovers without restarting setup |
| UI-16 | Deny Bluetooth, then deny notifications | One explanation, no repeated prompts; Demo works; Open Settings goes to the app's settings page |
| UI-17 | Skip at every step | Lands on Home; "Not connected" resumes at step 2; setup never shows again after success |
| UI-18 | Settings › Accessibility › Motion › Reduce Motion on, then off | On: crossfades only, no pulse, live dot static; off: motion as UI_DESIGN-iOS §4a; nothing flashes repeatedly |
Use the resizable iOS Simulator and Previews across sizes (Xcode 27). iPhone Duo hardware tests when a device is available; until then mark "simulator only".

**Snapshot tests:** no third-party snapshot library without asking. Use Xcode's preview rendering (or `ImageRenderer` in a test) to save PNGs of key previews into `build/` for side-by-side review; don't commit regenerated images without the owner's approval.

## 7. Vehicle matrix
Same matrix as Android (2010+ petrol CAN, diesel, hybrid, pre-2008/K-Line, non-OBD import). For iOS, also one BLE-only adapter and one Wi-Fi adapter.

## 8. Evidence
`docs/evidence/YYYY-MM-DD_<test-id>_<device-or-car>.<ext>`; `docs/STATUS-iOS.md` links each ✅ to its file.
