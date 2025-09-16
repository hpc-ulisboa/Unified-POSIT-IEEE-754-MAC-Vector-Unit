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

entity vector_zero_sign_detect is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);  -- 00 & 01 - 32bits; 10 - 16bits; 11 - 8bits
        v_a : in std_logic_vector (31 downto 0);
        v_z : out std_logic_vector (3 downto 0);
        v_s : out std_logic_vector (3 downto 0)
    );
end vector_zero_sign_detect;

architecture Behavioral of vector_zero_sign_detect is
    function is_zero(d : std_logic_vector) return std_logic is
        variable z : std_logic_vector(d'range);
    begin
        z := (others => '0');
        if d = z then return '1';
        else return '0';
        end if;
    end;
    
    signal sig_v8, z_v8 : std_logic_vector(3 downto 0);
    signal sig_v16, z_v16 : std_logic_vector(1 downto 0);
    signal sig_v32, z_v32 : std_logic;
begin

    sign_vector_8 : for i in 1 to 4 generate
        sig_v8(i-1) <= v_a((i*8)-1);
    end generate;
    
    sign_vector_16 : for i in 1 to 2 generate
        sig_v16(i-1) <= v_a((i*16)-1);
    end generate;
    
    sig_v32 <= v_a(31);
    
    zero_det_8 : for i in 1 to 4 generate
        z_v8(i-1) <= is_zero(v_a((i*8)-2 downto (i-1)*8));
    end generate;
    
    zero_det_16 : for i in 0 to 1 generate
        z_v16(i) <= z_v8((i*2)+1) and (not sig_v8(i*2) and z_v8(i*2));
    end generate;
    
    z_v32 <= z_v16(1) and (not sig_v16(0) and z_v16(0));
   
    
    v_z <= (others => z_v32) when config_port(1) = '0' else
           z_v16(1) & z_v16(1) & z_v16(0) & z_v16(0) when config_port(0) = '0' else
           z_v8(3) & z_v8(2) & z_v8(1) & z_v8(0);  
    
    v_s <= (others => sig_v32) when config_port(1) = '0' else
           sig_v16(1) & sig_v16(1) & sig_v16(0) & sig_v16(0) when config_port(0) = '0' else
           sig_v8(3) & sig_v8(2) & sig_v8(1) & sig_v8(0); 
           
           
end Behavioral;
