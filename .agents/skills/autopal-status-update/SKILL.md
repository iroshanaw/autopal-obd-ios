---
name: autopal-status-update
description: Update docs/STATUS-iOS.md after any task or hardware test, marking items done only when an evidence file exists. Use at the end of every task or when the owner reports a test result.
---

# Update STATUS-iOS.md

| Symbol | Meaning | Requires |
|---|---|---|
| ✅ | Done | A file in `docs/evidence/` linked in the Evidence column |
| ⏳ | In progress | Say what is left |
| ⏸ | Blocked / not started | Name the blocker |
| ❓ | Unknown | Nobody has tested it |

Code-only work: "passes fixtures (<n> tests) — unverified on device". Not ✅ for anything whose exit criterion needs a device, car, adapter or CarPlay unit.

1. List `docs/evidence/`; only those files justify ✅. Names: `YYYY-MM-DD_<test-id>_<device-or-car>.<ext>`.
2. Update the items the task touched; downgrade anything contradicted (explain under Open questions).
3. Set "Last updated"; add new open questions with what they block; show the owner the diff.
Never delete a past entry to hide a failure.
