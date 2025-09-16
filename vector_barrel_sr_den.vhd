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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_misc.all;

entity vector_barrel_sr_den is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (31 downto 0);
        shamtv : in std_logic_vector (11 downto 0);
        zero : in std_logic_vector(3 downto 0);
        s : out std_logic_vector (31 downto 0);
        sticky : out std_logic_vector(3 downto 0)
    );
end vector_barrel_sr_den;

architecture Behavioral of vector_barrel_sr_den is
    
    procedure shift_right_carry_8(value: in std_logic_vector(7 downto 0); shamt: in std_logic_vector(2 downto 0); zero: in std_logic;
                                  signal r : out std_logic_vector(15 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(15 downto 0);
        variable paddings: std_logic_vector(3 downto 0);
    begin
        paddings := (others => '0');
        result := value & x"00";

        if (zero = '0') then result := paddings(0) & result(15 downto 1); end if;
        if (shamt(0) = '0' and zero = '0') then result := paddings(0) & result(15 downto 1); end if;
        if (shamt(1) = '0' and zero = '0') then result := paddings(1 downto 0) & result(15 downto 2); end if;
        if (shamt(2) = '0' and zero = '0') then result := paddings(3 downto 0) & result(15 downto 4); end if;
        r <= result;
        or_red <= or_reduce(result(7 downto 0));
    end;
    
    procedure shift_right_inc_16(value: in std_logic_vector(15 downto 0); shamt: in std_logic; zero: in std_logic;
                                signal r : out std_logic_vector(31 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(31 downto 0);
        variable paddings: std_logic_vector(7 downto 0);
    begin
        paddings := (others => '0');
        result :=  value & x"0000";
        if (shamt = '0' and zero = '0') then result := paddings(7 downto 0) & result(31 downto 8) ; end if;
        r <= result;
        or_red <= or_reduce(result(15 downto 16-8));
    end;
    
    procedure shift_right_inc_32(value: in std_logic_vector(31 downto 0); shamt: in std_logic; zero: in std_logic;
                                signal r : out std_logic_vector(63 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(63 downto 0);
        variable paddings: std_logic_vector(15 downto 0);
    begin
        paddings := (others => '0');
        result := value & x"00000000";
        if (shamt = '0' and zero = '0') then result := paddings(15 downto 0) & result(63 downto 16) ; end if;
        r <= result;
        or_red <= or_reduce(result(31 downto 32-16));
    end;

    type byte_shift_array is array(0 to 3) of std_logic_vector(15 downto 0);
    type halfword_shift_array is array(0 to 1) of std_logic_vector(31 downto 0);
    type byte_shamt_vector is array(0 to 3) of std_logic_vector(2 downto 0);
    
    signal bsh : byte_shift_array;
    signal hwsh : halfword_shift_array;
    signal wsh : std_logic_vector(63 downto 0);
    signal b_s, hw_s : std_logic_vector(31 downto 0);
    signal sticky_v8, sticky_v16, sticky_v32 : std_logic_vector(3 downto 0);
    
    signal bshamtv : byte_shamt_vector;
    signal hwshamtv : std_logic_vector(1 downto 0);
    signal wshamtv : std_logic;
    
begin
   
   
    bshamtv(0) <= shamtv(2 downto 0);
    with config_port select
    bshamtv(1) <= shamtv(5 downto 3) when "11",
                  shamtv(2 downto 0) when others;
    with config_port select
    bshamtv(2) <= shamtv(8 downto 6) when "11",
                  shamtv(8 downto 6) when "10",
                  shamtv(2 downto 0) when others;
    with config_port select
    bshamtv(3) <= shamtv(11 downto 9) when "11",
                  shamtv(8 downto 6) when "10",
                  shamtv(2 downto 0) when others;
    
    with config_port select              
    hwshamtv(0) <= '0' when "11",
                   shamtv(3) when others;
    with config_port select              
    hwshamtv(1) <= '0' when "11",
                   shamtv(9) when "10",
                   shamtv(3) when others;
    
    with config_port select              
    wshamtv <= '0' when "11",
               '0' when "10",
               shamtv(4) when others;
    

    byte_shift: for i in 0 to 3 generate
        shift_right_carry_8(a((i+1)*8-1 downto i*8), bshamtv(i), zero(i), bsh(i), sticky_v8(i));
    end generate;
    
    
    b_s(31 downto 32-8) <= bsh(3)(15 downto 8);
    byte_shift_or_even: for i in 0 to 1 generate
       with config_port select
       b_s((2*i+1)*8-1 downto (2*i)*8) <= bsh(2*i)(15 downto 8) when "11",
                                          bsh(2*i)(15 downto 8) or bsh(2*i+1)(7 downto 0) when others; 
    end generate;
    b_s(8+7 downto 8) <= bsh(1)(15 downto 8) when config_port(1) = '1' else
                         bsh(1)(15 downto 8) or bsh(2)(7 downto 0); 
    
    
    hw_shift: for i in 0 to 1 generate
       shift_right_inc_16(b_s((i+1)*16-1 downto i*16), hwshamtv(i), zero(2*i), hwsh(i), sticky_v16(2*i));
    end generate;
    sticky_v16(1) <= '0';
    sticky_v16(3) <= '0';
       
    hw_s(31 downto 32-16) <= hwsh(1)(31 downto 16);
    hw_shift_or_even: 
       hw_s(15 downto 0) <= hwsh(0)(31 downto 16) when config_port(1) = '1' else
                            hwsh(0)(31 downto 16) or hwsh(1)(15 downto 0); 
    
     
    w_shift:
        shift_right_inc_32(hw_s(31 downto  0), wshamtv, zero(0), wsh, sticky_v32(0));
        sticky_v32(3 downto 1) <= (others => '0');
    
    s <= '0' & wsh(63 downto 33) when config_port(1)='0' else
         '0' & hwsh(1)(31 downto 17) & '0' & hwsh(0)(31 downto 17) when config_port(0)='0' else
         '0' & bsh(3)(15 downto 9) & '0' & bsh(2)(15 downto 9) & '0' & bsh(1)(15 downto 9) & '0' & bsh(0)(15 downto 9);
    
    
    sticky <= (3 downto 1 => '0', 0 => sticky_v32(0) or sticky_v16(0) or sticky_v8(0) or wsh(32)) when config_port(1)='0' else  -- 32
              '0' & (sticky_v16(2) or sticky_v8(2) or hwsh(1)(16)) & '0' & (sticky_v16(0) or sticky_v8(0) or hwsh(0)(16)) when config_port(0)='0' else  -- 16
              (sticky_v8(3) or bsh(3)(8)) & (sticky_v8(2) or bsh(2)(8)) & (sticky_v8(1) or bsh(1)(8)) & (sticky_v8(0) or bsh(0)(8));
    
    
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;