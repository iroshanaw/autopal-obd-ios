@name   CAN car with check-engine light on: 3 stored codes (multi-frame reply), 1 pending, lean fuel trim
@cycles 2
@expect phase LIVE
@expect isCan true
@expect milOn true
@expect storedDtcs P0133,P0300,P0420
@expect pendingDtcs P0171
@expect incomplete EVAP
@expect alertActive MISFIRE
@expect reading LONG_FUEL_TRIM_B1 23.4 0.1

[init]
TX ATZ
RX ATZ\r\r\rELM327 v1.5
TX ATE0
RX ATE0\rOK
TX ATL0
RX OK
TX ATS0
RX OK
TX ATH0
RX OK
TX ATAT1
RX OK
TX ATSP0
RX OK
TX ATRV
RX 14.1V
TX 0100
RX SEARCHING...\r4100BE3FA813
TX ATDPN
RX A6
TX 0120
RX 41209007B015
TX 0140
RX 4140FED08000
TX 0902
RX 014\r0:490201314847\r1:434D3832363333\r2:41303034333532
# 0101: A=83 -> MIL on (bit 7), 3 stored codes.  B=07 spark.  C=E5 available.  D=04 -> EVAP incomplete (bit 2).
TX 0101
RX 41018307E504
# Mode 03 on CAN: 43 <count> then 2 bytes per code. 8 bytes total -> multi-frame.
#   43 03 | 01 33 -> P0133 | 03 00 -> P0300 | 04 20 -> P0420.  Frame 1 padding (AA) is beyond the declared length.
TX 03
RX 008\r0:430301330300\r1:0420AAAAAAAAAA
# Mode 07 on CAN, single frame: 47 01 | 01 71 -> P0171 (system too lean, bank 1)
TX 07
RX 47010171

[live]
010C1 => 410C0C80
# 0x0C80 = 3200/4 = 800 rpm idle
010D1 => 410D00
01111 => 41110F
01041 => 410440
01051 => 410582
# 0x82 = 130 - 40 = 90 C (warm, closed loop). TRIM_LEAN_RICH needs 60 s sustained, so it is NOT expected
# within 2 cycles; that timing is covered by alert_scenarios.csv instead.
010F1 => 410F44
01421 => 41423714
01101 => 41100190
01061 => 41068A
01071 => 41079E
# (158-128)*100/128 = 23.44 % : lean, consistent with P0171 and a vacuum leak
012F1 => 412F99
01461 => 41463C
0101 => 41018307E504
03 => 008\r0:430301330300\r1:0420AAAAAAAAAA
07 => 47010171
