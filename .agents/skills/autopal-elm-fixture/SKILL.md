---
name: autopal-elm-fixture
description: Turn an exported Autopal traffic log from a real car or adapter into a replayable .elm fixture for AutopalCore tests (shared with Android). Use when the owner shares a traffic log, reports a hardware bug, or asks to capture a recording.
---

# Traffic log → `.elm` fixture

1. Save the exported log unchanged to `docs/evidence/YYYY-MM-DD_<test-id>_<car-or-adapter>.txt`.
2. Convert:
   ```bash
   python3 .agents/skills/autopal-elm-fixture/scripts/traffic_log_to_elm.py \
       docs/evidence/<log>.txt \
       AutopalCore/Tests/AutopalCoreTests/Resources/elm-sessions/recorded/<car>-<adapter>-<yyyymmdd>.elm \
       --name "<car, year, protocol, adapter>"
   ```
   It writes strict `[init]` up to the first successful `010C`, a `[live]` table, replaces the VIN with a sample VIN,
   adds `@delay` for timeouts and `@chunk 20` for BLE logs, and leaves `@expect` as TODO comments.
3. Write `@expect` lines for what **should** have happened, with hand-decoded arithmetic as comments.
4. `swift test --package-path AutopalCore` → the new fixture must **fail** for the reported bug. Then fix. Then all fixtures pass.
5. Tell the owner to copy the same `.elm` file into the Android repo (`core/src/test/resources/elm-sessions/recorded/`).

Never edit committed recordings except the VIN; never edit the synthetic fixtures.
