# Autopal OBD (iOS) — Status

Rule: ✅ only with a linked evidence file in `docs/evidence/`. Otherwise ⏳ in progress, ⏸ blocked / not started, ❓ unknown.

Last updated: 2026-10-29

## Hardware facts (iOS)
| Fact | Status | Evidence |
|---|---|---|
| Adapter is a clone (`JINXUSOLU JXSL-MIC34LE`) | ✅ | earlier session, add screenshot |
| `IOS-VLINK` UART pipe = `18F0` / notify `2AF0` / write `2AF1` | ✅ | earlier session, add log |
| `FF12/FF14/FF15` and `e7810a71-…` ruled out on iOS | ✅ | earlier session |
| ELM327 init → `010C` round trip on iOS | ⏳ | — run T-iBLE-3 |
| Adapter needs replug when switching Android ↔ iPhone | ✅ observed | add note/video |
| Wi-Fi adapter works on iPhone | ❓ | — needs a Wi-Fi adapter |

## Platform answers
| Question | Status |
|---|---|
| CarPlay driving-task entitlement for an OBD health app | ⏸ not requested |
| Live Activity small family visible on CarPlay for our activity | ❓ verify in CarPlay Simulator |
| iPhone Duo in Xcode Device Hub / simulator | ❓ "upcoming" per Apple at launch |

## Phases (ARCHITECTURE-iOS §9)
| Phase | Status | Evidence |
|---|---|---|
| 0 iOS BLE round trip | ⏳ in progress | Step 7 code complete: `BleTransport` + `BleUartCandidates` implemented with state restoration, candidate pipe priority, notify-before-write, chunking, and pipe verification; awaiting physical run on `IOS-VLINK` (T-iBLE-1/2) |
| 1 AutopalCore + fixtures green | ⏳ | Steps 1–5 complete: core framing, decoders, alert rules, polling scheduler, ObdClient, 6 session fixtures & SimulatedElm327Transport (7 scenarios) green |
| 2 Phone UI in Demo mode | ⏳ in progress | Step 6 & Step 8 complete: AppModel, VehicleStore, SettingsStore, ConnectionManager; all primary screens (Home, HealthCheck, Faults, Settings, AdapterSetup, EngineOff, TrafficLog, SetupFlow); compact TabView & regular split navigation; 0 build errors; guardrails passed |
| 3 Real data on the Wigo | ⏸ | — |
| 4 CarPlay entitlement requested | ⏸ | — |
| 5 CarPlay templates in Simulator | ⏳ in progress | Step 10 code complete: `CarPlaySceneDelegate` (`CPTabBarTemplate` > `CPListTemplate` for Health & Faults, `CPAlertTemplate` for critical alerts, depth ≤ 3), `CarPlayThrottle` (10s throttle & coalescing), `Info.plist` `CPTemplateApplicationSceneSessionRoleApplication` configured; 0 build errors; guardrails passed |
| 6 Live Activity + widget (incl. CarPlay) | ⏳ in progress | Step 9 code complete: `VehicleHealthWidget` (systemSmall & accessoryRectangular), `DriveLiveActivity` (Lock Screen, Dynamic Island, CarPlay small family), `LiveActivityController`, `SharedSnapshot` (App Group container); 0 build errors; guardrails passed |
| 7 iPhone Duo layouts | ⏸ | — |
| 8 TestFlight | ⏸ | — |

## Open questions
| Question | Blocks | Owner |
|---|---|---|
| Will Apple grant `carplay-driving-task` for vehicle health? | CarPlay templates | Iroshana |
| Fault severity table and health-check thresholds (mechanical engineer) | Verdicts on all platforms | Iroshana |
| Bundle Archivo font or use the system font on iOS? | Theme | Iroshana |
