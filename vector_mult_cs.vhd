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


use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


use work.vector_Pkg.all;

entity vector_mult_cs is
  Port ( 
    config_port : in std_logic_vector(1 downto 0); 
    a : in std_logic_vector(31 downto 0);
    b : in std_logic_vector(31 downto 0);
    
    s : out std_logic_vector(63 downto 0);
    c : out std_logic_vector(63 downto 0));
end vector_mult_cs;

architecture Behavioral of vector_mult_cs is

    type partial_product_array is array (1 to 16) of std_logic_vector(15 downto 0);
    type partial_product_vector_array is array (natural range <>) of std_logic_vector(63 downto 0);
    
    signal pp_s, pp_c : partial_product_array;
    signal pp_s_vec, pp_c_vec : partial_product_vector_array(0 to 7); 
    
    signal pp_s_l1 : partial_product_vector_array(0 to 5);
    signal pp_c_l1, pp_ec_l1 : partial_product_vector_array(0 to 4);
    signal pp_s_l2, pp_c_l2, pp_ec_l2: partial_product_vector_array(0 to 3);
    signal pp_s_l3, pp_c_l3, pp_ec_l3: partial_product_vector_array(0 to 2);
    signal pp_s_l4, pp_c_l4, pp_ec_l4 : partial_product_vector_array(0 to 1);
    signal pp_s_l5 : partial_product_vector_array(0 to 1); 
    signal pp_c_l5, pp_ec_l5 : partial_product_vector_array(0 to 0); 
    signal pp_s_l6, pp_c_l6 : partial_product_vector_array(0 to 0);
    
    signal enable : std_logic_vector(15 downto 0);
begin
    ---------------------------------------------------
    --- Configuration Decoding                      ---
    ---------------------------------------------------    
    enable <=   "1111111111111111" when config_port(1)='0' else  -- 32
                "1100110000110011" when config_port(0)='0' else  -- 16
                "1000010000100001";                              -- 8
                
                 
    ---------------------------------------------------
    --- Partial Product Generation                  ---
    ---------------------------------------------------

    partial_product_gen_top : for i in 1 to 4 generate
        pp_gen : for j in 1 to 4 generate
            radix4_mult_cs : radix4_mult8_cs port map ( a => a((i*8)-1 downto (i-1)*8), b => b((j*8)-1 downto (j-1)*8), 
                                                        en => enable(((i-1)*4+j)-1), s => pp_s((i-1)*4+j), c => pp_c((i-1)*4+j) );   
        end generate;
    end generate;

    ---------------------------------------------------
    --- Partial Product Vector Generation           ---
    ---------------------------------------------------
    pp_s_vec(0)  <= x"FDFCDDFC" & pp_s(3) & pp_s(1);
    pp_c_vec(0)  <= x"0000000" & "000" & pp_c(3) & pp_c(1) & '0';
    pp_s_vec(1)  <= x"00000D"  & pp_s(4) & pp_s(2) & x"00";
    pp_c_vec(1)  <= x"00000" & "000" & pp_c(4)  & pp_c(2) & x"00" & '0';
    pp_s_vec(2)  <= x"000011" & pp_s(7) & pp_s(5) & x"00";
    pp_c_vec(2)  <= x"00000" & "000" & pp_c(7) & pp_c(5) & x"00" & '0';
    pp_s_vec(3)  <= x"0000" &  pp_s(8) & pp_s(6) & x"8000";
    pp_c_vec(3)  <= x"000" & "000" & pp_c(8) & pp_c(6) & x"0000" & '0';
    pp_s_vec(4)  <= x"0000"  & pp_s(11) & pp_s(9) & x"8000";
    pp_c_vec(4)  <= x"000" & "000"  & pp_c(11) & pp_c(9) & x"0000" & '0';
    pp_s_vec(5)  <= x"00" & pp_s(12) & pp_s(10) & x"FA0000";
    pp_c_vec(5)  <= x"0" & "000" & pp_c(12) & pp_c(10) & x"000000" & '0';
    pp_s_vec(6)  <= x"00" & pp_s(15) & pp_s(13) & x"820000";
    pp_c_vec(6)  <= x"0" & "000" & pp_c(15) & pp_c(13) & x"000000" & '0';
    pp_s_vec(7)  <= pp_s(16) & pp_s(14) & x"FC820000";
    pp_c_vec(7)  <= pp_c(16) (14 downto 0) & pp_c(14) & x"00000000" & '0';

           
    ---------------------------------------------------
    --- Partial Product Accumulation - Wallace Tree ---
    ---------------------------------------------------
    
    -- Carry-Save Level 1 instances
    carry_save_l1_gen : for i in 0 to 63 generate
        pp_s_l1(0)(i) <= pp_s_vec(0)(i) xor pp_c_vec(0)(i) xor pp_s_vec(1)(i);
        pp_c_l1(0)(i) <= ((pp_s_vec(0)(i) xor pp_c_vec(0)(i)) and pp_s_vec(1)(i)) or (pp_s_vec(0)(i) and pp_c_vec(0)(i));
        
        pp_s_l1(1)(i) <= pp_c_vec(1)(i) xor pp_s_vec(2)(i) xor pp_c_vec(2)(i);
        pp_c_l1(1)(i) <= ((pp_c_vec(1)(i) xor pp_s_vec(2)(i)) and pp_c_vec(2)(i)) or (pp_c_vec(1)(i) and pp_s_vec(2)(i));

        pp_s_l1(2)(i) <= pp_s_vec(3)(i) xor pp_c_vec(3)(i) xor pp_s_vec(4)(i);
        pp_c_l1(2)(i) <= ((pp_s_vec(3)(i) xor pp_c_vec(3)(i)) and pp_s_vec(4)(i)) or (pp_s_vec(3)(i) and pp_c_vec(3)(i));
        
        pp_s_l1(3)(i) <= pp_c_vec(4)(i) xor pp_s_vec(5)(i) xor pp_c_vec(5)(i);
        pp_c_l1(3)(i) <= ((pp_c_vec(4)(i) xor pp_s_vec(5)(i)) and pp_c_vec(5)(i)) or (pp_c_vec(4)(i) and pp_s_vec(5)(i));
        
        pp_s_l1(4)(i) <= pp_s_vec(6)(i) xor pp_c_vec(6)(i) xor pp_s_vec(7)(i);
        pp_c_l1(4)(i) <= ((pp_s_vec(6)(i) xor pp_c_vec(6)(i)) and pp_s_vec(7)(i)) or (pp_s_vec(6)(i) and pp_c_vec(6)(i));
        
        pp_s_l1(5)(i) <= pp_c_vec(7)(i);
        
    end generate;
    
    pp_ec_l1(0) <= pp_c_l1(0)(62 downto 0) & '0';
    pp_ec_l1(1) <= pp_c_l1(1)(62 downto 0) & '0';
    pp_ec_l1(2) <= pp_c_l1(2)(62 downto 0) & '0';
    pp_ec_l1(3) <= pp_c_l1(3)(62 downto 0) & '0';
    pp_ec_l1(4) <= pp_c_l1(4)(62 downto 0) & '0';
    
    -- Carry-Save Level 2 instances
    carry_save_l2_gen : for i in 0 to 63 generate
        pp_s_l2(0)(i) <= pp_s_l1(0)(i) xor pp_ec_l1(0)(i) xor pp_s_l1(1)(i);
        pp_c_l2(0)(i) <= ((pp_s_l1(0)(i) xor pp_ec_l1(0)(i)) and pp_s_l1(1)(i)) or (pp_s_l1(0)(i) and pp_ec_l1(0)(i));
        
        pp_s_l2(1)(i) <= pp_ec_l1(1)(i) xor pp_s_l1(2)(i) xor pp_ec_l1(2)(i);
        pp_c_l2(1)(i) <= ((pp_ec_l1(1)(i) xor pp_s_l1(2)(i)) and pp_ec_l1(2)(i)) or (pp_ec_l1(1)(i) and pp_s_l1(2)(i));

        pp_s_l2(2)(i) <= pp_s_l1(3)(i) xor pp_ec_l1(3)(i) xor pp_s_l1(4)(i);
        pp_c_l2(2)(i) <= ((pp_s_l1(3)(i) xor pp_ec_l1(3)(i)) and pp_s_l1(4)(i)) or (pp_s_l1(3)(i) and pp_ec_l1(3)(i));
        
        pp_s_l2(3)(i) <= pp_ec_l1(4)(i);
        pp_c_l2(3)(i) <= pp_s_l1(5)(i);
        
    end generate;
    
    pp_ec_l2(0) <= pp_c_l2(0)(62 downto 0) & '0';
    pp_ec_l2(1) <= pp_c_l2(1)(62 downto 0) & '0';
    pp_ec_l2(2) <= pp_c_l2(2)(62 downto 0) & '0';
    --pp_ec_l2(3) <= pp_c_l2(3)(62 downto 0) & '0';
        
    -- Carry-Save Level 3 instances
    carry_save_l3_gen : for i in 0 to 63 generate
        pp_s_l3(0)(i) <= pp_s_l2(0)(i) xor pp_ec_l2(0)(i) xor pp_s_l2(1)(i);
        pp_c_l3(0)(i) <= ((pp_s_l2(0)(i) xor pp_ec_l2(0)(i)) and pp_s_l2(1)(i)) or (pp_s_l2(0)(i) and pp_ec_l2(0)(i));
        
        pp_s_l3(1)(i) <= pp_ec_l2(1)(i) xor pp_s_l2(2)(i) xor pp_ec_l2(2)(i);
        pp_c_l3(1)(i) <= ((pp_ec_l2(1)(i) xor pp_s_l2(2)(i)) and pp_ec_l2(2)(i)) or (pp_ec_l2(1)(i) and pp_s_l2(2)(i));

        pp_s_l3(2)(i) <= pp_s_l2(3)(i);
        pp_c_l3(2)(i) <= pp_c_l2(3)(i); -- carry ja foi shiftado 1 vez
        
    end generate;
    
    pp_ec_l3(0) <= pp_c_l3(0)(62 downto 0) & '0';
    pp_ec_l3(1) <= pp_c_l3(1)(62 downto 0) & '0';
    pp_ec_l3(2) <= pp_c_l3(2);  -- carry ja foi shiftado 1 vez
    
    -- Carry-Save Level 4 instances
    carry_save_l4_gen : for i in 0 to 63 generate
        pp_s_l4(0)(i) <= pp_s_l3(0)(i) xor pp_ec_l3(0)(i) xor pp_s_l3(1)(i);
        pp_c_l4(0)(i) <= ((pp_s_l3(0)(i) xor pp_ec_l3(0)(i)) and pp_s_l3(1)(i)) or (pp_s_l3(0)(i) and pp_ec_l3(0)(i));
        
        pp_s_l4(1)(i) <= pp_ec_l3(1)(i) xor pp_s_l3(2)(i) xor pp_ec_l3(2)(i);
        pp_c_l4(1)(i) <= ((pp_ec_l3(1)(i) xor pp_s_l3(2)(i)) and pp_ec_l3(2)(i)) or (pp_ec_l3(1)(i) and pp_s_l3(2)(i));
        
    end generate;
     
    pp_ec_l4(0) <= pp_c_l4(0)(62 downto 0) & '0';
    pp_ec_l4(1) <= pp_c_l4(1)(62 downto 0) & '0';
    
    -- Carry-Save Level 5 instances
    carry_save_l5_gen : for i in 0 to 63 generate
        pp_s_l5(0)(i) <= pp_s_l4(0)(i) xor pp_ec_l4(0)(i) xor pp_s_l4(1)(i);
        pp_c_l5(0)(i) <= ((pp_s_l4(0)(i) xor pp_ec_l4(0)(i)) and pp_s_l4(1)(i)) or (pp_s_l4(0)(i) and pp_ec_l4(0)(i));
        
        pp_s_l5(1)(i) <= pp_ec_l4(1)(i);

    end generate;
    
    pp_ec_l5(0) <= pp_c_l5(0)(62 downto 0) & '0';
        
    -- Carry-Save Level 6 instances
    carry_save_l6_gen : for i in 0 to 63 generate
        pp_s_l6(0)(i) <= pp_s_l5(0)(i) xor pp_ec_l5(0)(i) xor pp_s_l5(1)(i);
        pp_c_l6(0)(i) <= ((pp_s_l5(0)(i) xor pp_ec_l5(0)(i)) and pp_s_l5(1)(i)) or (pp_s_l5(0)(i) and pp_ec_l5(0)(i));
        
    end generate;
    
    s <= pp_s_l6(0);
    c <= pp_c_l6(0);
    
end Behavioral;
