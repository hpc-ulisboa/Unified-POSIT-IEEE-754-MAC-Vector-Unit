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

use work.vector_Pkg.all;

entity vector_lzc128 is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector (1 downto 0);
        a : in std_logic_vector (127 downto 0);
        c : out std_logic_vector (23 downto 0);
        v : out std_logic_vector(3 downto 0)
    );
end vector_lzc128;

architecture Behavioral of vector_lzc128 is
  
  type count32b is array(0 to 3) of std_logic_vector (5 downto 0);
  type count64b is array(0 to 1) of std_logic_vector (6 downto 0);
  signal r32 : count32b;
  signal r64 : count64b;
  signal r128 : std_logic_vector (7 downto 0);
  
begin
    -- 32-bit count vector
    count_vector_32: for i in 1 to 4 generate
        clz32: clz generic map (G_DATA_WIDTH => 32, G_COUNT_WIDTH => 5)
               port map (A => a((i*32)-1 downto (i-1)*32), C => r32(i-1)(4 downto 0), V => r32(i-1)(5));
    end generate;

    -- 64-bit count vector
    count_vector_64: for i in 0 to 1 generate
        r64(i)(5 downto 0) <= '0' & r32(2*i+1)(4 downto 0) when r32(2*i+1)(5) = '0' else
                              '1' & r32(2*i)(4 downto 0) when r32(2*i+1)(5) = '1' and r32(2*i)(5) = '0' else
                              "000000";
        r64(i)(6) <= r32(2*i+1)(5) and r32(2*i)(5);
    end generate;
    
    -- 128-bit count vector
    r128(6 downto 0) <= '0' & r64(1)(5 downto 0) when r64(1)(6) = '0' else
                        '1' & r64(0)(5 downto 0) when r64(1)(6) = '1' and r64(0)(6) = '0' else
                        "0000000";
    r128(7) <= r64(1)(6) and r64(0)(6);
    
    c <=  "00000000000000000" & r128(6 downto 0) when config_port(1)='0' else
          "000000" & r64(1)(5 downto 0) & "000000" & r64(0)(5 downto 0) when config_port(0)='0' else
          '0' & r32(3)(4 downto 0) & '0' & r32(2)(4 downto 0) & '0' & r32(1)(4 downto 0) & '0' & r32(0)(4 downto 0);
          
    v <= "000" & r128(7)  when config_port(1)='0' else
         '0' & r64(1)(6) & '0' & r64(0)(6) when config_port(0)='0' else
         r32(3)(5) & r32(2)(5) & r32(1)(5) & r32(0)(5);
  
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;

end Behavioral;
