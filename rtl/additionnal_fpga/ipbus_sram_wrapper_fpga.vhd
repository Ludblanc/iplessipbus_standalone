-- Ludovic Blanc & Wenqing Song
-- Copyright (c) TCL 2025
-- ≽^•⩊•^≼ ------------------------------------------------------------------------ ≽^•⩊•^≼ --
-- Description:  Wrapper arround arm sram
-- The objective is to make life easier when changing technology


-- wrapper around : 
--       Instance Name:              sram_2p1024x32m4
--       Words:                      1024
--       Bits:                       32
--       Mux:                        4
--       Drive:                      6
--       Write Mask:                 On
--       Write Thru:                 Off
--       Extra Margin Adjustment:    On
--       Redundany:                  Off
--       Test Muxes                  Off
--       Power Gating:               Off
--       Retention:                  On
--       Pipeline:                   Off
--       Read Disturb Test:	        Off

-- ≽^•⩊•^≼ ------------------------------------------------------------------------ ≽^•⩊•^≼ --

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.ceil;
use IEEE.math_real.log2;

entity ipbus_sram_wrapper is
    generic
    (
        SRAM_NUMWORDS  : positive := 4096;
        SRAM_NUMBITS   : positive := 8;
        SRAM_ADDRWIDTH : positive := integer(ceil(log2(real(4096)))) -- 120 = NUMWORD
    );
    port
    (
        clk          : in std_logic;
        write_enable : in std_logic;
        read_enable  : in std_logic;
        raddr        : in std_logic_vector(SRAM_ADDRWIDTH - 1 downto 0);
        waddr        : in std_logic_vector(SRAM_ADDRWIDTH - 1 downto 0);
        wdata        : in std_logic_vector(SRAM_NUMBITS - 1 downto 0);
        rdata        : out std_logic_vector(SRAM_NUMBITS - 1 downto 0)
    );
end entity;

architecture wrapper_fpga of ipbus_sram_wrapper is
    type ram_type is array (0 to SRAM_NUMWORDS - 1) of std_logic_vector(SRAM_NUMBITS - 1 downto 0);
    signal ram : ram_type;
begin
  write: process (clk)
  begin
    if (rising_edge(clk)) then
      if (write_enable = '1') then
        ram(to_integer(unsigned(waddr))) <= wdata
  -- pragma translate_off
        after 4 ns
  -- pragma translate_on
        ;
      end if;
    end if;
  end process write;

  read: process (clk)
  begin
    if (rising_edge(clk)) then
      rdata <= ram(to_integer(unsigned(raddr)))
  -- pragma translate_off
      after 4 ns
  -- pragma translate_on
      ;
    end if;
  end process read;

end architecture;
