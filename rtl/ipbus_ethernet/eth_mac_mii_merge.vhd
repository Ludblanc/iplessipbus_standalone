
-- Copyright (c) 2025 Ludovic Damien Blanc
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--- verilog ethernet wrapper
-- Author: Delphine Allimann, maintained by Ludovic Damien Blanc
-- EPFL - TCL 2025

library ieee;
use ieee.std_logic_1164.all;

entity eth_mac_mii_merge is
	port(
		clk    : in std_logic;
		rst:    in std_logic;

        mii_rx_clk : in  std_logic;
        mii_rxd    : in  std_logic_vector(3 downto 0);
        mii_rx_dv  : in  std_logic;
        mii_rx_er  : in  std_logic;
        mii_tx_clk : in  std_logic;
        mii_txd    : out std_logic_vector(3 downto 0);
        mii_tx_en  : out std_logic;
        mii_tx_er  : out std_logic;
		tx_data:  in  std_logic_vector(7 downto 0);
		tx_valid: in  std_logic;
		tx_last:  in  std_logic;
		tx_error: in  std_logic;
		tx_ready: out std_logic;
		rx_data:  out std_logic_vector(7 downto 0);
		rx_valid: out std_logic;
		rx_last:  out std_logic;
		rx_error: out std_logic;
		status:   out std_logic_vector(3 downto 0)
	);

end eth_mac_mii_merge;

architecture rtl of eth_mac_mii_merge is 

signal rx_clk : std_logic;
    signal rx_rst : std_logic;
    signal tx_clk : std_logic;
    signal tx_rst : std_logic;

    component eth_mac_mii is
        generic(
            TARGET : string := "GENERIC";
            CLOCK_INPUT_STYLE : string := "BUFIO2";
            ENABLE_PADDING : integer := 1;
            MIN_FRAME_LENGTH : integer := 64
        );
        port(
            rst : in std_logic;
            rx_clk : out std_logic;
            rx_rst : out std_logic;
            tx_clk : out std_logic;
            tx_rst : out std_logic;
            tx_axis_tdata : in std_logic_vector(7 downto 0);
            tx_axis_tvalid : in std_logic;
            tx_axis_tready : out std_logic;
            tx_axis_tlast : in std_logic;
            tx_axis_tuser : in std_logic;
            rx_axis_tdata : out std_logic_vector(7 downto 0);
            rx_axis_tvalid : out std_logic;
            rx_axis_tlast : out std_logic;
            rx_axis_tuser : out std_logic;
            mii_rx_clk : in std_logic;
            mii_rxd : in std_logic_vector(3 downto 0);
            mii_rx_dv : in std_logic;
            mii_rx_er : in std_logic;
            mii_tx_clk : in std_logic;
            mii_txd : out std_logic_vector(3 downto 0);
            mii_tx_en : out std_logic;
            mii_tx_er : out std_logic;
            tx_start_packet : out std_logic;
            tx_error_underflow : out std_logic;
            rx_start_packet : out std_logic;
            rx_error_bad_frame : out std_logic;
            rx_error_bad_fcs : out std_logic;
            cfg_ifg : in std_logic_vector(7 downto 0);
            cfg_tx_enable : in std_logic;
            cfg_rx_enable : in std_logic
        );
    end component;
    signal rx_error_bf : std_logic;
    signal rx_error_fcs : std_logic;
    
begin

    rx_error <= rx_error_bf or rx_error_fcs;
    
    eth_mac_inst : eth_mac_mii
    generic map(
            TARGET => "GENERIC",
            CLOCK_INPUT_STYLE => "BUFR", 
            MIN_FRAME_LENGTH => 64
        )
        port map( 
            rst         => rst,
            rx_clk     => open,
            rx_rst   => open,
            tx_clk     => open,
            tx_rst   => open,

            tx_axis_tdata   => tx_data,
            tx_axis_tvalid  => tx_valid,
            tx_axis_tready  => tx_ready,
            tx_axis_tlast   => tx_last,
            tx_axis_tuser   => '0',

            rx_axis_tdata   => rx_data,
            rx_axis_tvalid  => rx_valid,
            --rx_axis_tready  => '1',
            rx_axis_tlast   => rx_last,

            mii_rx_clk      => mii_rx_clk,
            mii_rxd         => mii_rxd,
            mii_rx_dv       => mii_rx_dv,
            mii_rx_er       => mii_rx_er,
            mii_tx_clk      => mii_tx_clk,
            mii_txd         => mii_txd,
            mii_tx_en       => mii_tx_en,
            mii_tx_er       => mii_tx_er,
            cfg_ifg         => X"0C",
            cfg_tx_enable   => '1',
            cfg_rx_enable   => '1',
            rx_error_bad_frame => rx_error_bf,
            rx_error_bad_fcs => rx_error_fcs
        );
end rtl;