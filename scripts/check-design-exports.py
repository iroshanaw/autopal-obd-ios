#!/usr/bin/env python3
"""Check docs/design/screens/ against the export names used by the prompts, docs and skills.

Usage: python3 scripts/check-design-exports.py
Exit 0 when every expected PNG is present; prints missing and unexpected files.
"""
import pathlib
import sys

EXPECTED = """
ios-Home-dark
ios-Home-Warning-dark
ios-Home-Disconnected-dark
ios-HealthCheck-dark
ios-HealthCheck-Running-dark
ios-Faults-dark
ios-Settings-dark
ios-Adapter-dark
ios-NoEngine-dark
ios-TrafficLog-dark
ios-Home-light
ios-Home-Warning-light
ios-HealthCheck-light
ios-Faults-light
ios-Settings-light
ios-Adapter-light
ios-NoEngine-light
ios-TrafficLog-light
ios-setup-Welcome-dark
ios-setup-Plug-dark
ios-setup-Permission-dark
ios-setup-Connect-dark
ios-setup-Car-dark
ios-setup-Error-NoEcu-dark
ios-setup-Error-Bluetooth-dark
ios-setup-Error-NoAdapter-dark
ios-setup-Welcome-light
ios-setup-Plug-light
ios-setup-Connect-light
ios-setup-Car-light
ios-duo-Folded-dark
ios-duo-Unfolded-dark
ios-duo-SplitView-dark
ios-duo-Landscape-dark
ios-carplay-Health-Night
ios-carplay-Faults-Night
ios-carplay-Alert-Night
ios-carplay-Dashboard-Night
ios-carplay-Widgets-Night
ios-glance-LockScreen-dark
ios-glance-DynamicIsland-dark
ios-glance-Widgets
""".split()
OPTIONAL = {"ios-Adapter-Wifi-dark", "ios-Adapter-Demo-dark"}

root = pathlib.Path(__file__).resolve().parent.parent / "docs" / "design" / "screens"
have = {p.stem for p in root.glob("*.png")}
missing = [n for n in EXPECTED if n not in have]
extra = sorted(have - set(EXPECTED) - OPTIONAL)

print(f"{len(EXPECTED) - len(missing)} of {len(EXPECTED)} expected screens present in {root}")
for n in missing:
    print(f"  MISSING   {n}.png")
for n in extra:
    print(f"  UNKNOWN   {n}.png  (rename it to one of the expected names, or tell the docs about it)")
sys.exit(1 if missing else 0)
