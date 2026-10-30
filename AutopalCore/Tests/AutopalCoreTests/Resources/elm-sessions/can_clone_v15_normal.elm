@name   Healthy 2015 petrol car, ISO 15765-4 CAN 11-bit 500k, clone ELM327 v1.5
@cycles 2
@expect phase LIVE
@expect adapterVersion ELM327 v1.5
@expect protocol A6
@expect isCan true
@expect hintEnabled true
@expect vin 1HGCM82633A004352
@expect supported 04,05,06,07,0C,0D,0F,10,11,2F,42,46
@expect neverSent 010A,015C
@expect reading RPM 1726 0.5
@expect reading SPEED 50 0
@expect reading THROTTLE 18.0 0.1
@expect reading ENGINE_LOAD 30.2 0.1
@expect reading COOLANT_TEMP 83 0
@expect reading INTAKE_TEMP 30 0
@expect reading CONTROL_MODULE_VOLTAGE 14.0 0.01
@expect reading MAF 5.0 0.01
@expect reading SHORT_FUEL_TRIM_B1 1.6 0.1
@expect reading LONG_FUEL_TRIM_B1 2.3 0.1
@expect reading FUEL_LEVEL 50.2 0.1
@expect reading AMBIENT_TEMP 20 0
@expect reading ADAPTER_VOLTAGE 14.2 0.01
@expect milOn false
@expect storedDtcs -
@expect pendingDtcs -
@expect incomplete -

[init]
# Echo is ON after reset, so ATZ and ATE0 replies start with the echoed command.
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
RX 14.2V
# Supported 01-20: BE 3F A8 13
#   BE = 1011 1110 -> 01,03,04,05,06,07
#   3F = 0011 1111 -> 0B,0C,0D,0E,0F,10      (0A fuel pressure NOT supported)
#   A8 = 1010 1000 -> 11,13,15
#   13 = 0001 0011 -> 1C,1F,20               (20 set -> query 0120)
TX 0100
RX SEARCHING...\r4100BE3FA813
TX ATDPN
RX A6
# Supported 21-40: 90 07 B0 15
#   07 = 0000 0111 -> 2E,2F,30   (2F fuel level supported)
#   15 = 0001 0101 -> 3C,3E,40   (40 set -> query 0140)
TX 0120
RX 41209007B015
# Supported 41-60: FE D0 80 00
#   FE -> 41..47 (42 voltage, 46 ambient)   D0 -> 49,4A,4C   80 -> 51   00 -> (5C oil NOT supported, 60 not set -> stop)
TX 0140
RX 4140FED08000
# VIN, CAN multi-frame: 0x014 = 20 bytes = 49 02 01 + 17 ASCII chars "1HGCM82633A004352"
TX 0902
RX 014\r0:490201314847\r1:434D3832363333\r2:41303034333532
# 0101: A=00 MIL off, 0 codes. B=07 spark, misfire/fuel/components available + complete.
#       C=E5 available: catalyst, EVAP, O2, O2 heater, EGR.  D=00 all complete.
TX 0101
RX 41010007E500
TX 03
RX 4300
TX 07
RX 4700

[live]
# CAN -> response-count hint "1" appended to Mode 01 data PIDs.
010C1 => 410C1AF8
# 0x1AF8 = 6904 / 4 = 1726 rpm
010D1 => 410D32
# 0x32 = 50 km/h
01111 => 41112E
# 0x2E = 46 * 100/255 = 18.04 %
01041 => 41044D
# 0x4D = 77 * 100/255 = 30.20 %
01051 => 41057B
# 0x7B = 123 - 40 = 83 C
010F1 => 410F46
# 0x46 = 70 - 40 = 30 C
01421 => 414236B0
# 0x36B0 = 14000 / 1000 = 14.0 V
01101 => 411001F4
# 0x01F4 = 500 / 100 = 5.00 g/s
01061 => 410682
# (130-128)*100/128 = 1.56 %
01071 => 410683
# (131-128)*100/128 = 2.34 %
012F1 => 412F80
# 128 * 100/255 = 50.20 %
01461 => 41463C
# 60 - 40 = 20 C
0101 => 41010007E500
03 => 4300
07 => 4700
