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

entity vector_posit_decode is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3);
        
    Port (
        Config_port : in std_logic_vector(1 downto 0);
        es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
        pos : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        sig : out std_logic_vector(3 downto 0);
        sf : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        frac : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        nar : out std_logic_vector(3 downto 0);
        zero : out std_logic_vector(3 downto 0) );
end vector_posit_decode;

architecture Behavioral of vector_posit_decode is

    signal zero_ref : std_logic_vector(3 downto 0);
    signal reg_bit, inv_reg_bit :  std_logic_vector(3 downto 0);
    signal ref, ef, inv, inv_pos, ext_rbit : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal ref_0, ref_v, ef_0_l, ef_0 : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal zc, ext_rbit_16, inv_zc : std_logic_vector(G_DATA_WIDTH/2-1 downto 0);
    
    signal ff: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal ext_sig : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    signal s_reg : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal reg_ext: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    signal r_sig : std_logic_vector(3 downto 0);
    signal r_reg : std_logic_vector(G_DATA_WIDTH/2-1 downto 0);
    signal r_exp : std_logic_vector(2*(2**G_MAX_ES_SIZE-1)+2*(G_MAX_ES_SIZE)-1 downto 0);
    signal r_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);      
    signal r_nar : std_logic_vector(3 downto 0);
    signal r_zero : std_logic_vector(3 downto 0);
begin
    
    -- check posit for zero and NaR
    sign_zero: vector_zero_sign_detect 
               port map (config_port => Config_port, v_a => pos, v_z => zero_ref, v_s => r_sig);

    ---- 2's complement if sign = 1 (negative) ----
    ext_sig <= (7 downto 0 => r_sig(3)) & (7 downto 0 => r_sig(2)) & (7 downto 0 => r_sig(1)) & (7 downto 0 => r_sig(0));
    
    inv_pos <= pos xor ext_sig;
    -- 2's complemented posit
    comp_v: vector_adder generic map ( G_DATA_WIDTH => 32)                          
            port map (Config_port => Config_port, A => inv_pos, B => (31 downto 0 => '0'), C_in => r_sig, S => ref, C_out => open);
    
    ---- Regime decoding ----
    reg_bit <= (3 downto 0 => ref(G_DATA_WIDTH-2)) when Config_port(1)='0' else
               ref(G_DATA_WIDTH-2) & ref(G_DATA_WIDTH-2) & ref(G_DATA_WIDTH/2-2) & ref(G_DATA_WIDTH/2-2) when Config_port(0)='0' else
               ref(G_DATA_WIDTH-2) & ref(G_DATA_WIDTH*3/4-2) & ref(G_DATA_WIDTH/2-2) & ref(G_DATA_WIDTH/4-2);
               

    ref_0 <= ref(G_DATA_WIDTH-2 downto 0) & '0';
    ref_v <=  ref_0 when Config_port(1)='0' else  
              ref_0(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2+1) & '0' & ref_0(G_DATA_WIDTH/2-1 downto 0) when Config_port(0)='0' else 
              ref_0(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4+1) & '0' & ref_0(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2+1) & '0' & 
              ref_0(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4+1) & '0' & ref_0(G_DATA_WIDTH/4-1 downto 0);
    
    --invert to use only one LZC istead of a LZC and a LOC          
    ext_rbit <= (7 downto 0 => reg_bit(3)) & (7 downto 0 => reg_bit(2)) & (7 downto 0 => reg_bit(1)) & (7 downto 0 => reg_bit(0));
    inv <= ref_v xor ext_rbit;                                                                 -- Invert 1's to use only LZD
    
    leading_zeroes: vector_lzc32 
                    port map (config_port => Config_port, a => inv, c => zc, v => open);
    
    --- Regime value
    -- reg = 1 => zc(A) - 1(B)
    -- reg = 0 => -zc = !zc(A) +1(C_in)
    ext_rbit_16 <= (3 downto 0 => reg_bit(3)) & (3 downto 0 => reg_bit(2)) & (3 downto 0 => reg_bit(1)) & (3 downto 0 => reg_bit(0));
    inv_zc <= zc xnor ext_rbit_16;
    inv_reg_bit <= not reg_bit;
    Regime_v: vector_adder generic map ( G_DATA_WIDTH => 16)
              port map (Config_port => Config_port, A => inv_zc, B => ext_rbit_16, C_in => inv_reg_bit , S => r_reg, C_out => open);
              
              
    ---- Exponent & Fraction decoding ----
    -- shift out regime bits
    shift_out_regime: vector_barrel_sl 
                      port map (config_port => Config_port, a => ref_v, shamtv => zc, s => ef_0);
     -- shift out zc + 1
    ef_0_l <= ef_0(G_DATA_WIDTH-2 downto 0) & '0';
    ef <= ef_0_l when Config_port(1)='0' else  
          ef_0_l(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2+1) & '0' & ef_0_l(G_DATA_WIDTH/2-1 downto 0) when Config_port(0)='0' else --16
          ef_0_l(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4+1) & '0' & ef_0_l(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2+1) & '0' & 
          ef_0_l(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4+1) & '0' & ef_0_l(G_DATA_WIDTH/4-1 downto 0);
               
    -- exponent & fraction decoupling - through a shifter due to the dynamic es support
    split_exp_fraction: vector_barrel_sl_es_cpy
                        port map (config_port => Config_port, a => ef, shamt => es, s => ff, cpy => r_exp);
    
    r_frac <= "00" & not zero_ref(3) & ff(G_DATA_WIDTH-1 downto 3) when Config_port(1)='0' else -- 32 
              "00" & not zero_ref(3) & ff(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2+3) & "00" & not zero_ref(1) & ff(G_DATA_WIDTH/2-1 downto 3) when Config_port(0)='0' else -- 16
              "00" & not zero_ref(3) & ff(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4+3) & "00" & not zero_ref(2) & ff(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2+3) & "00" 
              & not zero_ref(1) & ff(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4+3) & "00" & not zero_ref(0) & ff(G_DATA_WIDTH/4-1 downto 3);
              
    
    -- Gather scale factors (exp+k*2^es)    
    reg_ext <= (15 downto 0 => r_reg(G_DATA_WIDTH/2-1)) & r_reg when Config_port(1)='0' else
               (7 downto 0 => r_reg(G_DATA_WIDTH/2-1)) & r_reg(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) & (7 downto 0 => r_reg(G_DATA_WIDTH/4-1)) & r_reg(G_DATA_WIDTH/4-1 downto 0) when Config_port(0)='0' else 
               (3 downto 0 => r_reg(G_DATA_WIDTH/2-1)) & r_reg(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH*3/8) & (3 downto 0 => r_reg(G_DATA_WIDTH*3/8-1)) & r_reg(G_DATA_WIDTH*3/8-1 downto G_DATA_WIDTH/4) & 
               (3 downto 0 => r_reg(G_DATA_WIDTH/4-1)) & r_reg(G_DATA_WIDTH/4-1 downto G_DATA_WIDTH/8) & (3 downto 0 => r_reg(G_DATA_WIDTH/8-1)) & r_reg(G_DATA_WIDTH/8-1 downto 0);
    
    -- k*2^es
    shift_sf : vector_barrel_sl_es 
               port map (config_port => Config_port, a => reg_ext, shamt => es, s => s_reg);
               
    -- the addition in exp+k*2^es can be interpreted as an OR since overlapping is mathematically impossible
    -- the exponent is in the form:
    --  000 0000000 000 xxxxxxx
    --  000 xxxxxxx 000 xxxxxxx
    --  xxx 0000xxx xxx 0000xxx
    r_sf <= s_reg(31 downto 27) & (s_reg(26 downto 24) or r_exp(19 downto 17)) & s_reg(23) & (s_reg(22 downto 16) or r_exp(16 downto 10)) & s_reg(15 downto 11) & (s_reg(10 downto 8) or r_exp(9 downto 7)) & s_reg(7) &(s_reg(6 downto 0) or r_exp(6 downto 0));
    
    r_nar <= r_sig and zero_ref;
    r_zero <= (not r_sig) and zero_ref;
    
    --seq: process(clk)
    --begin
       -- if rising_edge(clk) then
           sig <= r_sig;
           sf <= r_sf;
           frac <= r_frac;
           nar <= r_nar;
           zero <= r_zero;
       -- end if;
   --end process;

end Behavioral;
