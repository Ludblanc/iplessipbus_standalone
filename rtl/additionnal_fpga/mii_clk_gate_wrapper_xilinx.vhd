library ieee;
use ieee.std_logic_1164.all;

entity mii_clk_gate_wrapper is
    port (
        clk_in  : in  std_logic;
        en      : in  std_logic;
        clk_out : out std_logic
    );
end entity mii_clk_gate_wrapper;

architecture rtl of mii_clk_gate_wrapper is
begin
    -- Instantiation of Xilinx clock gate using BUFGCE
    clk_bufg_inst : BUFGCE
        port map (
            I  => clk_in,  -- Input clock
            CE => en,      -- Enable signal
            O  => clk_out  -- Gated output clock
        );
end architecture rtl;