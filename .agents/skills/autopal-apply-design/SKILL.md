---
name: autopal-apply-design
description: Implement or update an Autopal iOS screen, widget or Live Activity in SwiftUI exactly as designed in Claude Design, from docs/UI_DESIGN-iOS.md, docs/design/tokens.json and the exported PNGs. Use for any UI, theme, layout or visual work.
---

# Apply the design (SwiftUI)

The design is the source of truth. Reproduce it; if something can't be built or looks wrong, stop and say so.

## 0. Inputs
- `docs/UI_DESIGN-iOS.md`: the screen's section, §2 tokens, §3 components, §4 layout rules.
- `docs/design/screens/ios-<Screen>[-<State>]-<theme>.png` (names in docs/APPLY-DESIGN-iOS.md): all PNGs for the screen (light, dark, compact, regular, states). Missing → ask.
- `Autopal/Theme/AutopalTokens.swift`: generated. `python3 scripts/tokens_to_swift.py --check` must pass.

## 1. Theme (once)
- Run `python3 scripts/tokens_to_swift.py`. It writes `AutopalTokens.swift`: dynamic `Color`s (light/dark), spacing and radii.
- `AutopalTheme`: fonts (Archivo via bundled files, or the system font if not bundled: say which), `.monospacedDigit()` for numbers.
- App tint = `AutopalTokens.primary`.

## 2. Components first, each with `#Preview`s (light + dark, Dynamic Type L and AX3)
`GaugeView` (SwiftUI `Canvas` or `Shape`s: 270° arc from 135°, round caps, states normal/warning/critical/stale) →
`VerdictCard` → `StatusChip` → `CheckRow`.

## 3. Screen
- Navigation: compact `TabView` (Home, Check, Faults, Settings; Adapter is pushed from Settings or the Home "Not connected" card); regular `NavigationSplitView` with the same four items. Let the system draw Liquid Glass bars.
- `.glassEffect()` only on floating custom controls (UI_DESIGN-iOS says which). No glass behind numbers.
- Colours only from `AutopalTokens`. No hard-coded colours: the guardrail fails the commit.
- Strings in the String Catalog. Safe areas respected; no fixed screen sizes.
- Accessibility: VoiceOver label per gauge; Dynamic Type to AX5 without truncating values; Reduce Transparency respected.
- Motion only as UI_DESIGN-iOS §4a says, with `AutopalMotion` tokens; honour Reduce Motion. No other animations.

## 4. Previews (each state the design shows)
`#Preview` per state × theme, plus traits for compact and regular widths. Feed them fixed `VehicleSnapshot`s equal to the design's values.
Check iPhone Duo in the resizable simulator: folded (compact), unfolded (regular), Split View half (compact).

## 5. Verify and report
```bash
python3 scripts/tokens_to_swift.py --check
scripts/check-guardrails.sh
xcodebuild -scheme Autopal -destination 'platform=iOS Simulator,name=<installed iPhone>' build
```
Capture the previews and compare with the PNGs. Report states built, differences you could not avoid (and why), and what needs a device.
