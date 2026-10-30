---
name: autopal-ble-debug
description: Diagnose Autopal iOS adapter problems on a real iPhone — BLE won't connect, ATZ gets no reply, garbled replies, background disconnects, Wi-Fi adapter or Local Network issues. Use for any CoreBluetooth or Wi-Fi adapter issue.
---

# iOS adapter debugging

Work bottom-up; ask the owner to run hardware steps and share results. You cannot see the phone or the car.

## Known facts (do not re-derive)
- Clone `JINXUSOLU JXSL-MIC34LE`. iOS persona `IOS-VLINK`: service `0x18F0`, notify `0x2AF0`, write `0x2AF1` [Certain].
  Ruled out on iOS: `0xFF12/FF14/FF15` and `e7810a71-…`. GATT names shown by scanners ("Electric Current…") mean nothing.
- iOS cannot use the Classic `ANDROID-VLINK` persona.
- Switching from an Android phone to an iPhone: **unplug the adapter for 5 s and replug** before testing.

## Layer 1 — power
Adapter LED on? Pin 16 to pin 4 ≈ 12.4–12.7 V engine off. Replugged after an Android session?

## Layer 2 — outside our app
nRF Connect (iOS) or LightBlue: connect to `IOS-VLINK` → service `18F0` → **subscribe to `2AF0` first** → write `ATZ\r` (UTF-8) to `2AF1`.
Pass: notification text contains `ELM327`. Screenshot → `docs/evidence/YYYY-MM-DD_T-iBLE-1_<adapter>.png`. Fail → stop: not an app problem.

## Layer 3 — our transport (ask for the exported traffic log)
| Symptom | Likely cause |
|---|---|
| Never reaches "connected" | Bluetooth permission, CBManager state not `.poweredOn` when scanning, wrong peripheral |
| TX then TIMEOUT, no RX | Notifications not enabled, or writing before `didUpdateNotificationStateFor`; wrong pipe |
| Write error "not permitted" | Wrong write type; use the characteristic's supported property |
| Replies split / credited to the wrong command | Framing not waiting for `>`; drain after timeout missing (core bug: fixture first) |
| Works in foreground, stops in background | Missing `bluetooth-central` background mode or state restoration not wired |
| Wi-Fi: connection refused / no route | Phone not on the adapter's Wi-Fi, wrong IP/port, Local Network permission denied |

## Layer 4 — the car
`UNABLE TO CONNECT` = ignition off or not OBD-II; `NO DATA` = unsupported PID. Capture a log → `autopal-elm-fixture`.

Report the failing layer with quoted log lines, the fix or the next owner test (TESTING-iOS IDs), and update STATUS.
