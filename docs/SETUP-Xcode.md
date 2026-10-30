# Setup — Xcode with coding agents (Claude Agent or Codex)

## 1. How the Claude Code structure maps to Xcode

| Claude Code piece | In Xcode (26.3+ / 27) | In this repo | Confidence |
|---|---|---|---|
| `CLAUDE.md` | Project instruction file read by Claude Agent; Codex reads `AGENTS.md` | `AGENTS.md` (full rules) + `CLAUDE.md` importing it; same pair in `AutopalCore/` and `Autopal/` | [Likely]: verify with the check in §4 |
| `.claude/skills/` | Project skills for Claude Agent; Apple's own skills via `/` in the message field and `xcrun agent skills export ~/.agents/skills` | `.agents/skills/` (8 skills), linked as `.claude/skills/` | Project folder [Likely]; Apple export [Certain] |
| `.claude/settings.json` (permissions) | Xcode › Settings › Intelligence › Agents › **Permissions** (allowed commands and tools) | — (UI only) | [Certain] |
| Model, MCP servers, global skills | `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/` (Claude) or `…/codex/` | — (per machine) | [Certain] |
| `commands/` | Slash commands in the message field (`/plan`, Apple skills); our skills by name | `.agents/skills/` | [Certain] for `/plan` |
| `agents/` (sub-agents) | Xcode runs sub-agents itself; plug-ins can add more (Intelligence › Plug-ins) | Run `autopal-review` in a new conversation | [Certain] |
| `hooks/` | No agent hooks | `.githooks/pre-commit`, `scripts/check-guardrails.sh`, `.github/workflows/ios-ci.yml` | [Certain] |
| `.mcp.json` | MCP config in the agent config folder above; Claude Code in Terminal can reach Xcode via `xcrun mcpbridge` | — | [Certain] |

## 2. Before you start
- A Mac with **Xcode 27** (iOS 27 SDK: iPhone Duo, resizable simulator, Device Hub with CarPlay Simulator). Deployment target **iOS 26.0**.
- Apple Developer Program membership: App Groups, Live Activities on device, TestFlight and the CarPlay entitlement request need it.
- An iPhone on iOS 26+ for BLE tests (BLE does not work in the Simulator). The Wigo + Lenovo D1 head unit for CarPlay checks.
- Xcode › Settings › Intelligence: sign in to Claude (Claude Agent) and/or ChatGPT (Codex).

## 3. Project setup
1. Xcode › New › Project › iOS App, SwiftUI, name **Autopal**, organisation identifier `com.autopal`, Swift. Set deployment target iOS 26.0, Swift 6.
2. Copy this package into the project root (next to `Autopal.xcodeproj`), merging folders. Keep Xcode's `.gitignore`; don't ignore `.agents/`, `.claude/`, `.githooks/`, `docs/`.
3. `git init`, commit, then `git config core.hooksPath .githooks` (once per clone) and `chmod +x .githooks/pre-commit scripts/*.sh scripts/*.py`.
4. `python3 scripts/tokens_to_swift.py`, then add `Autopal/Theme/AutopalTokens.swift` to **both** the app and widget targets.
5. Give build step 0 to the agent (§5); it creates the `AutopalCore` package, widget extension, capabilities and Info.plist keys.
6. Request the CarPlay entitlement now (it takes time): developer.apple.com › CarPlay › request entitlement, category **Driving task**. Suggested description:
   > Autopal shows a car's health from its OBD-II port: a plain-language verdict, active warnings (overheating, charging failure) and fault codes, so drivers can decide whether to keep driving. Data updates at most every 10 seconds; no real-time engine data, no settings or video in CarPlay.
7. Push to a private GitHub repo so CI runs the guardrails and core tests on a macOS runner.

## 4. Check the agent sees the rules
Start a conversation with the agent and ask:
> Which instruction files (CLAUDE.md / AGENTS.md) and skills did you load for this project? List the autopal skills.

Expected: root `AGENTS.md` (via `CLAUDE.md` for Claude) and 8 `autopal-*` skills. If the skills are missing, copy `.agents/skills/*` into `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/skills/` and ask again. Also export Apple's skills once: `xcrun agent skills export ~/.agents/skills` (adds `swiftui-specialist`, `swiftui-whats-new-27`, `uikit-app-modernization`, `device-interaction`, `test-modernizer` and others).

## 5. Agent permissions (Intelligence › Agents › Permissions)
| Allow | Ask | Deny |
|---|---|---|
| `swift test`, `xcodebuild`, `xcrun simctl`, `python3 scripts/*`, `scripts/check-guardrails.sh` | anything that writes outside the repo, network tools | `git push`, `rm -rf`, editing `~/Library` |

## 6. First prompts (one build step per conversation)
1. `/plan` Use autopal-build-step for build step 0 (scaffold) only.
2. Use autopal-build-step for step 1. Tests first from TESTING-iOS §3.1–3.2. Do not modify anything under `AutopalCore/Tests/AutopalCoreTests/Resources`.
3. Before every commit, in a new conversation: Use autopal-review on the uncommitted changes.
4. UI steps: attach the PNGs from `docs/design/screens/` and say "Use autopal-apply-design for <screen>".

## 7. Testing tools
- **CarPlay Simulator:** Xcode 27 Device Hub (or Additional Tools for Xcode). Test small, wide and portrait car screens, light/dark, touch and knob.
- **Resizable iOS Simulator and Previews across sizes:** iPhone Duo folded / unfolded / Split View widths.
- **nRF Connect or LightBlue (iPhone):** raw BLE checks (T-iBLE-1).
- **Console.app:** device logs for background BLE sessions.

## 8. What the agent can't do for you
- Run anything on the car, the adapter or a real CarPlay head unit; drive the Wigo.
- Get the CarPlay entitlement or answer Apple App Review.
- Confirm thresholds: the mechanical engineer's review still decides severities and limits on both platforms.
