@name   Older car on ISO 9141-2 (K-Line, pin 7): slow protocol search, no CAN features, no VIN, no 0142
@cycles 2
@expect phase LIVE
@expect protocol A3
@expect isCan false
@expect hintEnabled false
@expect vin null
@expect neverSent 010C1,010D1,0142,01421,0110,01101
@expect reading RPM 750 0.5
@expect reading COOLANT_TEMP 50 0
@expect reading FUEL_LEVEL 25.1 0.1
@expect reading ADAPTER_VOLTAGE 13.9 0.01
@expect milOn true
@expect storedDtcs P0133,P0171
@expect pendingDtcs -

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
RX 13.9V
# K-Line search prints BUS INIT noise before the data. It must be stripped, not treated as an error.
# Supported 01-20: BE 3E B8 11
#   3E = 0011 1110 -> 0B..0F  (10 MAF NOT supported)
#   B8 = 1011 1000 -> 11,13,14,15
#   11 = 0001 0001 -> 1C,20
TX 0100
RX SEARCHING...\rBUS INIT: ...OK\r4100BE3EB811
TX ATDPN
RX A3
# Supported 21-40: 80 02 80 00 -> 21, 2F, 31.  40 not set -> stop. So 0142 is unsupported -> ATRV is the voltage source.
TX 0120
RX 412080028000
# Many pre-2008 cars do not support VIN over Mode 09.
TX 0902
RX NO DATA
# 0101: A=82 -> MIL on, 2 codes.
TX 0101
RX 41018207E500
# Non-CAN Mode 03: no count byte, 3 codes per line, zero padded -> P0133, P0171
TX 03
RX 43013301710000
# NO DATA on Mode 07 means "no pending codes", not an error.
TX 07
RX NO DATA

[live]
# Not CAN -> no response-count hint.
010C => 410C0BB8
# 0x0BB8 = 3000/4 = 750 rpm
010D => 410D00
0111 => 411114
0104 => 410433
0105 => 41055A
# 90 - 40 = 50 C (still warming up)
010F => 410F3C
0106 => 41067E
0107 => 410780
012F => 412F40
# 64 * 100/255 = 25.10 %
ATRV => 13.9V
0101 => 41018207E500
03 => 43013301710000
07 => NO DATA
