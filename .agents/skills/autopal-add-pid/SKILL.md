---
name: autopal-add-pid
description: Add a new OBD-II Mode 01 value to Autopal iOS end to end — decoder, shared vectors, poll tier, UI, optional alert. Use when asked to show, read or monitor a new engine value.
---

# Add a PID (iOS)

1. **Confirm the PID** number, byte count and SAE J1979 formula with a confidence tag. Not [Certain] → stop and ask the owner.
2. **Vectors are shared with Android.** Append rows to `AutopalCore/Tests/AutopalCoreTests/Resources/vectors/pid_vectors.csv`
   (typical, min, max, wrong-PID → null, truncated → null), arithmetic in the `note` column. Show the owner. Tell them the same rows
   must be appended in the Android repo so the files stay identical.
3. **Implement:** `Param` case (label, unit, decimals), `PidCatalog` entry, tier (FAST only if it needs sub-second updates; keep the fixed FAST order first).
4. **UI:** shown only when supported; stale styling; CarPlay shows it only if it matters to the verdict (≤ 1 update / 10 s).
5. **Alert (only if asked):** rule in `AlertRules` with sustain + hysteresis; append scenarios to `alert_scenarios.csv`; same change needed on Android.
6. **Verify:** `swift test --package-path AutopalCore`, `scripts/check-guardrails.sh`. Report as in `autopal-build-step`.
