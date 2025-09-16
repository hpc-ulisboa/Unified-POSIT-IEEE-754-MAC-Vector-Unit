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


entity vector_adder is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32);
        
    Port (
        Config_port : in std_logic_vector(1 downto 0); 
        A : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        B : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        C_in : in std_logic_vector(3 downto 0);
  
        S : out std_logic_vector(G_DATA_WIDTH-1 downto 0); 
        C_out : out std_logic_vector(3 downto 0));
end vector_adder;

architecture Behavioral of vector_adder is

    constant section_size : integer := G_DATA_WIDTH/4;

    signal a_0, a_1, a_2, a_3 : std_logic_vector(section_size-1 downto 0);
    signal b_0, b_1, b_2, b_3 : std_logic_vector(section_size-1 downto 0);
    signal s_0, s_1, s_2, s_3 : std_logic_vector(section_size downto 0);
    signal C_out_tmp : std_logic_vector(3 downto 0);
    
    signal sel_cin : std_logic_vector(3 downto 0);
    signal split_units, split_half: std_logic;
    
begin
    
    split_units <= '1' when config_port = "11" else '0'; -- G_DATA_WIDTH/4
    split_half <= config_port(1);  -- 0 -> split, 1 -> do not split
    
    a_0 <= A(G_DATA_WIDTH/4-1 downto 0);
    a_1 <= A(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4);
    a_2 <= A(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2);
    a_3 <= A(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4);
    
    b_0 <= B(G_DATA_WIDTH/4-1 downto 0);
    b_1 <= B(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4);
    b_2 <= B(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2);
    b_3 <= B(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4);
                                               
    -- section 1
    sel_cin(0) <=  C_in(0);
    s_0 <= std_logic_vector(unsigned('0' & a_0) + unsigned('0' & b_0) + ("" & sel_cin(0)));
    
    S(G_DATA_WIDTH/4-1 downto 0) <= s_0(G_DATA_WIDTH/4-1 downto 0);
    C_out_tmp(0) <= '0' when split_units = '0' else   -- G_DATA_WIDTH, G_DATA_WIDTH/2
                    s_0(section_size);                -- G_DATA_WIDTH/4
   
    
    -- section 2
    sel_cin(1) <= s_0(section_size) when split_units = '0' else   -- G_DATA_WIDTH, G_DATA_WIDTH/2
                  C_in(1);                                        -- G_DATA_WIDTH/4
    s_1 <= std_logic_vector(unsigned('0' & a_1) + unsigned('0' & b_1) + ("" & sel_cin(1)));
    
    S(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) <= s_1(G_DATA_WIDTH/4-1 downto 0);
    C_out_tmp(1) <= '0' when split_half = '0' else    -- G_DATA_WIDTH
                    s_1(section_size);                -- G_DATA_WIDTH/2, G_DATA_WIDTH/4
    
    
    -- section 3
    sel_cin(2) <= s_1(section_size) when split_half = '0' else    -- G_DATA_WIDTH
                  C_in(2);                                        -- G_DATA_WIDTH/2, G_DATA_WIDTH/4
    
    s_2 <= std_logic_vector(unsigned('0' & a_2) + unsigned('0' & b_2) + ("" & sel_cin(2)));
    
    S(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) <= s_2(G_DATA_WIDTH/4-1 downto 0);
    C_out_tmp(2) <= '0' when split_units = '0' else   -- G_DATA_WIDTH, G_DATA_WIDTH/2
                    s_2(section_size);                -- G_DATA_WIDTH/4
    
    
    -- section 4
    sel_cin(3) <= s_2(section_size) when split_units = '0' else   -- G_DATA_WIDTH, G_DATA_WIDTH/2
                  C_in(3);                                        -- G_DATA_WIDTH/4
    
    s_3 <= std_logic_vector(unsigned('0' & a_3) + unsigned('0' & b_3) + ("" & sel_cin(3)));
    
    S(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) <= s_3(G_DATA_WIDTH/4-1 downto 0);
    C_out_tmp(3) <= s_3(section_size);
    
    
    C_out <= (others => C_out_tmp(3)) when Config_port(1)='0' else
             C_out_tmp(3) & C_out_tmp(3) & C_out_tmp(1) & C_out_tmp(1) when Config_port(0)='0' else
             C_out_tmp;
    
end Behavioral;
