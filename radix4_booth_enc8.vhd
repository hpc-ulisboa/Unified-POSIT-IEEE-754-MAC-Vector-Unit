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

entity radix4_booth_enc8 is
  Port ( 
    a : in std_logic_vector(7 downto 0);
    rec : in std_logic_vector(2 downto 0);
    
    pp : out std_logic_vector(8 downto 0); 
    s : out std_logic);
end radix4_booth_enc8;

architecture Behavioral of radix4_booth_enc8 is

    signal ext_a, shl_a : std_logic_vector(8 downto 0);

begin

    ext_a <= '0' & a;
    shl_a <= a & '0';
    
    
    --pp <= (others => '0') when (not (rec(2) xor rec(1)) and not (rec(1) xor rec(0))) = '1' else
    --      ext_a     when (not rec(2) and (rec(1) xor rec(0))) = '1' else
    --      not ext_a when (rec(2) and (rec(1) xor rec(0))) = '1' else
    --      shl_a     when (not rec(2) and not (rec(1) xor rec(0))) = '1' else
    --      not shl_a when (rec(2) and not (rec(1) xor rec(0))) = '1' else
    --      (others => '0');
    
    with rec select
    pp <= (others => '0') when "000",
          ext_a     when "001",
          ext_a     when "010",
          shl_a     when "011",
          not shl_a when "100",
          not ext_a when "101",
          not ext_a when "110",
          (others => '0') when others;
    
    s <= rec(2) and not (rec(1) and rec(0));


end Behavioral;
