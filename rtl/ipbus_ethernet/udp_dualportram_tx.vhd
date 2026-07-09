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
-- Ludovic Blanc 2026

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.ceil;
use IEEE.math_real.log2;
entity udp_DualPortRAM_tx is
  generic (
    BUFWIDTH  : natural := 0;
    ADDRWIDTH : natural := 0
  );
  port (
    clk      : in std_logic;
    clk125   : in std_logic;
    tx_wea   : in std_logic;
    tx_addra : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 3 downto 0);
    tx_addrb : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);
    tx_dia   : in std_logic_vector(31 downto 0);
    tx_dob   : out std_logic_vector(7 downto 0)
  );
end entity udp_DualPortRAM_tx;

--
architecture v3 of udp_DualPortRAM_tx is
  -- type ram_type is array (2**(BUFWIDTH + ADDRWIDTH - 2) - 1 downto 0) of std_logic_vector (31 downto 0);
  -- signal ram : ram_type;
  -- --attribute block_ram : boolean;
  -- --attribute block_ram of ram : signal is TRUE;
  constant addr_nb_bit                          : positive := BUFWIDTH + ADDRWIDTH - 2;
  signal ram_in1, ram_in2, ram_in3, ram_in4     : std_logic_vector(7 downto 0);
  signal ram_out1, ram_out2, ram_out3, ram_out4 : std_logic_vector(7 downto 0);
  signal bytesel                                : std_logic_vector(1 downto 0);
  signal txa_addr_sram, txb_addr_sram           : std_logic_vector(addr_nb_bit - 1 downto 0);
  --in theory rx and tx dualport ram could have a depth of 1024
  component ipbus_sram_wrapper is
    generic (
      SRAM_NUMWORDS  : positive;
      SRAM_NUMBITS   : positive;
      SRAM_ADDRWIDTH : positive -- 12 = NUMWORD
    );
    port (
      clk          : in std_logic;
      write_enable : in std_logic;
      read_enable  : in std_logic;
      raddr        : in std_logic_vector(SRAM_ADDRWIDTH - 1 downto 0);
      waddr        : in std_logic_vector(SRAM_ADDRWIDTH - 1 downto 0);
      wdata        : in std_logic_vector(SRAM_NUMBITS - 1 downto 0);
      rdata        : out std_logic_vector(SRAM_NUMBITS - 1 downto 0)
    );
  end component;
begin

  -- write : process (clk)
  -- begin
  --   if (rising_edge(clk)) then
  --     if (tx_wea = '1') then
  --       ram(to_integer(unsigned(tx_addra))) <= tx_dia;
  --     end if;
  --   end if;
  -- end process write;

  -- read : process (clk125)
  -- begin
  --   if (rising_edge(clk125)) then
  --     ram_out <= ram(to_integer(unsigned(tx_addrb(BUFWIDTH + ADDRWIDTH - 1 downto 2))))
  --       -- pragma translate_off
  --       after 4 ns
  --       -- pragma translate_on
  --       ;
  --     bytesel <= tx_addrb(1 downto 0)
  --       -- pragma translate_off
  --       after 4 ns
  --       -- pragma translate_on
  --       ;
  --   end if;
  -- end process read;

  -- with bytesel select
  --   tx_dob <= ram_out(31 downto 24) when "00",
  --   ram_out(23 downto 16) when "01",
  --   ram_out(15 downto 8) when "10",
  --   ram_out(7 downto 0) when "11",
  --   (others => '0') when others;

  ram_in1 <= tx_dia(31 downto 24);
  ram_in2 <= tx_dia(23 downto 16);
  ram_in3 <= tx_dia(15 downto 8);
  ram_in4 <= tx_dia(7 downto 0);

  txa_addr_sram <= tx_addra;
  --txa_addr_sram(BUFWIDTH + ADDRWIDTH - 1 downto BUFWIDTH + ADDRWIDTH - 2) <= (others => '0');
  txb_addr_sram <= tx_addrb(BUFWIDTH + ADDRWIDTH - 1 downto 2);
  -- txb_addr_sram(BUFWIDTH + ADDRWIDTH - 1 downto BUFWIDTH + ADDRWIDTH - 2) <= (others => '0');

  bytesel_proc : process (clk125)
  begin
    if (rising_edge(clk125)) then
      bytesel <= tx_addrb(1 downto 0)
        -- pragma translate_off
        after 4 ns
        -- pragma translate_on
        ;
    end if;
  end process bytesel_proc;
  with bytesel select
    tx_dob <= ram_out1 when "00",
    ram_out2 when "01",
    ram_out3 when "10",
    ram_out4 when "11",
    (others => '0') when others;

  ipbus_sram1_wrapper_inst : ipbus_sram_wrapper
  generic map(
    SRAM_NUMWORDS  => 2 ** (addr_nb_bit),
    SRAM_NUMBITS   => 8,
    SRAM_ADDRWIDTH => addr_nb_bit
  )
  port map(
    clk          => clk, -- we assume CLKA is equal to CLK_B in this implementation of rmii
    write_enable => tx_wea,
    read_enable  => '1', -- always read enabled
    raddr        => txb_addr_sram,
    waddr        => txa_addr_sram,
    wdata        => ram_in1,
    rdata        => ram_out1
  );
  ipbus_sram2_wrapper_inst : ipbus_sram_wrapper
  generic map(
    SRAM_NUMWORDS  => 2 ** (addr_nb_bit),
    SRAM_NUMBITS   => 8,
    SRAM_ADDRWIDTH => addr_nb_bit
  )
  port map(
    clk          => clk, -- we assume CLKA is equal to CLK_B in this implementation of rmii
    write_enable => tx_wea,
    read_enable  => '1', -- always read enabled
    raddr        => txb_addr_sram,
    waddr        => txa_addr_sram,
    wdata        => ram_in2,
    rdata        => ram_out2
  );
  ipbus_sram3_wrapper_inst : ipbus_sram_wrapper
  generic map(
    SRAM_NUMWORDS  => 2 ** (addr_nb_bit),
    SRAM_NUMBITS   => 8,
    SRAM_ADDRWIDTH => addr_nb_bit
  )
  port map(
    clk          => clk, -- we assume CLKA is equal to CLK_B in this implementation of rmii
    write_enable => tx_wea,
    read_enable  => '1', -- always read enabled
    raddr        => txb_addr_sram,
    waddr        => txa_addr_sram,
    wdata        => ram_in3,
    rdata        => ram_out3
  );
  ipbus_sram4_wrapper_inst : ipbus_sram_wrapper
  generic map(
    SRAM_NUMWORDS  => 2 ** (addr_nb_bit),
    SRAM_NUMBITS   => 8,
    SRAM_ADDRWIDTH => addr_nb_bit
  )
  port map(
    clk          => clk, -- we assume CLKA is equal to CLK_B in this implementation of rmii
    write_enable => tx_wea,
    read_enable  => '1', -- always read enabled
    raddr        => txb_addr_sram,
    waddr        => txa_addr_sram,
    wdata        => ram_in4,
    rdata        => ram_out4
  );
end architecture v3;
