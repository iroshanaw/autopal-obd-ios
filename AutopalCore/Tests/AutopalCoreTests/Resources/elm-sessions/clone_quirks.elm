@name   Clone misbehaviour: rejects optional AT commands, rejects the response-count hint, aborts once, answers late once
@cycles 3
@expect phase LIVE
@expect hintEnabled false
@expect reading RPM 1726 0.5
@expect reading SPEED 50 0
@expect reading COOLANT_TEMP 83 0
@expect trafficContains TIMEOUT

[init]
TX ATZ
RX ATZ\r\r\rELM327 v1.5
TX ATE0
RX ATE0\rOK
# Optional commands answered with "?" must not abort init.
TX ATL0
RX ?
TX ATS0
RX OK
TX ATH0
RX OK
TX ATAT1
RX ?
TX ATSP0
RX OK
TX ATRV
RX ?
TX 0100
RX SEARCHING...\r4100BE3FA813
TX ATDPN
RX A6
TX 0120
RX 41209007B015
TX 0140
RX 4140FED08000
TX 0902
RX NO DATA
TX 0101
RX 41010007E500
TX 03
RX 4300
TX 07
RX 4700
# First hinted poll is rejected. Client must disable the hint for the session
# and resend the SAME PID without it, before moving on.
TX 010C1
RX ?
TX 010C
RX 410C1AF8

[live]
010C => 410C1AF8
# STOPPED once: client retries the same command once after ~100 ms.
010D =>1 STOPPED
010D => 410D32
0111 => 41112E
0104 => 41044D
# Late reply once: arrives 2700 ms after the request, i.e. after the 2500 ms timeout but
# inside the 300 ms drain window. It must be discarded, NOT credited to the next command.
0105 =>1 @delay=2700 41057B
0105 => 41057B
010F => 410F46
0142 => 414236B0
0110 => 411001F4
0106 => 410682
0107 => 410683
012F => 412F80
0146 => 41463C
0101 => 41010007E500
03 => 4300
07 => 4700
