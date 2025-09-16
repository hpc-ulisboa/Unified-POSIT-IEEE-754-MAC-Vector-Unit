--Copyright 2025 IST, University of Lisbon and INESC-ID.
--
--SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
--
--Licensed under the Solderpad Hardware License v 2.1 (the “License”); 
--you may not use this file except in compliance with the 
--License, or, at your option, the Apache License version 2.0.
--You may obtain a copy of the License at
--
--https://solderpad.org/licenses/SHL-2.1/
--
--Unless required by applicable law or agreed to in writing, any 
--work distributed under the License is distributed on an “AS IS” 
--BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
--either express or implied. See the License for the specific
--language governing permissions and limitations under the License.

--Author: Luís Crespo - luis.miguel.crespo@tecnico.ulisboa.pt

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;


entity vector_barrel_sr_round is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (127 downto 0);
        shamtv : in std_logic_vector (23 downto 0);
        sign: in std_logic_vector (3 downto 0);
        s : out std_logic_vector (127 downto 0);
        sticky : out std_logic_vector(3 downto 0)
    );
end vector_barrel_sr_round;

architecture Behavioral of vector_barrel_sr_round is

    procedure shift_right_carry_8(value: in std_logic_vector(31 downto 0); shamt: in std_logic_vector(4 downto 0); sign: in std_logic;
                                  signal r : out std_logic_vector(63 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(63 downto 0);
        variable paddings: std_logic_vector(15 downto 0);
        variable i: integer := 0; 
    begin
        paddings := (others => sign);
        result := value & X"00000000";
        while i < 5 loop
	       if (shamt(i) = '1') then result := paddings(2**i - 1 downto 0) & result(63 downto 2**i);
	       end if;
	       i:=i+1;
	    end loop;
	    r <= result;
        or_red <= or_reduce(result(31 downto 1));
    end;    
    
    
    procedure shift_right_inc_16(value: in std_logic_vector(63 downto 0); shamt: in std_logic; sign: in std_logic;
                                signal r : out std_logic_vector(127 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(127 downto 0);
        variable paddings: std_logic_vector(31 downto 0);
    begin
        paddings := (others => sign);
        result :=  value & x"0000000000000000";
        if (shamt = '1') then result := paddings(31 downto 0) & result(127 downto 32); end if;
        r <= result;
        or_red <= or_reduce(result(63 downto 64-32));
    end;
    
    procedure shift_right_inc_32(value: in std_logic_vector(127 downto 0); shamt: in std_logic; sign: in std_logic;
                                 signal r : out std_logic_vector(255 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(255 downto 0);
        variable paddings: std_logic_vector(63 downto 0);
    begin
        paddings := (others => sign);
        result := value & x"00000000000000000000000000000000";
        if (shamt = '1') then result := paddings(63 downto 0) & result(255 downto 64); end if;
        r <= result;
        or_red <= or_reduce(result(127 downto 128-64));
    end;


    type byte_shift_array is array(0 to 3) of std_logic_vector(63 downto 0);
    type halfword_shift_array is array(0 to 1) of std_logic_vector(127 downto 0);
    type byte_shamt_vector is array(0 to 3) of std_logic_vector(4 downto 0);
    
    signal bsh : byte_shift_array;
    signal hwsh : halfword_shift_array;
    signal wsh : std_logic_vector(255 downto 0);
    signal b_s, hw_s : std_logic_vector(127 downto 0);
    signal sticky_v8, sticky_v16, sticky_v32 : std_logic_vector(3 downto 0);
    
    signal bsign : std_logic_vector(3 downto 0);
    signal hwsign : std_logic_vector(1 downto 0);
    signal wsign : std_logic;
    
    signal bshamtv : byte_shamt_vector;
    signal hwshamtv : std_logic_vector(1 downto 0);
    signal wshamtv : std_logic;
    
begin
    
    with config_port select
    bsign <= sign when "11",
             sign(3) & '0' & sign(1) & '0' when "10",
             sign(3) & "000" when others;
    
    with config_port select
    hwsign <= sign(3) & sign(1) when "10",
              sign(3) & '0' when others;
   
    wsign <= sign(3);
   
    bshamtv(0) <= shamtv(4 downto 0);
    with config_port select
    bshamtv(1) <= shamtv(10 downto 6) when "11",
                  shamtv(4 downto 0) when others;
    with config_port select
    bshamtv(2) <= shamtv(16 downto 12) when "11",
                  shamtv(16 downto 12) when "10",
                  shamtv(4 downto 0) when others;
    with config_port select
    bshamtv(3) <= shamtv(22 downto 18) when "11",
                  shamtv(16 downto 12) when "10",
                  shamtv(4 downto 0) when others;
   
    
    with config_port select              
    hwshamtv(0) <= '0' when "11",
                   shamtv(5) when others;
    with config_port select              
    hwshamtv(1) <= '0' when "11",
                   shamtv(17) when "10",
                   shamtv(5) when others;


    with config_port select              
    wshamtv <= '0' when "11",
               '0' when "10",
               shamtv(6) when others;
               

    byte_shift: for i in 0 to 3 generate
       shift_right_carry_8(a((i+1)*32-1 downto i*32), bshamtv(i), bsign(i), bsh(i), sticky_v8(i));
    end generate;
    
    b_s(127 downto 128-32) <= bsh(3)(63 downto 32);
    byte_shift_or_even: for i in 0 to 1 generate
       with config_port select
       b_s((2*i+1)*32-1 downto (2*i)*32) <= bsh(2*i)(63 downto 32) when "11",
                                            bsh(2*i)(63 downto 32) or bsh(2*i+1)(31 downto 0) when others; 
    end generate;
    b_s(32+31 downto 32) <= bsh(1)(63 downto 32) when config_port(1) = '1' else
                            bsh(1)(63 downto 32) or bsh(2)(31 downto 0); 
    
    
    hw_shift: for i in 0 to 1 generate
       shift_right_inc_16(b_s((i+1)*64-1 downto i*64), hwshamtv(i), hwsign(i), hwsh(i), sticky_v16(2*i));
    end generate;
    sticky_v16(1) <= '0';
    sticky_v16(3) <= '0';
       
    hw_s(127 downto 128-64) <= hwsh(1)(127 downto 64);
    hw_shift_or_even: 
       hw_s(63 downto 0) <= hwsh(0)(127 downto 64) when config_port(1) = '1' else
                            hwsh(0)(127 downto 64) or hwsh(1)(63 downto 0); 
            

    w_shift:
        shift_right_inc_32(hw_s(127 downto  0), wshamtv, wsign, wsh, sticky_v32(0));
        sticky_v32(3 downto 1) <= (others => '0');
    
    s <= wsh(255 downto 128);
    
    sticky <= (3 downto 1 => '0', 0 => sticky_v32(0) or sticky_v16(0) or sticky_v8(0))      when config_port(1)='0' else  -- 32
              '0' & (sticky_v16(2) or sticky_v8(2)) & '0' & (sticky_v16(0) or sticky_v8(0)) when config_port(0)='0' else  -- 16
              sticky_v8;                                                                                                  --8
                  
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;
