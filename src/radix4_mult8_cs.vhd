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

use IEEE.NUMERIC_STD.ALL;

use work.vector_Pkg.all;

entity radix4_mult8_cs is
  Port ( 
    a : in std_logic_vector(7 downto 0);
    b : in std_logic_vector(7 downto 0);
    en : in std_logic;
    
    s : out std_logic_vector(15 downto 0); 
    c : out std_logic_vector(15 downto 0));
end radix4_mult8_cs;

architecture Behavioral of radix4_mult8_cs is

    signal sa, sb : std_logic_vector(7 downto 0);
    signal pp0, pp1, pp2, pp3, pp4 : std_logic_vector(8 downto 0);
    signal ext_pp0, ext_pp1, ext_pp2, ext_pp3, ext_pp4 : std_logic_vector(15 downto 0);
    signal s0, s1, s2, s3 : std_logic;
    signal rec0, rec4 : std_logic_vector(2 downto 0);
    
    signal cs_p_l1, cs_c_l1, cs_s_l1: std_logic_vector(15 downto 0);
    signal cs_p_l2, cs_c_l2, cs_s_l2: std_logic_vector(15 downto 0);
    signal cs_c_l3, cs_s_l3: std_logic_vector(15 downto 0);
    
    signal ext_en : std_logic_vector(7 downto 0);
begin

    ext_en <= (others => en);
    
    sa <= a and ext_en;
    sb <= b and ext_en;
    
    rec0 <= sb(1 downto 0) & '0';
    booth_enc0 : radix4_booth_enc8 port map ( a => sa, rec => rec0, pp => pp0, s => s0 );
    booth_enc1 : radix4_booth_enc8 port map ( a => sa, rec => sb(3 downto 1), pp => pp1, s => s1 );
    booth_enc2 : radix4_booth_enc8 port map ( a => sa, rec => sb(5 downto 3), pp => pp2, s => s2 );
    booth_enc3 : radix4_booth_enc8 port map ( a => sa, rec => sb(7 downto 5), pp => pp3, s => s3 );
    rec4 <= "00" & sb(7);
    booth_enc4 : radix4_booth_enc8 port map ( a => sa, rec => rec4, pp => pp4, s => open );
    
    ext_pp0 <= "0000" & not s0 & s0 & s0 & pp0;
    ext_pp1 <= "000" & '1' & not s1 & pp1 & '0' & s0; 
    ext_pp2 <= '0' & '1' & not s2 & pp2 & '0' & s1 & "00";
    ext_pp3 <= not s3 & pp3 & '0' & s2 & "0000";
    ext_pp4 <= pp4(7 downto 0) & '0' & s3 & "000000";
    
    -- Carry-Save Level 1 instances
    carry_save_l1_gen : for i in 0 to 15 generate
        cs_s_l1(i) <= ext_pp0(i) xor ext_pp1(i) xor ext_pp2(i);
        cs_c_l1(i) <= ((ext_pp0(i) xor ext_pp1(i)) and ext_pp2(i)) or (ext_pp0(i) and ext_pp1(i));
    end generate;    
    cs_p_l1 <= cs_c_l1(14 downto 0) & '0';
    
    -- Carry-Save Level 2 instances
    carry_save_l2_gen : for i in 0 to 15 generate
        cs_s_l2(i) <= cs_s_l1(i) xor cs_p_l1(i) xor ext_pp3(i);
        cs_c_l2(i) <= ((cs_s_l1(i) xor cs_p_l1(i)) and ext_pp3(i)) or (cs_s_l1(i) and cs_p_l1(i));
    end generate;
    cs_p_l2 <= cs_c_l2(14 downto 0) & '0';
    
    -- Carry-Save Level 3 instances
    carry_save_l3_gen : for i in 0 to 15 generate
        cs_s_l3(i) <= cs_s_l2(i) xor cs_p_l2(i) xor ext_pp4(i);
        cs_c_l3(i) <= ((cs_s_l2(i) xor cs_p_l2(i)) and ext_pp4(i)) or (cs_s_l2(i) and cs_p_l2(i));
    end generate;
    

    
    s <= cs_s_l3;
    c <= cs_c_l3;--(14 downto 0) & '0';
    
end Behavioral;

