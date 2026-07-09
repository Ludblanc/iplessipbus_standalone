# Ludovic Blanc
# © 2026 TCL EPFL

###########################################################################
# RMII (LAN8720A) Timing Constraints
# Source: Datasheet RMII Timing (REF_CLK OUT Mode), page 71
# https://www.waveshare.com/w/upload/1/1a/LAN8720A.pdf
# Key signals:
#   TX: FPGA -> PHY  (TXD[1:0], TXEN)
#   RX: PHY  -> FPGA (RXD[1:0], CRS_DV)
#
# Clock: 50 MHz (20 ns period)
###########################################################################

##############################
# USER CONFIGURABLE MARGINS
##############################
# Positive margin = more conservative
# Applied as:
#   max_delay = datasheet_max + MARGIN_MAX
#   min_delay = datasheet_min - MARGIN_MIN

set MARGIN_MAX 0.5
set MARGIN_MIN 0.5


##############################
# CONSTANTS FROM DATASHEET
##############################

# Clock
set RMII_CLK_PERIOD 20.000

# --- TX (FPGA -> PHY) ---
# tsu   = 7.0 ns  (setup to rising edge)
# tihold= 2.0 ns  (hold after rising edge)

set RMII_TX_TSU     7.0
set RMII_TX_THOLD   2.0

# --- RX (PHY -> FPGA) ---
# toval  = 10.0 ns (clock-to-output max)
# tohold = 1.4 ns  (output hold)

set RMII_RX_TOVAL   10.0
set RMII_RX_TOHOLD  1.4


##############################
# ASCII TIMING DIAGRAM
##############################
#
#                |<------ 20 ns ------>|
# REF_CLK   ____/‾‾‾‾\____/‾‾‾‾\____
#              ↑
#              | rising edge (reference)
#
# RX (PHY -> FPGA):
#                |<--- toval --->|
# RXD        XXXX=========VALID=========
#                         |<--tohold-->|
#
# TX (FPGA -> PHY):
#                |<--- tsu --->|
# TXD        ========VALID====XXXX
#                         |<-tihold->|
#
# Interpretation:
#  - RX: data becomes valid AFTER clock edge (input delay)
#  - TX: data must be valid BEFORE clock edge (output delay)
#

##############################
# TIMING TABLE (FROM DATASHEET)
##############################
#
# +--------+-------------------------------+-------+------+
# | Symbol | Description                   |  Min  | Max  |
# +--------+-------------------------------+-------+------+
# | tsu    | TX setup time                 | 7.0   |  -   |
# | tihold | TX hold time                  | 2.0   |  -   |
# | toval  | RX valid after clock          |  -    | 10.0 |
# | tohold | RX hold after clock           | 1.4   |  -   |
# +--------+-------------------------------+-------+------+
#

##############################
# CLOCK DEFINITION
##############################

create_clock -period $RMII_CLK_PERIOD \
             -name rmii_clk \
             [get_ports rmii_ref_clk]

# Optional: keep uncertainty parametric
set CLOCK_UNCERTAINTY [expr 0.1 * $RMII_CLK_PERIOD]

set_clock_uncertainty -setup $CLOCK_UNCERTAINTY [get_clocks rmii_clk]
set_clock_uncertainty -hold  $CLOCK_UNCERTAINTY [get_clocks rmii_clk]


##############################
# OUTPUT DELAY (FPGA -> PHY)
##############################
#
# Constraint derivation:
#   max = tsu  (+ margin)
#   min = -tihold (- margin)
#
# NOTE:
#   min is NEGATIVE because hold is AFTER clock edge
#

set_output_delay -clock rmii_clk \
    -max [expr $RMII_TX_TSU + $MARGIN_MAX] \
    [get_ports {rmii_tx_en {rmii_txd[*]}}]

set_output_delay -clock rmii_clk \
    -min [expr -$RMII_TX_THOLD - $MARGIN_MIN] \
    [get_ports {rmii_tx_en {rmii_txd[*]}}]


##############################
# INPUT DELAY (PHY -> FPGA)
##############################
#
# Constraint derivation:
#   max = toval (+ margin)
#   min = tohold (- margin)
#

set_input_delay -clock rmii_clk \
    -max [expr $RMII_RX_TOVAL + $MARGIN_MAX] \
    [get_ports {rmii_crs_dv {rmii_rxd[*]}}]

set_input_delay -clock rmii_clk \
    -min [expr $RMII_RX_TOHOLD - $MARGIN_MIN] \
    [get_ports {rmii_crs_dv {rmii_rxd[*]}}]
