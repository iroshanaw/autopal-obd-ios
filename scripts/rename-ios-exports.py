#!/usr/bin/env python3
"""Rename exported iOS canvas PNGs to the names the docs and prompts use.

Usage (from the repo root):
  python3 scripts/rename-ios-exports.py [folder]           # dry run: shows what would happen
  python3 scripts/rename-ios-exports.py [folder] --apply   # renames
Default folder: docs/design/screens

Matches each PNG by the board title on the canvas ("Home · healthy · dark") or by the board's file name
("Main", "Setup-Plug", "carplay-Health" ...). Ignores case, spaces and punctuation, and copy suffixes like " (1)" or "@2x".
Never overwrites an existing file. Files it can't match are listed; rename those by hand.
"""
import pathlib
import re
import sys

# (target name, board title on canvas, board file)
BOARDS = [
    ('ios-Home-dark', 'Home · healthy · dark', 'Main.dc.html'),
    ('ios-Home-Warning-dark', 'Home · coolant warning · dark', 'Home-Warning.dc.html'),
    ('ios-HealthCheck-dark', 'Health check · result · dark', 'HealthCheck.dc.html'),
    ('ios-Faults-dark', 'Faults · dark', 'Faults.dc.html'),
    ('ios-Settings-dark', 'Settings tab · dark (Appearance is interactive)', 'Settings.dc.html'),
    ('ios-Adapter-dark', 'Settings › Adapter (BLE, Wi-Fi, Demo) · dark', 'Adapter.dc.html'),
    ('ios-Home-Disconnected-dark', 'Home · not connected · one-tap Connect', 'Home-Disconnected.dc.html'),
    ('ios-HealthCheck-Running-dark', 'Health check · running · dark', 'HealthCheck-Running.dc.html'),
    ('ios-NoEngine-dark', 'Engine off (NO_ECU) · dark', 'NoEngine.dc.html'),
    ('ios-TrafficLog-dark', 'Settings › Traffic log · dark', 'TrafficLog.dc.html'),
    ('ios-Home-light', 'Home · healthy · light', 'Home-Light.dc.html'),
    ('ios-Home-Warning-light', 'Home · coolant warning · light', 'Home-Warning-Light.dc.html'),
    ('ios-HealthCheck-light', 'Health check · result · light', 'HealthCheck-Light.dc.html'),
    ('ios-Faults-light', 'Faults · light', 'Faults-Light.dc.html'),
    ('ios-Settings-light', 'Settings tab · light', 'Settings-Light.dc.html'),
    ('ios-Adapter-light', 'Settings › Adapter · light', 'Adapter-Light.dc.html'),
    ('ios-NoEngine-light', 'Engine off (NO_ECU) · light', 'NoEngine-Light.dc.html'),
    ('ios-TrafficLog-light', 'Settings › Traffic log · light', 'TrafficLog-Light.dc.html'),
    ('ios-setup-Welcome-dark', '1 Welcome · dark (export as setup-Welcome-dark.png; interactive)', 'Setup.dc.html'),
    ('ios-setup-Plug-dark', '2 Plug in · dark', 'Setup-Plug.dc.html'),
    ('ios-setup-Permission-dark', '3a Bluetooth permission (before the iOS alert)', 'Setup-Permission.dc.html'),
    ('ios-setup-Connect-dark', '3b Connecting · dark', 'Setup-Connect.dc.html'),
    ('ios-setup-Car-dark', '4 Connected · your car · dark', 'Setup-Car.dc.html'),
    ('ios-setup-Error-NoEcu-dark', 'Error · car not answering (ignition off)', 'Setup-Error-NoEcu.dc.html'),
    ('ios-setup-Error-Bluetooth-dark', 'Error · Bluetooth off or not allowed', 'Setup-Error-Bluetooth.dc.html'),
    ('ios-setup-Error-NoAdapter-dark', 'Error · no adapter found in 30 s', 'Setup-Error-NoAdapter.dc.html'),
    ('ios-setup-Welcome-light', '1 Welcome · light', 'Setup-Welcome-Light.dc.html'),
    ('ios-setup-Plug-light', '2 Plug in · light', 'Setup-Plug-Light.dc.html'),
    ('ios-setup-Connect-light', '3b Connecting · light', 'Setup-Connect-Light.dc.html'),
    ('ios-setup-Car-light', '4 Connected · light', 'Setup-Car-Light.dc.html'),
    ('ios-duo-Folded-dark', 'Folded · outer display (compact)', 'Duo-Folded.dc.html'),
    ('ios-duo-Unfolded-dark', 'Unfolded · portrait (larger gauges)', 'Duo-Unfolded.dc.html'),
    ('ios-duo-SplitView-dark', 'Unfolded · Split View with another app', 'Duo-SplitView.dc.html'),
    ('ios-duo-Landscape-dark', 'Unfolded · landscape (sidebar + two panes)', 'Duo-Landscape.dc.html'),
    ('ios-carplay-Health-Night', 'CarPlay · Health tab (CPListTemplate)', 'carplay/Health.dc.html'),
    ('ios-carplay-Faults-Night', 'CarPlay · Faults tab (CPListTemplate)', 'carplay/Faults.dc.html'),
    ('ios-carplay-Alert-Night', 'CarPlay · critical alert (CPAlertTemplate)', 'carplay/Alert.dc.html'),
    ('ios-carplay-Dashboard-Night', 'CarPlay home · Drive monitor Live Activity', 'carplay/Dashboard.dc.html'),
    ('ios-carplay-Widgets-Night', 'CarPlay widgets · Vehicle health widget', 'carplay/Widgets.dc.html'),
    ('ios-glance-LockScreen-dark', 'Lock Screen · Live Activity + widget', 'glance/LockScreen.dc.html'),
    ('ios-glance-DynamicIsland-dark', 'Dynamic Island · compact, minimal, expanded', 'glance/DynamicIsland.dc.html'),
    ('ios-glance-Widgets', 'Home Screen widgets · small, dark & light', 'glance/Widgets.dc.html'),
]

def norm(s):
    s = re.sub(r"@\dx$", "", s)
    s = re.sub(r"\s*\(\d+\)$", "", s)
    s = s.replace(".dc.html", "")
    return re.sub(r"[^a-z0-9]", "", s.lower())

keys = {}
ambiguous = set()
for target, title, board in BOARDS:
    cands = {norm(title), norm(board), norm(board.split("/")[-1]) if "/" not in board else None, norm(target)}
    for k in filter(None, cands):
        if k in keys and keys[k] != target:
            ambiguous.add(k)
        keys[k] = target
for k in ambiguous:          # e.g. "Faults" is both an iPhone and a CarPlay board: use the full title instead
    keys.pop(k, None)

args = [a for a in sys.argv[1:] if not a.startswith("--")]
apply = "--apply" in sys.argv
folder = pathlib.Path(args[0] if args else "docs/design/screens")
if not folder.is_dir():
    sys.exit(f"Folder not found: {folder}")

done, todo, unknown = 0, [], []
for p in sorted(folder.glob("*.png")):
    target = keys.get(norm(p.stem))
    if target is None:
        unknown.append(p.name)
    elif p.stem == target:
        done += 1
    else:
        todo.append((p, folder / f"{target}.png"))

clash = [(a, b) for a, b in todo if b.exists() or [x for _, x in todo].count(b) > 1]
for a, b in todo:
    if (a, b) in clash:
        print(f"  SKIP      {a.name} -> {b.name} (target already exists or two files map to it)")
        continue
    print(f"  {'RENAME' if apply else 'WOULD'}    {a.name} -> {b.name}")
    if apply:
        a.rename(b)
for n in unknown:
    print(f"  UNKNOWN   {n}  (rename by hand; see docs/APPLY-DESIGN-iOS.md)")

expected = {t for t, _, _ in BOARDS}
present = {p.stem for p in folder.glob("*.png")} if apply else {p.stem for p in folder.glob("*.png")} | {b.stem for a, b in todo if (a, b) not in clash}
missing = sorted(expected - present)
print(f"\n{len(expected) - len(missing)} of {len(expected)} expected screens {'present' if apply else 'would be present'}.")
for m in missing:
    print(f"  MISSING   {m}.png")
if not apply and todo:
    print("\nDry run only. Add --apply to rename.")
