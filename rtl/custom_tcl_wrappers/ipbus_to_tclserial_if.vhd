-- TCL specific IP

-- Ludovic Blanc 2026

library ieee;
use ieee.std_logic_1164.all;
use work.ipbus.all;

entity ipbus_to_tclserial_if is
    port (
        ipb_clk    : in std_logic;
        ipb_in     : in ipb_wbus;
        ipb_out    : out ipb_rbus;
        mem_adr_o  : out std_logic_vector(31 downto 0);
        mem_rdat_i : in std_logic_vector(31 downto 0);
        mem_wdat_o : out std_logic_vector(31 downto 0);
        mem_req_o  : out std_logic;
        mem_we_o   : out std_logic;
        mem_be_o   : out std_logic_vector(3 downto 0);
        mem_ack_i  : in std_logic
    );
end entity ipbus_to_tclserial_if;

architecture dummy of ipbus_to_tclserial_if is
    signal req_local : std_logic;
    signal ipbus_request_prev : std_logic;
    signal acknowledge_prev : std_logic;
begin
    clock_process : process(ipb_clk)
    begin -- add reset?
        if rising_edge(ipb_clk) then
            ipbus_request_prev <= ipb_in.ipb_strobe;
            acknowledge_prev <= mem_ack_i;
        end if;
    end process clock_process;


    ipb_out.ipb_ack <= (mem_ack_i and not acknowledge_prev) or (mem_ack_i and acknowledge_prev and ipb_in.ipb_strobe); -- only one clock cycle except if we restart a second transaction immediately after the first one completes, in which case we keep ipb_out.ipb_ack high for the second transaction
    ipb_out.ipb_err <= '0';
    ipb_out.ipb_rdata <= mem_rdat_i;

    mem_adr_o <= ipb_in.ipb_addr;
    mem_wdat_o <= ipb_in.ipb_wdata;
    req_local <= (ipb_in.ipb_strobe and not ipbus_request_prev) or (ipb_in.ipb_strobe and acknowledge_prev); -- only one clock cycle except if we restart a second transaction immediately after the first one completes, in which case we keep mem_req_o high for the second transaction
    mem_req_o <= req_local;
    mem_we_o <= ipb_in.ipb_write and req_local; -- only simulteanously?
    mem_be_o <= (others=>'1');

end architecture dummy;