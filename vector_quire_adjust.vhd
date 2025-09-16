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


entity vector_quire_adjust is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (127 downto 0);
        s : out std_logic_vector (127 downto 0);
        sf_inc : out std_logic_vector (3 downto 0)
    );
end vector_quire_adjust;

architecture Behavioral of vector_quire_adjust is

    function shift_right_carry_32(value: std_logic_vector(31 downto 0); shift: std_logic; sign: std_logic) return std_logic_vector is
        variable result: std_logic_vector(32 downto 0);
    begin
        result := value & '0';
        if (shift = '1') then result := sign & result(32 downto 1)  ;end if;

        return result;
    end;
    
    type word_shift_array is array(0 to 3) of std_logic_vector(32 downto 0);
    
    signal bsh : word_shift_array;
    signal b_s : std_logic_vector(127 downto 0);
    
    signal sign : std_logic_vector (3 downto 0);
    
    signal shift_16 : std_logic;
    signal shift_32 : std_logic;
    signal shift : std_logic_vector (3 downto 0);
    
begin
    
    sign <= a(127) & "000" when config_port(1) = '0' else
            a(127) & '0' & a(128/2-1) & '0' when config_port(0) = '0' else
            a(127) & a(128*3/4-1) & a(128/2-1) & a(128/4-1); 
    
    shift_32 <= a(126) xor a(127);
    shift_16 <= a(128/2-2) xor a(128/2-1);
    shift <= (3 downto 0 => shift_32) when Config_port(1)='0' else
             (1 downto 0 => shift_32) & (1 downto 0 => shift_16) when Config_port(0)='0' else
             shift_32 & (a(128*3/4-2) xor a(128*3/4-1)) & shift_16 & (a(128/4-2) xor a(128/4-1));
    
    halfword_shift: for i in 0 to 3 generate
       bsh(i) <= shift_right_carry_32(a((i+1)*32-1 downto i*32), shift(i), sign(i));
    end generate;
    
    
    b_s(127 downto 96) <= bsh(3)(32 downto 1);
    
    byte_shift_or_even: for i in 0 to 1 generate
       with config_port select
       b_s((2*i+1)*32-1 downto (2*i)*32) <= bsh(2*i)(32 downto 1) when "11",
                                            (bsh(2*i)(32) or bsh(2*i+1)(0)) & bsh(2*i)(31 downto 1) when others; 
    end generate;
    
    b_s(63 downto 32) <= (bsh(2)(0) or bsh(1)(32)) & bsh(1)(31 downto 1) when config_port(1) = '1' else
                         bsh(1)(32 downto 1);



    
    s <= b_s;
    
    sf_inc <= (3 downto 0 => shift_32) when Config_port(1)='0' else
              (1 downto 0 => shift_32) & (1 downto 0 => shift_16) when Config_port(0)='0' else
              shift_32 & shift(2) & shift_16 & shift(0);
    
    
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;

