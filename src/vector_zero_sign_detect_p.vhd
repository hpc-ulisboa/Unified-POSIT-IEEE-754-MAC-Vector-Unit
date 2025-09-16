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


entity vector_zero_sign_detect_p is
    Generic ( 
            constant G_DATA_WIDTH : positive := 32);
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);  -- 00 & 01 - 32bits; 10 - 16bits; 11 - 8bits
        v_a : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
        v_z : out std_logic_vector (3 downto 0);
        v_s : out std_logic_vector (3 downto 0)
    );
end vector_zero_sign_detect_p;

architecture Behavioral of vector_zero_sign_detect_p is
    function is_zero(d : std_logic_vector) return std_logic is
        variable z : std_logic_vector(d'range);
    begin
        z := (others => '0');
        if d = z then return '1';
        else return '0';
        end if;
    end;
    
    signal sig_vQ, z_vQ : std_logic_vector(3 downto 0);
    signal sig_vH, z_vH : std_logic_vector(1 downto 0);
    signal sig_vA, z_vA : std_logic;
begin

    sign_vector_Q : for i in 1 to 4 generate
        sig_vQ(i-1) <= v_a((i*G_DATA_WIDTH/4)-1);
    end generate;
    
    sign_vector_16 : for i in 1 to 2 generate
        sig_vH(i-1) <= v_a((i*G_DATA_WIDTH/2)-1);
    end generate;
    
    sig_vA <= v_a(G_DATA_WIDTH-1);
    
    zero_det_8 : for i in 1 to 4 generate
        z_vQ(i-1) <= is_zero(v_a((i*G_DATA_WIDTH/4)-2 downto (i-1)*G_DATA_WIDTH/4));
    end generate;
    
    zero_det_H : for i in 0 to 1 generate
        z_vH(i) <= z_vQ((i*2)+1) and (not sig_vQ(i*2) and z_vQ(i*2));
    end generate;
    
    z_vA <= z_vH(1) and (not sig_vH(0) and z_vH(0));
   
    
    v_z <= (others => z_vA) when config_port(1) = '0' else
           z_vH(1) & z_vH(1) & z_vH(0) & z_vH(0) when config_port(0) = '0' else
           z_vQ(3) & z_vQ(2) & z_vQ(1) & z_vQ(0);  
    
    v_s <= (others => sig_vA) when config_port(1) = '0' else
           sig_vH(1) & sig_vH(1) & sig_vH(0) & sig_vH(0) when config_port(0) = '0' else
           sig_vQ(3) & sig_vQ(2) & sig_vQ(1) & sig_vQ(0); 
           
           
end Behavioral;
