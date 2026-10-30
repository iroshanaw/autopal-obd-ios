@name   Adapter powered from pin 16, ignition OFF: adapter answers, no ECU does
@cycles 0
@expect phase NO_ECU
@expect adapterVersion ELM327 v1.5
@expect reading ADAPTER_VOLTAGE 12.4 0.01
@expect neverSent ATDPN,0120,0902,010C,010C1
@expect trafficContains UNABLE TO CONNECT

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
RX 12.4V
TX 0100
RX SEARCHING...\rUNABLE TO CONNECT

[live]
# In NO_ECU the client retries 0100 every 10 s and keeps reading adapter voltage.
0100 => SEARCHING...\rUNABLE TO CONNECT
ATRV => 12.4V
