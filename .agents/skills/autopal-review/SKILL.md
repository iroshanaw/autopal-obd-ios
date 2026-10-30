---
name: autopal-review
description: Review the current Autopal iOS diff against protocol, iOS, CarPlay, design and honesty rules before committing. Use when asked to review, check or audit changes; run in a fresh conversation.
---

# Pre-commit review (iOS)

Run in a **new conversation** so the review isn't biased by the reasoning that wrote the code.

## 1. Collect
```bash
git status && git diff --stat HEAD && git diff HEAD
scripts/check-guardrails.sh
swift test --package-path AutopalCore
```
Failing guardrails or tests are the first finding.

## 2. Check in order (stop at the first critical)
**Critical**
- Changed or deleted lines in `AutopalCore/Tests/AutopalCoreTests/Resources/`.
- UIKit/SwiftUI/CoreBluetooth/Network imports in `AutopalCore`; `Date()`/`Task.sleep` without the injected clock in core.
- Adapter writes bypassing `ElmSession.send`; completion on write callback instead of `>`.
- Mode 04, or any vehicle-state-changing command.
- BLE UUID literals outside `BleUartCandidates.swift`; any External Accessory / Classic Bluetooth code.
- CarPlay: `CPMapTemplate`, updates faster than every 10 s, live RPM/speed, settings or Demo on CarPlay, depth > 3.
- Status claims stronger than the evidence.
**Major**
- Hard-coded colours; custom glass behind numbers; fixed frames/orientation locks; `UIScreen.main`.
- Unsupported values shown as 0; stale shown as live; widget claiming live data.
- Thresholds changed without `alert_scenarios.csv` (and without telling the owner the Android repo needs the same change).
- Main-thread blocking; non-`Sendable` types crossing actors; CoreBluetooth used off its queue.
- New dependency without the owner asking.
**Minor**
- Missing `#Preview` for a designed state; missing VoiceOver label; missing String Catalog entry.

## 3. Report
```
Verdict: COMMIT | FIX FIRST
Guardrails: pass/fail    Core tests: <summary>
Critical: <file>:<line> — problem — why — fix
Major: …
Minor: …
Not checked (needs device / car / CarPlay unit): …
```
Findings only; fix nothing unless asked.
