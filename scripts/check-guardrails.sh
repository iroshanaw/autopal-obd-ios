#!/usr/bin/env bash
# Autopal iOS guardrails. Enforces AGENTS.md rules an AI agent might ignore.
# Used by .githooks/pre-commit and CI.
#
#   scripts/check-guardrails.sh             # working tree vs HEAD
#   scripts/check-guardrails.sh --staged    # staged changes (pre-commit)
#   scripts/check-guardrails.sh --base REF  # changes since REF (CI)
#
# Owner-only override for a deliberate, reviewed change:
#   AUTOPAL_ALLOW_FIXTURE_EDIT=1
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

mode="worktree"; base="HEAD"
case "${1:-}" in
  --staged) mode="staged" ;;
  --base)   mode="base"; base="${2:?--base needs a ref}" ;;
  "")       ;;
  *) echo "usage: $0 [--staged | --base REF]"; exit 2 ;;
esac

diff_numstat() {
  case "$mode" in
    staged)   git diff --cached --numstat --no-renames -- "$@" ;;
    base)     git diff --numstat --no-renames "$base"...HEAD -- "$@" ;;
    worktree) git diff --numstat --no-renames HEAD -- "$@" ;;
  esac
}

fail=0
report() { echo "✗ $1"; fail=1; }
ok()     { echo "✓ $1"; }

# grep Swift sources under a path, excluding file names. Prints file:line:text.
swift_grep() {
  local pattern="$1" path="$2"; shift 2
  [ -d "$path" ] || return 0
  local excludes=()
  for f in "$@"; do excludes+=(--exclude="$f"); done
  grep -rnE --include='*.swift' ${excludes[@]+"${excludes[@]}"} "$pattern" "$path" 2>/dev/null
}
show() { echo "$1" | sed 's/^/    /'; }

CORE_SRC="AutopalCore/Sources"
APP_DIRS="Autopal AutopalWidgets"
RES="AutopalCore/Tests/AutopalCoreTests/Resources"

# 1. Shared fixtures: existing lines never change (appends allowed).
bad=$(diff_numstat "$RES" | awk '$2 != "0" && $2 != "-" { print $3 " (" $2 " lines changed/removed)" }')
if [ -n "$bad" ]; then
  if [ "${AUTOPAL_ALLOW_FIXTURE_EDIT:-0}" = "1" ]; then echo "! fixture edits allowed by override:"; show "$bad"
  else report "shared test fixtures modified (AGENTS.md rule 6):"; show "$bad"; fi
else ok "fixtures: no existing lines changed"; fi

# 2. Core stays pure Swift.
hits=$(swift_grep '^[[:space:]]*(@preconcurrency[[:space:]]+)?import[[:space:]]+(UIKit|SwiftUI|CoreBluetooth|Network|ActivityKit|WidgetKit|CarPlay|ExternalAccessory)\b' "$CORE_SRC")
[ -n "$hits" ] && { report "Apple UI/radio framework imported in AutopalCore:"; show "$hits"; } || ok "AutopalCore imports only Foundation-level frameworks"

# 3. Core uses the injected clock.
hits=$(swift_grep 'Date\(\)|Date\.now|Task\.sleep\(nanoseconds|Thread\.sleep|DispatchQueue\.main\.asyncAfter' "$CORE_SRC")
[ -n "$hits" ] && { report "direct time access in AutopalCore (inject a Clock):"; show "$hits"; } || ok "AutopalCore uses the injected clock"

# 4. BLE UUIDs only in BleUartCandidates.swift.
UUID_RE='CBUUID\(string:|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
hits=$(for d in $APP_DIRS "$CORE_SRC"; do swift_grep "$UUID_RE" "$d" BleUartCandidates.swift; done)
[ -n "$hits" ] && { report "BLE UUID outside BleUartCandidates.swift:"; show "$hits"; } || ok "no stray BLE UUIDs"

# 5. No Classic Bluetooth / MFi code.
hits=$(for d in $APP_DIRS "$CORE_SRC"; do swift_grep 'import[[:space:]]+ExternalAccessory|EAAccessory|EASession' "$d"; done)
[ -n "$hits" ] && { report "External Accessory (Classic/MFi) code found:"; show "$hits"; } || ok "no Classic Bluetooth code"

# 6. Never clear fault codes.
hits=$(for d in $APP_DIRS "$CORE_SRC"; do swift_grep 'send\([[:space:]]*"04' "$d"; done)
[ -n "$hits" ] && { report "Mode 04 (clear codes) command found:"; show "$hits"; } || ok "no Mode 04 commands"

# 7. CarPlay: not a navigation app.
hits=$(for d in $APP_DIRS; do swift_grep 'CPMapTemplate|CPNavigationSession' "$d"; done)
[ -n "$hits" ] && { report "navigation-only CarPlay API used:"; show "$hits"; } || ok "no navigation-only CarPlay APIs"

# 8. Design first: generated tokens current.
if [ -f docs/design/tokens.json ]; then
  PY=$(command -v python3 || command -v python || true)
  if [ -n "$PY" ]; then
    if out=$("$PY" scripts/tokens_to_swift.py --check 2>&1); then ok "Swift tokens match the design system"; else report "$out"; fi
  else echo "! python not found: skipped the design-token check"; fi
fi

# 9. Design first: no hard-coded colours.
COLOR_RE='Color\((red|hue|white):|UIColor\((red|hue|white):|Color\(hex|Color\(#|Color\.(red|green|orange|yellow|blue|gray|black|white)\b|\.foregroundStyle\(\.(red|green|orange|yellow|blue)\)'
hits=$(for d in $APP_DIRS; do swift_grep "$COLOR_RE" "$d" AutopalTokens.swift; done)
[ -n "$hits" ] && { report "hard-coded colour outside AutopalTokens.swift:"; show "$hits"; } || ok "no hard-coded colours"

# 10. No fixed-device assumptions (iPhone Duo / resizable apps).
hits=$(for d in $APP_DIRS; do swift_grep 'UIScreen\.main|UIRequiresFullScreen|supportedInterfaceOrientations' "$d"; done)
[ -n "$hits" ] && { report "fixed screen/orientation assumption (breaks iPhone Duo and resizing):"; show "$hits"; } || ok "no fixed screen assumptions"

# 11. Evidence links resolve.
if [ -f docs/STATUS-iOS.md ]; then
  missing=""
  for p in $(grep -oE 'evidence/[A-Za-z0-9._/-]+' docs/STATUS-iOS.md | sort -u); do [ -e "docs/$p" ] || missing="$missing docs/$p"; done
  [ -n "$missing" ] && { report "STATUS-iOS.md links to missing evidence:"; for m in $missing; do echo "    $m"; done; } || ok "STATUS-iOS.md evidence links resolve"
fi

if [ "$fail" -ne 0 ]; then echo; echo "Guardrails FAILED. See AGENTS.md. Fix the code, not the fixtures."; exit 1; fi
echo; echo "Guardrails passed."
