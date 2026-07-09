-- Ludovic Blanc TCL 2026
-- serial interface tcl in parallel of the rmii interface 

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.ipbus.all;

entity serialwrapper is
    port (
        sifclk_i               : in std_logic;
        sifrst_n_i             : in std_logic;
        rmii_rst_n_i           : in std_logic;
        select_ethernet_mode_i : in std_logic;
        sif_sel_i              : in std_logic;
        sdat_i                 : in std_logic;
        sdat_o                 : out std_logic;
        rmii_rxd               : in std_logic_vector(1 downto 0);
        rmii_crsdv             : in std_logic;
        rmii_ref_clk           : in std_logic;
        rmii_txd               : out std_logic_vector(1 downto 0);
        rmii_tx_en             : out std_logic;
        mem_adr_o              : out std_logic_vector(31 downto 0);
        mem_rdat_i             : in std_logic_vector(31 downto 0);
        mem_wdat_o             : out std_logic_vector(31 downto 0);
        mem_req_o              : out std_logic;
        mem_we_o               : out std_logic;
        mem_be_o               : out std_logic_vector(3 downto 0);
        mem_ack_i              : in std_logic;
        selected_sif_clk       : out std_logic
    );
end entity;

architecture rtl of serialwrapper is
    constant rmii_rx_er  : std_logic                     := '0'; -- the selected chip dont have this pin
    constant ENABLE_DHCP : std_logic                     := '0'; -- Default is build with support for RARP rather than DHCP
    constant USE_IPAM    : std_logic                     := '0'; -- Default is no, use static IP address as specified by ip_addr below
    constant MAC_ADDRESS : std_logic_vector(47 downto 0) := X"0060d7c0ffee";-- Careful here, arbitrary addresses do not always work here default to one of EPFL TCL mac address
    constant IP_ADDRESS  : std_logic_vector(31 downto 0) := X"c0a8006f"; -- 192.168.0.111

    signal clk_gate_en_rmii : std_logic; -- to gate the rmii_ref_clk when no valid data is present, to save power
    signal clk_gate_en_rmii_ethernet : std_logic; -- to gate the rmii_ref_clk when no valid data is present, to save power
    signal mii_clk          : std_logic; -- clock gate rmii clock with clk_gate_en_rmii

    signal rmii_rst      : std_logic; -- No reset for now
    signal sif_selected_clock_local : std_logic;
    signal ipb_out       : ipb_wbus;
    signal ipb_in        : ipb_rbus;

    ---
    signal sif_mem_adr_o  : std_logic_vector(31 downto 0);
    signal sif_mem_rdat_i : std_logic_vector(31 downto 0);
    signal sif_mem_wdat_o : std_logic_vector(31 downto 0);
    signal sif_mem_req_o  : std_logic;
    signal sif_mem_we_o   : std_logic;
    signal sif_mem_be_o   : std_logic_vector(3 downto 0);
    signal sif_mem_ack_i  : std_logic;

    signal rmii_mem_adr_o  : std_logic_vector(31 downto 0);
    signal rmii_mem_rdat_i : std_logic_vector(31 downto 0);
    signal rmii_mem_wdat_o : std_logic_vector(31 downto 0);
    signal rmii_mem_req_o  : std_logic;
    signal rmii_mem_we_o   : std_logic;
    signal rmii_mem_be_o   : std_logic_vector(3 downto 0);
    signal rmii_mem_ack_i  : std_logic;

    -- component declarations
    component serialif is
        port (
            clk_i      : in std_logic;
            rst_n_i    : in std_logic;
            sif_sel_i  : in std_logic;
            sdat_i     : in std_logic;
            sdat_o     : out std_logic;
            mem_adr_o  : out std_logic_vector(31 downto 0);
            mem_rdat_i : in std_logic_vector(31 downto 0);
            mem_wdat_o : out std_logic_vector(31 downto 0);
            mem_req_o  : out std_logic;
            mem_we_o   : out std_logic;
            mem_be_o   : out std_logic_vector(3 downto 0);
            mem_ack_i  : in std_logic
        );
    end component serialif;
    --- already used in FLL
    --     module clock_mux2 (
    --     input  logic clk0_i,   // first clock input
    --     input  logic clk1_i,   // second clock input
    --     input  logic clk_sel_i, // clock select signal
    --     output logic clk_o     // output clock
    -- );
    component clock_mux2 is
        port (
            clk0_i    : in std_logic;
            clk1_i    : in std_logic;
            clk_sel_i : in std_logic;
            clk_o     : out std_logic
        );
    end component clock_mux2;
    component ipbus_to_tclserial_if is
        port (
            ipb_clk    : in std_logic;
            ipb_in     : in ipb_wbus; -- ipbus master is the serial interface
            ipb_out    : out ipb_rbus;
            mem_adr_o  : out std_logic_vector(31 downto 0);
            mem_rdat_i : in std_logic_vector(31 downto 0);
            mem_wdat_o : out std_logic_vector(31 downto 0);
            mem_req_o  : out std_logic;
            mem_we_o   : out std_logic;
            mem_be_o   : out std_logic_vector(3 downto 0);
            mem_ack_i  : in std_logic
        );
    end component ipbus_to_tclserial_if;
begin
    rmii_rst <= not rmii_rst_n_i; -- active high reset, invert the active low reset input
    -- Infrastructure
    infra_inst : entity work.TCL_rmii_infra
        generic map(
            DHCP_not_RARP => ENABLE_DHCP
        )
        port map(
            rst_sync_rmii    => rmii_rst,
            clk_gate_en_rmii => clk_gate_en_rmii,
            mii_clk          => mii_clk,
            rmii_rxd         => rmii_rxd,
            rmii_rx_er       => rmii_rx_er,
            rmii_crs_dv      => rmii_crsdv,
            rmii_txd         => rmii_txd,
            rmii_tx_en       => rmii_tx_en,
            rmii_ref_clk     => rmii_ref_clk,
            mac_addr         => MAC_ADDRESS,
            ip_addr          => IP_ADDRESS,
            ipb_clk          => open, -- use directly mii clock 
            ipam_select      => USE_IPAM,
            ipb_in           => ipb_in,
            ipb_out          => ipb_out
        );

    clk_gate_en_rmii_ethernet <= clk_gate_en_rmii when select_ethernet_mode_i = '1' else '0';
    mii_clk_gate_inst : entity work.mii_clk_gate_wrapper
        port map(
            clk_in  => rmii_ref_clk,
            en      => clk_gate_en_rmii_ethernet,
            clk_out => mii_clk
        );
    serialif_inst : serialif
    port map(
        clk_i      => sifclk_i,
        rst_n_i    => sifrst_n_i,
        sif_sel_i  => sif_sel_i,
        sdat_i     => sdat_i,
        sdat_o     => sdat_o,
        mem_adr_o  => sif_mem_adr_o,
        mem_rdat_i => sif_mem_rdat_i,
        mem_wdat_o => sif_mem_wdat_o,
        mem_req_o  => sif_mem_req_o,
        mem_we_o   => sif_mem_we_o,
        mem_be_o   => sif_mem_be_o,
        mem_ack_i  => sif_mem_ack_i
    );


    ipbus_to_tclserial_if_inst : ipbus_to_tclserial_if
    port map(
        ipb_clk    => sif_selected_clock_local,
        ipb_in     => ipb_out, -- ipbus master is the serial interface
        ipb_out    => ipb_in,
        mem_adr_o  => rmii_mem_adr_o,
        mem_rdat_i => rmii_mem_rdat_i,
        mem_wdat_o => rmii_mem_wdat_o,
        mem_req_o  => rmii_mem_req_o,
        mem_we_o   => rmii_mem_we_o,
        mem_be_o   => rmii_mem_be_o,
        mem_ack_i  => rmii_mem_ack_i
    );

    clock_mux2_inst : clock_mux2
    port map(
        clk0_i    => sifclk_i,
        clk1_i    => mii_clk,
        clk_sel_i => select_ethernet_mode_i,
        clk_o     => sif_selected_clock_local
    );

    rmii_mem_rdat_i <= mem_rdat_i when select_ethernet_mode_i = '1' else (others => '0');
    rmii_mem_ack_i  <= mem_ack_i when select_ethernet_mode_i = '1' else '0';
    sif_mem_rdat_i  <= mem_rdat_i when select_ethernet_mode_i = '0' else (others => '0');
    sif_mem_ack_i   <= mem_ack_i when select_ethernet_mode_i = '0' else '0';

    with select_ethernet_mode_i select
        mem_adr_o <= sif_mem_adr_o when '0',
        rmii_mem_adr_o when '1',
        (others=>'X') when others;

    with select_ethernet_mode_i select
        mem_wdat_o <= sif_mem_wdat_o when '0',
        rmii_mem_wdat_o when '1',
        (others=>'X') when others;

    with select_ethernet_mode_i select
        mem_req_o <= sif_mem_req_o when '0',
        rmii_mem_req_o when '1',
        'X' when others;
    with select_ethernet_mode_i select
        mem_we_o <= sif_mem_we_o when '0',
        rmii_mem_we_o when '1',
        'X' when others;
    with select_ethernet_mode_i select
        mem_be_o <= sif_mem_be_o when '0',
        rmii_mem_be_o when '1',
        (others=>'X') when others;

    selected_sif_clk <= sif_selected_clock_local;
end rtl;
