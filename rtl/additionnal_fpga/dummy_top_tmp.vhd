-- Ludovic Blanc TCL 2026
-- minimal toplevel with infra and payload to check synthesis and fpga with minimal clocks

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.ipbus.all;

entity top is
    port (
        rmii_rxd     : in std_logic_vector(1 downto 0);
        rmii_crs_dv  : in std_logic;
        rmii_txd     : out std_logic_vector(1 downto 0);
        rmii_tx_en   : out std_logic;
        rmii_ref_clk : in std_logic

    );
end top;

architecture rtl of top is
    signal mac_addr : std_logic_vector(47 downto 0);
    signal ip_addr  : std_logic_vector(31 downto 0);
    signal ipb_clk_local : std_logic;
    signal ipb_clk      : std_logic;
    signal ipb_out  : ipb_wbus;
    signal ipb_in   : ipb_rbus;
    constant rmii_rx_er  : std_logic                     := '0'; -- the selected chip dont have this pin
    constant ENABLE_DHCP : std_logic                     := '0'; -- Default is build with support for RARP rather than DHCP
    constant USE_IPAM    : std_logic                     := '0'; -- Default is no, use static IP address as specified by ip_addr below
    constant MAC_ADDRESS : std_logic_vector(47 downto 0) := X"0060d7c0ffee";-- Careful here, arbitrary addresses do not always work here default to one of EPFL TCL mac address
    constant IP_ADDRESS  : std_logic_vector(31 downto 0) := X"c0a8006f"; -- 192.168.0.111
    constant rst         : std_logic                     := '0';         -- No reset for now, tie low

    component payload is
    port(
        ipb_clk: in std_logic;
        ipb_rst: in std_logic;
        ipb_in: in ipb_wbus;
        ipb_out: out ipb_rbus;
        clk: in std_logic;
        rst: in std_logic;
        nuke: out std_logic;
        soft_rst: out std_logic;
        userled: out std_logic
    );
    end component;

    signal clk_gate_en_rmii : std_logic; -- to gate the rmii_ref_clk when no valid data is present, to save power
    signal mii_clk : std_logic; -- clock gate rmii clock with clk_gate_en_rmii
begin
    ipb_clk <= ipb_clk_local;
    -- Infrastructure
    infra_inst : entity work.TCL_rmii_infra
        generic map(
            DHCP_not_RARP => ENABLE_DHCP
        )
        port map(
            rst_sync_rmii => rst,
            clk_gate_en_rmii => clk_gate_en_rmii,
            mii_clk => mii_clk,
            rmii_rxd      => rmii_rxd,
            rmii_rx_er    => rmii_rx_er,
            rmii_crs_dv   => rmii_crs_dv,
            rmii_txd      => rmii_txd,
            rmii_tx_en    => rmii_tx_en,
            rmii_ref_clk  => rmii_ref_clk,
            mac_addr      => MAC_ADDRESS,
            ip_addr       => IP_ADDRESS,
            ipb_clk       => ipb_clk_local,
            ipam_select   => USE_IPAM,
            ipb_in        => ipb_in,
            ipb_out       => ipb_out
        );

    mii_clk_gate_inst : entity work.mii_clk_gate_wrapper
        port map(
            clk_in => rmii_ref_clk,
            en     => clk_gate_en_rmii,
            clk_out => mii_clk
        );

    payload_inst : payload
        port map(
            ipb_clk  => ipb_clk_local,
            ipb_rst  => rst,
            ipb_in   => ipb_out,
            ipb_out  => ipb_in,
            clk      => rmii_ref_clk,
            rst      => rst,
            nuke     => open,
            soft_rst => open,
            userled  => open
        );

end rtl;
