-- Ludovic Blanc & Wenqing Song & ᘛ⁐̤ᕐᐷ
-- Copyright (c) TCL 2025
-- ≽^•⩊•^≼ ------------------------------------------------------------------------ ≽^•⩊•^≼ --
-- Description: convert the tcl "legacy" serial interface to ipbus (on-chip bus) compatible signals

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.ipbus.all;

-- for ipbus need to maintain the we (strobe) until an acknowledge is received, this removes the burst functionality
-- change, sif rdata should not change before next read op.
entity bridge_ipbus_tclsif is
    port
    (
        rst_n_ext_i : in std_logic; -- external reset
        sif_clk_i   : in std_logic; -- serial interface clock (Maybe later use one from FLL?)
        sif_adr     : in std_logic_vector(31 downto 0);
        sif_rdat    : out std_logic_vector(31 downto 0);
        sif_wdat    : in std_logic_vector(31 downto 0);
        sif_req     : in std_logic;
        sif_we      : in std_logic; -- write enable
        sif_ack     : out std_logic;
        ipb_write   : out ipb_wbus; -- ipbus write
        ipb_read    : in ipb_rbus   -- ipbus read
    );
end entity bridge_ipbus_tclsif;

architecture behabvioral of bridge_ipbus_tclsif is
    signal ipbus_write_next, ipbus_write_present : ipb_wbus;
    type fsm_state_t is (IDLE, DIRECT_ACKNOWLEDGE, WAIT_ACKNOWLEDGE);
    signal fsm_present, fsm_next : fsm_state_t;
    signal sif_rdat_reg : std_logic_vector(31 downto 0);
begin

    register_input : process (sif_clk_i, rst_n_ext_i)
    begin
        if rst_n_ext_i = '0' then
            ipbus_write_present <= IPB_WBUS_NULL;
            fsm_present         <= IDLE;
            sif_rdat_reg <= (others => '0');
        elsif rising_edge(sif_clk_i) then
            ipbus_write_present <= ipbus_write_next;
            fsm_present         <= fsm_next;
            if ipb_read.ipb_ack = '1' then
                sif_rdat_reg <= ipb_read.ipb_rdata;
            end if;
        end if;

    end process register_input;

    comb_process : process (all)
    begin
        sif_ack          <= '0';
        ipbus_write_next <= ipbus_write_present;
        fsm_next         <= fsm_present;
        case fsm_present is
            when IDLE =>
                if sif_req = '1' then
                    ipbus_write_next.ipb_addr   <= sif_adr;
                    ipbus_write_next.ipb_wdata  <= sif_wdat;
                    ipbus_write_next.ipb_strobe <= '1';
                    ipbus_write_next.ipb_write  <= sif_we;
                    fsm_next                    <= WAIT_ACKNOWLEDGE;
                end if;

            when WAIT_ACKNOWLEDGE =>
                ipbus_write_next.ipb_strobe <= '1';
                if ipb_read.ipb_ack = '1' then
                    ipbus_write_next.ipb_strobe <= '0';
                    sif_ack                     <= '1';
                    if sif_req = '1' then
                    ipbus_write_next.ipb_addr   <= sif_adr;
                    ipbus_write_next.ipb_wdata  <= sif_wdat;
                    ipbus_write_next.ipb_strobe <= '1';
                    ipbus_write_next.ipb_write  <= sif_we;
                    fsm_next                    <= WAIT_ACKNOWLEDGE;
                    else -- sif_req = 0
                        fsm_next <= IDLE;
                    end if;
                end if;

            when others => null;
        end case;
    end process comb_process;

    sif_rdat  <= ipb_read.ipb_rdata when ipb_read.ipb_ack = '1' else sif_rdat_reg;
    ipb_write <= ipbus_write_present;

end architecture behabvioral;
