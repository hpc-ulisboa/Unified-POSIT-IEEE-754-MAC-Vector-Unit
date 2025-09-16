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

entity vector_frac_zero_detect is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);  -- 00 & 01 - 32bits; 10 - 16bits; 11 - 8bits
        v_a : in std_logic_vector (31 downto 0);
        v_z : out std_logic_vector (3 downto 0)
    );
end vector_frac_zero_detect;

architecture Behavioral of vector_frac_zero_detect is
    function is_zero(d : std_logic_vector) return std_logic is
        variable z : std_logic_vector(d'range);
    begin
        z := (others => '0');
        if d = z then return '1';
        else return '0';
        end if;
    end;
    
    signal z_vQ : std_logic_vector(3 downto 0);
    signal z_vH : std_logic_vector(1 downto 0);
    signal z_vH_1, z_vA : std_logic;
begin

    -- 00000 0 00   0xxxx xxx   xxxxx x xx   xxxxx xxx
    -- 00000 0 xx   xxxxx xxx | 00000 0 xx   xxxxx xxx
    -- 00000 x xx | 00000 xxx | 00000 x xx | 00000 xxx
    
    z_vQ(0) <= is_zero(v_a(2 downto 0));
    z_vQ(1) <= is_zero(v_a(9 downto 8));
    z_vQ(2) <= is_zero(v_a(18 downto 16));
    z_vQ(3) <= is_zero(v_a(25 downto 24));
    
    z_vH(0) <= z_vQ(0) and is_zero(v_a(7 downto 3)) and z_vQ(1);
    z_vH_1 <= z_vQ(2) and is_zero(v_a(22 downto 19));
    z_vH(1) <= z_vH_1 and z_vQ(3) and not v_a(23);

    z_vA <= z_vH(0) and is_zero(v_a(15 downto 10)) and z_vH_1;
   
    
    v_z <= (others => z_vA) when config_port(1) = '0' else
           z_vH(1) & z_vH(1) & z_vH(0) & z_vH(0) when config_port(0) = '0' else
           (z_vQ(3) and not v_a(26)) & z_vQ(2) & (z_vQ(1) and not v_a(10)) & z_vQ(0); 
           
end Behavioral; 
