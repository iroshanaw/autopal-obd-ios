# ELM327 session fixtures

Each `.elm` file scripts an adapter + car. `FixtureTransport` (core test code) replays it,
`ObdClient` runs against it, and the replay test asserts the `@expect` lines on the final snapshot.

## Format

```
# comment
@name     human description
@chunk    20            optional: split every reply into 20-byte pieces (BLE notification size)
@cycles   3             optional: number of full poll cycles to run in [live] before asserting (default 2)
@expect   <key> <value> one per line, see keys below

[init]                  STRICT section: commands must arrive in exactly this order
TX <command>
RX <reply>

[live]                  TABLE section: used once [init] is exhausted, any order
<command> => <reply>                 every time
<command> =>1 <reply>                first time only, then falls through to the plain entry
<command> =>1 @delay=2700 <reply>    delay the reply by 2700 ms (timeout testing)
```

Reply text:
- Write `\r` for carriage return. The harness appends the prompt `\r\r>` to every reply.
- Echo is part of the reply when the script says so (before `ATE0` takes effect).
- In `[init]`, a TX that does not match the next scripted line fails the test with
  `expected TX <x>, got <y>`. This is how the init sequence order is verified.
- In `[live]`, a command with no entry fails the test with `unscripted command <x>`.
  This is how "never poll unsupported PIDs" is verified.

## @expect keys

| Key | Example | Meaning |
|---|---|---|
| `phase` | `LIVE` | final `ConnectionPhase` |
| `adapterVersion` | `ELM327 v1.5` | parsed from ATZ |
| `protocol` | `A6` | from ATDPN |
| `isCan` | `true` | |
| `hintEnabled` | `false` | response-count hint state at the end |
| `vin` | `1HGCM82633A004352` or `null` | |
| `supported` | `04,05,0C,0D` | these PIDs (hex) are in `supportedPids` |
| `neverSent` | `010A,015C` | these commands (with or without hint suffix) never sent |
| `reading` | `RPM 1726 0.5` | param, value, tolerance |
| `milOn` | `true` | |
| `storedDtcs` | `P0133,P0300,P0420` | exact list, order-insensitive; `-` for none |
| `pendingDtcs` | `P0171` | as above |
| `incomplete` | `EVAP` | readiness monitors reported incomplete; `-` for none |
| `alertActive` | `MISFIRE` | this alert is active at the end |
| `trafficContains` | `TIMEOUT` | the TrafficLog export contains this text |

## Files

| File | What it proves |
|---|---|
| `can_clone_v15_normal.elm` | Full init + discovery + hinted polling on a healthy CAN car |
| `can_ble_fragmented.elm` | Same script as the normal session with `@chunk 7`: framing survives replies split mid-line and mid-prompt |
| `ignition_off.elm` | `UNABLE TO CONNECT` → `NO_ECU`, adapter voltage still read |
| `can_faults_multiframe.elm` | CAN multi-frame Mode 03, pending codes, MIL, readiness, misfire alert |
| `kline_iso9141.elm` | Non-CAN: no hint, BUS INIT noise, 3-codes-per-line Mode 03, `NO DATA` on 07 means "none", ATRV fallback, no VIN |
| `clone_quirks.elm` | `?` on optional AT commands, hint rejected, `STOPPED` retry, late reply after timeout not mis-credited |

Values in these fixtures are synthetic but byte-exact; the expected numbers are worked out in each file's comments.
They are not recordings from a real car. Add real recordings under `recorded/` as they are captured (see docs/TESTING-iOS.md §2 (Android: docs/TESTING.md §6)).
Convert an exported traffic log with `.agents/skills/autopal-elm-fixture/scripts/traffic_log_to_elm.py` (the `autopal-elm-fixture` skill describes the steps).
