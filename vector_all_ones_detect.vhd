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


entity vector_all_ones_detect is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        v_a : in std_logic_vector (15 downto 0);
        v_f : out std_logic_vector (3 downto 0)
    );
end vector_all_ones_detect;

architecture Behavioral of vector_all_ones_detect is
    
    function is_all_ones(d : std_logic_vector) return std_logic is
        variable z : std_logic_vector(d'range);
    begin
        z := (others => '1');
        if d = z then return '1';
        else return '0';
        end if;
    end;
    
    signal F_vQ : std_logic_vector(3 downto 0);
    signal F_vH : std_logic_vector(1 downto 0);
    signal F_vA : std_logic;
begin
    
    -- 000 0 | 0000 | 111 1 | 1111
    -- 000 1 | 1111 | 000 1 | 1111
    -- 111 1 | 1111 | 111 1 | 1111
    
    F_vQ(0) <= is_all_ones(v_a(3 downto 0));
    F_vQ(1) <= is_all_ones(v_a(7 downto 5));
    F_vQ(2) <= is_all_ones(v_a(11 downto 8));
    F_vQ(3) <= is_all_ones(v_a(15 downto 13));
    
    
    F_vH(0) <= F_vQ(0) and v_a(4);
    F_vH(1) <= F_vQ(2) and v_a(12);
    
    F_vA <= F_vQ(1) and F_vH(0);
   
    
    v_f <= (others => F_vA) when config_port(1) = '0' else
           F_vH(1) & F_vH(1) & F_vH(0) & F_vH(0) when config_port(0) = '0' else
           (F_vQ(3) and v_a(12)) & F_vQ(2) & (F_vQ(1) and v_a(4)) & F_vQ(0);
           
           
end Behavioral;