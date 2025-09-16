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

entity vector_lzc32 is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector (1 downto 0);
        a : in std_logic_vector (31 downto 0);
        c : out std_logic_vector (15 downto 0);
        v : out std_logic_vector(3 downto 0)
    );
end vector_lzc32;

architecture Behavioral of vector_lzc32 is

  type count8b is array(0 to 3) of std_logic_vector (3 downto 0);
  type count16b is array(0 to 1) of std_logic_vector (4 downto 0);
  signal r8 : count8b;
  signal r16 : count16b;
  signal r32 : std_logic_vector (5 downto 0);
  
begin
    -- 8-bit count vector
    count_vector_8: for i in 1 to 4 generate
        clz8: clz generic map (G_DATA_WIDTH => 8, G_COUNT_WIDTH => 3)
              port map (A => a((i*8)-1 downto (i-1)*8), C => r8(i-1)(2 downto 0), V => r8(i-1)(3));
    end generate;

    -- 16-bit count vector
    count_vector_16: for i in 0 to 1 generate
        r16(i)(3 downto 0) <= '0' & r8(2*i+1)(2 downto 0) when r8(2*i+1)(3) = '0' else
                              '1' & r8(2*i)(2 downto 0) when r8(2*i+1)(3) = '1' and r8(2*i)(3) = '0' else
                              "0000";
        r16(i)(4) <= r8(2*i+1)(3) and r8(2*i)(3);
    end generate;
    
    -- 32-bit count vector
    r32(4 downto 0) <= '0' & r16(1)(3 downto 0) when r16(1)(4) = '0' else
                          '1' & r16(0)(3 downto 0) when r16(1)(4) = '1' and r16(0)(4) = '0' else
                          "00000";
    r32(5) <= r16(1)(4) and r16(0)(4);
    
    c <=  "00000000000" & r32(4 downto 0) when config_port(1)='0' else
          "0000" & r16(1)(3 downto 0) & "0000" & r16(0)(3 downto 0) when config_port(0)='0' else
          '0' & r8(3)(2 downto 0) & '0' & r8(2)(2 downto 0) & '0' & r8(1)(2 downto 0) & '0' & r8(0)(2 downto 0);
          
    v <= "000" & r32(5)  when config_port(1)='0' else
         '0' & r16(1)(4) & '0' & r16(0)(4) when config_port(0)='0' else
         r8(3)(3) & r8(2)(3) & r8(1)(3) & r8(0)(3);
  
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;

end Behavioral;
