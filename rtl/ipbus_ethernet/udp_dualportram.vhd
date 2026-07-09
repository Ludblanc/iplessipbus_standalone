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

entity udp_DualPortRAM is
  generic (
    BUFWIDTH  : natural := 0;
    ADDRWIDTH : natural := 0
  );
  port (
    ClkA  : in std_logic;
    ClkB  : in std_logic;
    wea   : in std_logic;
    addra : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);
    addrb : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);
    dia   : in std_logic_vector(7 downto 0);
    dob   : out std_logic_vector(7 downto 0)
  );
end entity udp_DualPortRAM;

--
architecture rtl of udp_DualPortRAM is

  component ipbus_sram_wrapper is
    generic (
      SRAM_NUMWORDS  : positive := 4096;
      SRAM_NUMBITS   : positive := 8;
      SRAM_ADDRWIDTH : positive := integer(ceil(log2(real(4096)))) -- 120 = NUMWORD
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
ipbus_sram_wrapper_inst: ipbus_sram_wrapper
 port map(
    clk => ClkA, -- we assume CLKA is equal to CLK_B in this implementation of rmii
    write_enable => wea,
    read_enable => '1', -- always read enabled
    raddr => addrb,
    waddr => addra,
    wdata => dia,
    rdata => dob
);
  -- type ram_type is array (2**(BUFWIDTH + ADDRWIDTH) - 1 downto 0) of std_logic_vector (7 downto 0);
  -- signal ram : ram_type;
  -- --attribute block_ram : boolean;
  -- --attribute block_ram of RAM : signal is TRUE;
  -- BEGIN

  -- write: process (ClkA)
  -- begin
  --   if (rising_edge(ClkA)) then
  --     if (wea = '1') then
  --       ram(to_integer(unsigned(addra))) <= dia
  -- -- pragma translate_off
  --       after 4 ns
  -- -- pragma translate_on
  --       ;
  --     end if;
  --   end if;
  -- end process write;

  -- read: process (ClkB)
  -- begin
  --   if (rising_edge(ClkB)) then
  --     dob <= ram(to_integer(unsigned(addrb)))
  -- -- pragma translate_off
  --     after 4 ns
  -- -- pragma translate_on
  --     ;
  --   end if;
  -- end process read;
end architecture rtl;
