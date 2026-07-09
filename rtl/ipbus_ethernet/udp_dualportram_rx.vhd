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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.ceil;
use IEEE.math_real.log2;
entity udp_DualPortRAM_rx is
  generic (
    BUFWIDTH  : natural := 0;
    ADDRWIDTH : natural := 0
  );
  port (
    clk125   : in std_logic;
    clk      : in std_logic;
    rx_wea   : in std_logic;
    rx_addra : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 1 downto 0);
    rx_addrb : in std_logic_vector(BUFWIDTH + ADDRWIDTH - 3 downto 0);
    rx_dia   : in std_logic_vector(7 downto 0);
    rx_dob   : out std_logic_vector(31 downto 0)
  );
end entity udp_DualPortRAM_rx;

--
architecture striped of udp_DualPortRAM_rx is
  --type ram_type is array (2**(BUFWIDTH + ADDRWIDTH - 2) - 1 downto 0) of std_logic_vector (7 downto 0);
  --signal ram1,ram2, ram3, ram4 : ram_type;
  --attribute block_ram : boolean;
  --attribute block_ram of RAM1 : signal is TRUE;
  --attribute block_ram of RAM2 : signal is TRUE;
  --attribute block_ram of RAM3 : signal is TRUE;
  --attribute block_ram of RAM4 : signal is TRUE;
  constant addr_nb_bit                          : positive := BUFWIDTH + ADDRWIDTH - 2;
  signal ram_out1, ram_out2, ram_out3, ram_out4 : std_logic_vector(7 downto 0);
  component ipbus_sram_wrapper is
    generic (
      SRAM_NUMWORDS  : positive;
      SRAM_NUMBITS   : positive;
      SRAM_ADDRWIDTH : positive -- 120 = NUMWORD
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
  signal write_enable_1, write_enable_2, write_enable_3, write_enable_4 : std_logic;
  signal write_address                                                  : std_logic_vector(BUFWIDTH + ADDRWIDTH - 2 - 1 downto 0);
begin

  -- write: process (clk125)
  -- begin
  --   if (rising_edge(clk125)) then
  --     if (rx_wea = '1') then
  --       case rx_addra(1 downto 0) is
  --         when "00" =>
  --           ram4(to_integer(unsigned(rx_addra(BUFWIDTH + ADDRWIDTH - 1 downto 2)))) <= rx_dia;
  --         when "01" =>
  --           ram3(to_integer(unsigned(rx_addra(BUFWIDTH + ADDRWIDTH - 1 downto 2)))) <= rx_dia;
  --         when "10" =>
  --           ram2(to_integer(unsigned(rx_addra(BUFWIDTH + ADDRWIDTH - 1 downto 2)))) <= rx_dia;
  --         when "11" =>
  --           ram1(to_integer(unsigned(rx_addra(BUFWIDTH + ADDRWIDTH - 1 downto 2)))) <= rx_dia;
  --         when others =>
  --         	null;
  --       end case;
  --     end if;
  --   end if;
  -- end process write;

  -- read: process (clk)
  --   variable byte1, byte2, byte3, byte4 : std_logic_vector (7 downto 0);
  -- begin
  --   if (rising_edge(clk)) then
  --     byte4 := ram4(to_integer(unsigned(rx_addrb)));
  --     byte3 := ram3(to_integer(unsigned(rx_addrb)));
  --     byte2 := ram2(to_integer(unsigned(rx_addrb)));
  --     byte1 := ram1(to_integer(unsigned(rx_addrb)));

  --   end if;
  -- end process read;

  rx_dob <= ram_out4 & ram_out3 & ram_out2 & ram_out1;

  write_address <= rx_addra(BUFWIDTH + ADDRWIDTH - 1 downto 2);

  write_enable_1 <= '1' when rx_addra(1 downto 0) = "11" and rx_wea = '1' else
    '0';
  write_enable_2 <= '1' when rx_addra(1 downto 0) = "10" and rx_wea = '1' else
    '0';
  write_enable_3 <= '1' when rx_addra(1 downto 0) = "01" and rx_wea = '1' else
    '0';
  write_enable_4 <= '1' when rx_addra(1 downto 0) = "00" and rx_wea = '1' else
    '0';

  ipbus_sram1_wrapper_inst : ipbus_sram_wrapper
  generic map(
    SRAM_NUMWORDS  => 2 ** (addr_nb_bit),
    SRAM_NUMBITS   => 8,
    SRAM_ADDRWIDTH => addr_nb_bit
  )
  port map(
    clk          => clk, -- we assume CLKA is equal to CLK_B in this implementation of rmii
    write_enable => write_enable_1,
    read_enable  => '1', -- always read enabled
    raddr        => rx_addrb,
    waddr        => write_address,
    wdata        => rx_dia,
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
    write_enable => write_enable_2,
    read_enable  => '1', -- always read enabled
    raddr        => rx_addrb,
    waddr        => write_address,
    wdata        => rx_dia,
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
    write_enable => write_enable_3,
    read_enable  => '1', -- always read enabled
    raddr        => rx_addrb,
    waddr        => write_address,
    wdata        => rx_dia,
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
    write_enable => write_enable_4,
    read_enable  => '1', -- always read enabled
    raddr        => rx_addrb,
    waddr        => write_address,
    wdata        => rx_dia,
    rdata        => ram_out4
  );

end architecture striped;
