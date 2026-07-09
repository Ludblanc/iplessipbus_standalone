-- Modified by Delphine Allimann, TCL, 2025

---------------------------------------------------------------------------------
--
--   Copyright 2017 - Rutherford Appleton Laboratory and University of Bristol
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing, software
--   distributed under the License is distributed on an "AS IS" BASIS,
--   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--   See the License for the specific language governing permissions and
--   limitations under the License.
--
--                                     - - -
--
--   Additional information about ipbus-firmare and the list of ipbus-firmware
--   contacts are available at
--
--       https://ipbus.web.cern.ch/ipbus
--
---------------------------------------------------------------------------------
-- Top-level design for ipbus demo
--
-- This version is for ASICs of TCL with 100Mbps RMII interface
-- adapted to be used as component in the top-level design
-- you have a payload side and a network side
--
-- You must edit this file to set the IP and MAC addresses
--


library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.ipbus.all;

entity TCL_rmii_infra is
    generic (
        DHCP_not_RARP : std_logic := '0' -- Default use RARP not DHCP for now...
    );
    port (
        rst_sync_rmii : in std_logic;
        rst_sync_mii  : in std_logic;
        clk_gate_en_rmii : out std_logic; -- to gate the rmii_ref_clk when no valid data is present, to save power
        mii_clk : in std_logic; -- clock gate rmii clock with clk_gate_en_rmii
        rmii_rxd      : in std_logic_vector(1 downto 0); -- RMII interface to ethernet PHY
        rmii_rx_er    : in std_logic;
        rmii_crs_dv   : in std_logic;
        rmii_txd      : out std_logic_vector(1 downto 0);
        rmii_tx_en    : out std_logic;
        rmii_ref_clk  : in std_logic;
        mac_addr      : in std_logic_vector(47 downto 0); -- MAC address
        ip_addr       : in std_logic_vector(31 downto 0); -- IP address
        ipam_select   : in std_logic;                     -- enable RARP or DHCP
        ipb_clk : out std_logic;
        ipb_in        : in ipb_rbus;                      -- ipbus
        ipb_out       : out ipb_wbus
    );

end TCL_rmii_infra;

architecture rtl of TCL_rmii_infra is

    constant BUFWIDTH : integer := 1; -- also works with := 1-- BUFWIDTH determines the number of simultaneous packets in flight supported by the interface, specifically the number of bits in the dual-port RAM address field to select the packet - i.e. the number of simultaneous packets in flight is 2 to the power of BUFWIDTH. The default value is currently 4, giving 16 packets in flight.
    --signal rst125  : std_logic;
    signal ipb_clk_internal : std_logic;
    signal mac_clk : std_logic;
    -- mac data
    signal mac_tx_data, mac_rx_data : std_logic_vector(7 downto 0);
    -- mac control and status signals
    signal mac_tx_valid, mac_tx_last, mac_tx_error, mac_tx_ready, mac_rx_valid, mac_rx_last, mac_rx_error : std_logic;
    -- mac control signals
    --signal mii_rx_clk, mii_rx_dv, mii_rx_er, mii_tx_clk, mii_tx_en, mii_tx_er : std_logic;
    --signal mii_rx_dv, mii_rx_er, mii_clk, mii_tx_en, mii_tx_er : std_logic;
    signal mii_rx_dv, mii_rx_er, mii_tx_en, mii_tx_er : std_logic;
    -- mii data
    signal mii_rxd, mii_txd : std_logic_vector(3 downto 0);
    -- signal rst_mii : std_logic;
    -- component reset_sync
    --     port (
    --         clk_ext_i    : in std_logic;
    --         rst_n_ext_i  : in std_logic;
    --         rst_n_main_o : out std_logic
    --     );
    -- end component;
    component rmii_mii_converter
    port (
        rst : in std_logic;
        rst_mii : in std_logic;
        --MII interface    
        --mii_rx_clk : out std_logic;
        --mii_clk : out std_logic; -- dont forget the generated clock statement
        clk_gate_en_rmii : out std_logic; -- to gate the rmii_ref_clk when no valid data is present, to save power
        mii_rxd    : out std_logic_vector(3 downto 0);
        mii_rx_dv  : out std_logic;
        mii_rx_er  : out std_logic;
        --mii_tx_clk : out std_logic;
        mii_txd    : in  std_logic_vector(3 downto 0);
        mii_tx_en  : in  std_logic;
        mii_tx_er  : in  std_logic;

        --RMII interface    
        rmii_rxd     : in  std_logic_vector(1 downto 0);
        rmii_rx_er   : in  std_logic;
        rmii_crs_dv  : in  std_logic;
        rmii_txd     : out std_logic_vector(1 downto 0);
        rmii_tx_en   : out std_logic;
        rmii_ref_clk : in  std_logic
    );
end component;
--signal rst_mii_n, rst_sync_n_rmii : std_logic;
begin
    -- signals connection
    -- Ethernet MAC core and PHY interface
    -- custom TCL converter to convert between MII and RMII and generate a divided by 2 clock for the MAC
    --rst_mii <= rst_sync_rmii;
    --rst_mii <= not rst_mii_n;
    --mii_rst <= not mii_rst_n;
    --rst_sync_n_rmii <= not rst_sync_rmii;
    -- reset_sync_inst_mii_clk_rst_sync : reset_sync
    -- port map(
    --     clk_ext_i    => mii_clk,
    --     rst_n_ext_i  => rst_sync_n_rmii,
    --     rst_n_main_o => rst_mii_n
    -- );
    converter : rmii_mii_converter
        port map(
            rst         => rst_sync_rmii,
            rst_mii => rst_sync_mii,
            clk_gate_en_rmii     => clk_gate_en_rmii,
            mii_rxd     => mii_rxd,
            mii_rx_dv   => mii_rx_dv,
            mii_rx_er   => mii_rx_er,
            mii_txd     => mii_txd,
            mii_tx_en   => mii_tx_en,
            mii_tx_er   => mii_tx_er,
            rmii_rxd    => rmii_rxd,
            rmii_rx_er  => rmii_rx_er,
            rmii_crs_dv => rmii_crs_dv,
            rmii_txd    => rmii_txd,
            rmii_tx_en  => rmii_tx_en,

            rmii_ref_clk => rmii_ref_clk
        );

    -- mac 
    eth : entity work.eth_mac_mii_merge
        port map(
            clk        => mac_clk,
            rst        => rst_sync_mii,
            mii_rx_clk => mii_clk,
            mii_rxd    => mii_rxd,
            mii_rx_dv  => mii_rx_dv,
            mii_rx_er  => mii_rx_er,
            mii_tx_clk => mii_clk,
            mii_txd    => mii_txd,
            mii_tx_en  => mii_tx_en,
            mii_tx_er  => mii_tx_er,
            tx_data    => mac_tx_data,
            tx_valid   => mac_tx_valid,
            tx_last    => mac_tx_last,
            tx_error   => mac_tx_error,
            tx_ready   => mac_tx_ready,
            rx_data    => mac_rx_data,
            rx_valid   => mac_rx_valid,
            rx_last    => mac_rx_last,
            rx_error   => mac_rx_error
        );

    -- IP -> UDP/ICMP packet processing --> ipbus control logic
    ipb_clk_internal <= mii_clk; -- mii_clk
    ipb_clk <= ipb_clk_internal;
    mac_clk <= mii_clk;--rmii_ref_clk;
    -- The transport layer within ipbus_ctrl entity runs in the Ethernet MAC clock domain, mac_clk, namely 125MHz, with synchronous reset signal
    -- (active high), rst_macclk. The IPbus logic runs in the IPbus clock domain, ipb_clk, typically around 30MHz, with its synchronous reset
    -- (again active high) rst_ipb. There is no fixed frequency or phase relationship between these two clocks, the only requirement being that
    -- ipb_clk is slower.
    ipbus : entity work.ipbus_ctrl
        generic map(
            DHCP_RARP => DHCP_not_RARP,
            BUFWIDTH => BUFWIDTH, -- BUFWIDTH determines the number of simultaneous packets in flight supported by the interface, specifically the number of bits in the dual-port RAM address field to select the packet - i.e. the number of simultaneous packets in flight is 2 to the power of BUFWIDTH. The default value is currently 4, giving 16 packets in flight.
            INTERNALWIDTH => 1 -- INTERNALWIDTH is similarly the number of bits in the address field for ?other? packets (ARP, ping, status etc.). The default value is the minimum, namely 1 (2 packets).
            )
        port map(
            mac_clk         => mac_clk,
            rst_macclk      => rst_sync_mii,
            ipb_clk         => ipb_clk_internal,
            rst_ipb         => rst_sync_mii,
            mac_rx_data     => mac_rx_data,
            mac_rx_valid    => mac_rx_valid,
            mac_rx_last     => mac_rx_last,
            mac_rx_error    => mac_rx_error,
            mac_tx_data     => mac_tx_data,
            mac_tx_valid    => mac_tx_valid,
            mac_tx_last     => mac_tx_last,
            mac_tx_error    => mac_tx_error,
            mac_tx_ready    => mac_tx_ready,
            ipb_out         => ipb_out,
            ipb_in          => ipb_in,
            mac_addr        => mac_addr,
            ip_addr         => ip_addr,
            ipam_select     => ipam_select,
            -- Missing Outputs connected to 'open'
            pkt             => open,
            ipb_req         => open,
            actual_mac_addr => open,
            actual_ip_addr  => open,
            Got_IP_addr     => open,
            pkt_oob         => open,
            --oob_out         => open,
            -- Missing Inputs (See report below for required signals)
            ipb_grant       => '1',          -- Defaulted to '1'
            ipbus_port      => x"C351",      -- Defaulted to 50001
            enable          => '1'          -- Defaulted to '1'
            --oob_in          => (others => ('0', X"00000000", '0'))
        );

end rtl;
