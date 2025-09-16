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

entity vector_barrel_sl is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (31 downto 0);
        shamtv : in std_logic_vector (15 downto 0);
        s : out std_logic_vector (31 downto 0)
    );
end vector_barrel_sl;

architecture Behavioral of vector_barrel_sl is

    function shift_left_carry_8(value: std_logic_vector(7 downto 0); shamt: std_logic_vector(2 downto 0)) return std_logic_vector is
        variable result: std_logic_vector(15 downto 0);
        variable paddings: std_logic_vector(3 downto 0);
    begin
        paddings := (others => '0');
        result := "00000000" & value;
        if (shamt(0) = '1') then result := result(14 downto 0) & paddings( 0 );         end if;
        if (shamt(1) = '1') then result := result(13 downto 0) & paddings( 1 downto 0); end if;
        if (shamt(2) = '1') then result := result(11 downto 0) & paddings( 3 downto 0); end if;
        return result;
    end;
    
    function shift_left_inc_16(value: std_logic_vector(15 downto 0); shamt: std_logic) return std_logic_vector is
        variable result: std_logic_vector(31 downto 0);
        variable paddings: std_logic_vector(7 downto 0);
    begin
        paddings := (others => '0');
        result := x"0000" & value;
        if (shamt = '1') then result := result(23 downto 0) & paddings(7 downto 0); end if;
        return result;
    end;
    
    function shift_left_inc_32(value: std_logic_vector(31 downto 0); shamt: std_logic) return std_logic_vector is
        variable result: std_logic_vector(63 downto 0);
        variable paddings: std_logic_vector(15 downto 0);
    begin
        paddings := (others => '0');
        result := x"00000000" & value;
        if (shamt = '1') then result := result(47 downto 0) & paddings(15 downto 0); end if;
        return result;
    end;

    type byte_shift_array is array(0 to 3) of std_logic_vector(15 downto 0);
    type halfword_shift_array is array(0 to 1) of std_logic_vector(31 downto 0);
    type byte_shamt_vector is array(0 to 3) of std_logic_vector(2 downto 0);
    
    signal bsh : byte_shift_array;
    signal hwsh : halfword_shift_array;
    signal wsh : std_logic_vector(63 downto 0);
    signal b_s, hw_s : std_logic_vector(31 downto 0);
    
    signal bshamtv : byte_shamt_vector;
    signal hwshamtv : std_logic_vector(1 downto 0);
    signal wshamtv : std_logic;
    
begin
   
   
    bshamtv(0) <= shamtv(2 downto 0);
    with config_port select
    bshamtv(1) <= shamtv(6 downto 4) when "11",
                  shamtv(2 downto 0) when others;
    with config_port select
    bshamtv(2) <= shamtv(10 downto 8) when "11",
                  shamtv(10 downto 8) when "10",
                  shamtv(2 downto 0) when others;
    with config_port select
    bshamtv(3) <= shamtv(14 downto 12) when "11",
                  shamtv(10 downto 8) when "10",
                  shamtv(2 downto 0) when others;
    
    
    with config_port select              
    hwshamtv(0) <= '0' when "11",
                   shamtv(3) when others;
    with config_port select              
    hwshamtv(1) <= '0' when "11",
                   shamtv(11) when "10",
                   shamtv(3) when others;
   
    with config_port select              
    wshamtv <= '0' when "11",
               '0' when "10",
               shamtv(4) when others;


    byte_shift: for i in 0 to 3 generate
       bsh(i) <= shift_left_carry_8(a((i+1)*8-1 downto i*8), bshamtv(i));
    end generate;
    
    b_s(7 downto 0) <= bsh(0)(7 downto 0);                        
    byte_shift_or_odd: for i in 0 to 1 generate
       with config_port select
       b_s((2*i+2)*8-1 downto (2*i+1)*8) <= bsh(2*i+1)(7 downto 0) when "11",
                                            bsh(2*i)(15 downto 8) or bsh(2*i+1)(7 downto 0) when others; 
    end generate;
    with config_port select
    b_s(16+7 downto 16) <= bsh(2)(7 downto 0) when "11",
                           bsh(2)(7 downto 0) when "10",
                           bsh(1)(15 downto 8) or bsh(2)(7 downto 0) when others;

     
    hw_shift: for i in 0 to 1 generate
       hwsh(i) <= shift_left_inc_16(b_s((i+1)*16-1 downto i*16), hwshamtv(i));
    end generate;
    
    hw_s(15 downto 0) <= hwsh(0)(15 downto 0);

    with config_port select
    hw_s(31 downto 16) <= hwsh(1)(15 downto 0) when "11",
                          hwsh(1)(15 downto 0) when "10",
                          hwsh(0)(31 downto 16) or hwsh(1)(15 downto 0) when others; 


      
    wsh <= shift_left_inc_32(hw_s(31 downto  0), wshamtv);
    
    s <= wsh(31 downto 0);
    
    
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;

