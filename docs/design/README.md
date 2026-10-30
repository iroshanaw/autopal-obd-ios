# docs/design — the design as files the agent can read

Xcode's coding agent can't open Claude Design links. Everything it needs is here.

| File | What | How it gets here |
|---|---|---|
| `tokens.json` | Autopal colours (dark + light), type, spacing, radius | Copy of the Autopal Design System's `project/tokens.json` (same file as the Android repo). Then `python3 scripts/tokens_to_swift.py`. |
| `screens/ios-*.png` | One PNG per board of the iOS canvas | Canvas › Share › Export › PNG. Names `ios-<Screen>[-<State>]-<theme>.png` (full list in `../APPLY-DESIGN-iOS.md`); check with `python3 scripts/check-design-exports.py` |
| `../UI_DESIGN-iOS.md` | Written spec | Updated whenever the canvas changes |

Never edit `tokens.json` here; change the design system and copy it again, in both repos.
