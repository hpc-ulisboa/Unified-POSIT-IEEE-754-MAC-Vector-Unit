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


entity vector_frac_overflow is
    Port ( --clk : in std_logic;
        a : in std_logic_vector (63 downto 0);
        ovf : in std_logic_vector (3 downto 0);
        s : out std_logic_vector (63 downto 0)
    );
end vector_frac_overflow;

architecture Behavioral of vector_frac_overflow is

    function shift_left_carry_16(value: std_logic_vector(15 downto 0); ovf: std_logic) return std_logic_vector is
        variable result: std_logic_vector(16 downto 0);
    begin
        result := '0' & value;
        if (ovf = '0') then result := result(15 downto 0) & '0' ;end if;

        return result;
    end;
    
    type halfword_shift_array is array(0 to 3) of std_logic_vector(16 downto 0);
    
    signal bsh : halfword_shift_array;
    signal b_s : std_logic_vector(63 downto 0);
    
    
begin
   
    halfword_shift: for i in 0 to 3 generate
       bsh(i) <= shift_left_carry_16(a((i+1)*16-1 downto i*16), ovf(i));
    end generate;
    
    b_s(15 downto 0) <= bsh(0)(15 downto 0);

    b_s(31 downto 16) <= bsh(1)(15 downto 1) & (bsh(1)(0) or bsh(0)(16));
                         
    b_s(47 downto 32) <= bsh(2)(15 downto 1) & (bsh(2)(0) or bsh(1)(16));
                                           
    b_s(63 downto 48) <= bsh(3)(15 downto 1) & (bsh(3)(0) or bsh(2)(16));

    
    s <= b_s;
    
    
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;

