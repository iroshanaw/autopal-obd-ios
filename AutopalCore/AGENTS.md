# AutopalCore/AGENTS.md — protocol core rules

Applies to everything under `AutopalCore/`. The root `AGENTS.md` still applies.

## Hard rules
- Pure Swift + Foundation. **Never import** UIKit, SwiftUI, CoreBluetooth, Network, ActivityKit, WidgetKit or CarPlay here.
- Swift 6 language mode, strict concurrency. Public types `Sendable`.
- Time only through an injected `any Clock<Duration>`. No `Date()`, `Date.now`, `Task.sleep(nanoseconds:)` or `Thread.sleep` in `Sources/`.
  Tests use a manual test clock (write a small one in `Tests/`; no dependencies).
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), parameterised over the CSV rows and `.elm` files.
- Resources: `Tests/AutopalCoreTests/Resources/` declared with `.copy("Resources")` in `Package.swift`. Never edit existing lines.

## ELM327 framing (ARCHITECTURE-iOS §5.1)
1. `ElmSession` is an `actor`; one command in flight.
2. Accumulate bytes until `>`; drop NUL; accept `\r`, `\n`, `\r\n`.
3. Subscribe to `incoming` before the first `send`.
4. After a timeout: wait 300 ms on the injected clock, discard buffered bytes.
5. Timeouts 2.5 s, `ATZ` 5 s, first OBD request after `ATSP0` 15 s.
6. `TrafficLog.export()` format is fixed; the fixture converter parses it.

## Init order — fixtures check it strictly
`ATZ ATE0 ATL0 ATS0 ATH0 ATAT1 ATSP0 ATRV 0100 ATDPN [0120 0140 0160 while bit set] 0902 0101 03 07`
Optional (tolerate `?`): `ATL0 ATS0 ATAT1 ATRV 0902`.

## Response-count hint
CAN only, Mode 01 data PIDs in the poll tiers (`010C1`); never ranges, `0101`, `03`, `07`, `0902`. On `?`, disable for the session and resend the same PID.

## Polling order
FAST tier fixed: `010C`, `010D`, `0111`, `0104` (`clone_quirks.elm` depends on it).

## Fixture format
`Tests/AutopalCoreTests/Resources/elm-sessions/README.md`. Same files as Android: a behaviour difference between the apps is a bug in one of them.
