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

entity vector_barrel_sl_es_cpy is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (31 downto 0);
        shamt : in std_logic_vector (2 downto 0);
        s : out std_logic_vector (31 downto 0);
        cpy : out std_logic_vector (19 downto 0)
    );
end vector_barrel_sl_es_cpy;

architecture Behavioral of vector_barrel_sl_es_cpy is
    
    
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
    
    signal shamtv : std_logic_vector(2 downto 0);
    
    type byte_shift_array is array(0 to 3) of std_logic_vector(15 downto 0);
    
    signal bsh : byte_shift_array;
    signal b_s : std_logic_vector(31 downto 0);
    
    
begin
   
    shamtv <= '0' & shamt(1 downto 0) when config_port= "11" else
              shamt(2 downto 0);
       
    byte_shift: for i in 0 to 3 generate
       bsh(i) <= shift_left_carry_8(a((i+1)*8-1 downto i*8), shamtv);
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

    
    s <= b_s;
    
    cpy <= x"000" & '0' & bsh(3)(14 downto 8) when config_port(1)= '0' else                                     --  000 0000000 000 xxxxxxx
           "000" & bsh(3)(14 downto 8) & "000" & bsh(1)(14 downto 8) when config_port(0)= '0' else              --  000 xxxxxxx 000 xxxxxxx
           bsh(3)(10 downto 8) & x"0" & bsh(2)(10 downto 8) & bsh(1)(10 downto 8) & x"0" & bsh(0)(10 downto 8); --  xxx 0000xxx xxx 0000xxx
                                                                                                                                     

end Behavioral;

