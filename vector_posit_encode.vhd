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
use ieee.std_logic_misc.all;

use IEEE.NUMERIC_STD.ALL;


use work.vector_Pkg.all;

entity vector_posit_encode is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3);
    Port (es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
          Config_port : in std_logic_vector(1 downto 0);
          nar : in std_logic_vector(3 downto 0);
          zero : in std_logic_vector(3 downto 0);
          sig : in std_logic_vector(3 downto 0);
          sf : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
          frac : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
          sticky : in std_logic_vector(3 downto 0);
          s_pos : out std_logic_vector(G_DATA_WIDTH-1 downto 0) );
end vector_posit_encode;

architecture Behavioral of vector_posit_encode is
    
    constant C_MAX_EXP_SIZE_8 : positive := 3;
    constant C_MAX_EXP_SIZE_16 : positive := 4;
    constant C_MAX_EXP_SIZE_32 : positive := 5;
    
    constant MAX_REG_8 : std_logic_vector(4*C_MAX_EXP_SIZE_32-1 downto 0) :=  std_logic_vector(to_unsigned(G_DATA_WIDTH/4-2, C_MAX_EXP_SIZE_32)) & std_logic_vector(to_unsigned(G_DATA_WIDTH/4-2, C_MAX_EXP_SIZE_32)) & std_logic_vector(to_unsigned(G_DATA_WIDTH/4-2, C_MAX_EXP_SIZE_32)) & std_logic_vector(to_unsigned(G_DATA_WIDTH/4-2, C_MAX_EXP_SIZE_32));
    constant MAX_REG_16 : std_logic_vector(4*C_MAX_EXP_SIZE_32-1 downto 0) :=  std_logic_vector(to_unsigned(G_DATA_WIDTH/2-2, 2*C_MAX_EXP_SIZE_32)) & std_logic_vector(to_unsigned(G_DATA_WIDTH/2-2, 2*C_MAX_EXP_SIZE_32));
    constant MAX_REG_32 : std_logic_vector(4*C_MAX_EXP_SIZE_32-1 downto 0) :=  std_logic_vector(to_unsigned(G_DATA_WIDTH-2, 4*C_MAX_EXP_SIZE_32));
    
    signal sf_sign_ext : std_logic_vector(3 downto 0);
    signal t_sf_frac, sf_frac : std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
    signal t_sticky : std_logic_vector(3 downto 0);
    signal k, ext_cr, inv_k : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal abs_k : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal MAX_REG : std_logic_vector(4*C_MAX_EXP_SIZE_32-1 downto 0);
    signal efective_abs_k, inv_efective_abs_k : std_logic_vector(4*C_MAX_EXP_SIZE_32-1 downto 0);
    signal ovf_comp : std_logic_vector(4*C_MAX_EXP_SIZE_32-1 downto 0);
    signal ovf_reg : std_logic_vector(3 downto 0);
    signal offset, ext_sf_sign, reg : std_logic_vector(4*C_MAX_EXP_SIZE_8-1 downto 0);
    signal inv_sf_sign_ext: std_logic_vector(3 downto 0);
    signal pre_ref: std_logic_vector(4*(G_DATA_WIDTH/4+2)-1 downto 0);
    signal unrounded: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal lsb, guard, round : std_logic_vector(3 downto 0);
    signal t2_sticky, sticky_enc: std_logic_vector(3 downto 0);
    signal round_up, add_round: std_logic_vector(3 downto 0);
    signal rounded: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal sig_ext: std_logic_vector(3 downto 0);
    signal ext_pos, comp_rounded: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal pre_posit: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_pos :  std_logic_vector(G_DATA_WIDTH-1 downto 0);

begin
    
    -- Calculate resulting scale factor    
    sf_sign_ext <= (others=> sf(G_DATA_WIDTH-1))  when Config_port(1)='0' else
                   sf(G_DATA_WIDTH-1) & sf(G_DATA_WIDTH-1) & sf(G_DATA_WIDTH/2-1) & sf(G_DATA_WIDTH/2-1) when Config_port(0)='0' else
                   sf(G_DATA_WIDTH-1) & sf(G_DATA_WIDTH*3/4-1) & sf(G_DATA_WIDTH/2-1) & sf(G_DATA_WIDTH/4-1);
               
    -- Concat exp to fraction and extract regime
    t_sf_frac <= sf & frac(G_DATA_WIDTH-2 downto 0) & '0' when Config_port(1)='0' else                                                                                                                                        -- 32
                 sf(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) & frac(G_DATA_WIDTH-2 downto G_DATA_WIDTH/2) & '0' & sf(G_DATA_WIDTH/2-1 downto 0) & frac(G_DATA_WIDTH/2-2 downto 0) & '0' when Config_port(0)='0' else             -- 16
                 sf(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) & frac(G_DATA_WIDTH-2 downto G_DATA_WIDTH*3/4) & '0' & sf(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) & frac(G_DATA_WIDTH*3/4-2 downto G_DATA_WIDTH/2) & '0' &    -- 8 
                 sf(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) & frac(G_DATA_WIDTH/2-2 downto G_DATA_WIDTH/4) & '0' & sf(G_DATA_WIDTH/4-1 downto 0) & frac(G_DATA_WIDTH/4-2 downto 0) & '0';
    
      
    -- shift in exp and isolate regime
    shift_out_exp : vector_barrel_sr_ef
                    port map(config_port => Config_port, a => t_sf_frac, shamt => es, sign => sf_sign_ext, s => sf_frac, sticky => t_sticky);

    -- K must have 32 bits to support arithmetic with different exponents (higher to lower)
    k <= sf_frac(2*G_DATA_WIDTH-1 downto G_DATA_WIDTH) when Config_port(1)='0' else
         sf_frac(2*G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/2) & sf_frac(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) when Config_port(0)='0' else
         sf_frac(2*G_DATA_WIDTH-1 downto G_DATA_WIDTH*7/4) & sf_frac(G_DATA_WIDTH*3/2-1 downto G_DATA_WIDTH*5/4) &
         sf_frac(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) & sf_frac(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4); 
         
--    ef <= sf_frac(G_DATA_WIDTH-1 downto 0) when precision(4)='0' else 
--          sf_frac(G_DATA_WIDTH*3/2-1 downto G_DATA_WIDTH) & sf_frac(G_DATA_WIDTH/2-1 downto 0) when precision(3)='0' else
--          sf_frac(G_DATA_WIDTH*7/4-1 downto G_DATA_WIDTH*6/4) & sf_frac(G_DATA_WIDTH*5/4-1 downto G_DATA_WIDTH) &
--          sf_frac(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) & sf_frac(G_DATA_WIDTH/4-1 downto 0); 
    
    -- 2's complement regime
    ext_cr <= (7 downto 0 => sf_sign_ext(3)) & (7 downto 0 => sf_sign_ext(2)) & (7 downto 0 => sf_sign_ext(1)) & (7 downto 0 => sf_sign_ext(0));
    
    inv_k <= k xor ext_cr;
    
    k_comp: vector_adder generic map ( G_DATA_WIDTH => 32)
            port map (Config_port => Config_port, A => inv_k, B => (others => '0'), C_in => sf_sign_ext, S => abs_k, C_out => open);
        
    
    efective_abs_k <= abs_k(4*C_MAX_EXP_SIZE_32-1 downto 0) when Config_port(1)='0' else
                      abs_k(G_DATA_WIDTH/2+2*C_MAX_EXP_SIZE_32-1 downto G_DATA_WIDTH/2) & abs_k(2*C_MAX_EXP_SIZE_32-1 downto 0) when Config_port(0)='0' else
                      abs_k(G_DATA_WIDTH*3/4+C_MAX_EXP_SIZE_32-1 downto G_DATA_WIDTH*3/4) & abs_k(G_DATA_WIDTH/2+C_MAX_EXP_SIZE_32-1 downto G_DATA_WIDTH/2) & 
                      abs_k(G_DATA_WIDTH/4+C_MAX_EXP_SIZE_32-1 downto G_DATA_WIDTH/4) & abs_k(C_MAX_EXP_SIZE_32-1 downto 0);
    
    inv_efective_abs_k <= not efective_abs_k;
    
    
    MAX_REG <= MAX_REG_32 when Config_port(1)='0' else
               MAX_REG_16 when Config_port(0)='0' else
               MAX_REG_8;
    
    comp_abs_k: vector_adder generic map ( G_DATA_WIDTH => 4*C_MAX_EXP_SIZE_32)
                port map (Config_port => Config_port, A => MAX_REG, B => inv_efective_abs_k, C_in => "1111", S => ovf_comp, C_out => open);
    
    ovf_reg(0) <= ovf_comp(4*C_MAX_EXP_SIZE_32-1) when Config_port(1)='0' else
                  ovf_comp(2*C_MAX_EXP_SIZE_32-1) or or_reduce(abs_k(C_MAX_EXP_SIZE_16+2**G_MAX_ES_SIZE-1 downto 2*C_MAX_EXP_SIZE_32)) when Config_port(0)='0' else
                  ovf_comp(C_MAX_EXP_SIZE_32-1) or or_reduce(abs_k(C_MAX_EXP_SIZE_8+2**(G_MAX_ES_SIZE-1)-1 downto C_MAX_EXP_SIZE_32));
  
    ovf_reg(1) <= ovf_reg(0) when Config_port(1)='0' else
                  ovf_reg(0) when Config_port(0)='0' else
                  ovf_comp(2*C_MAX_EXP_SIZE_32-1) or or_reduce(abs_k(G_DATA_WIDTH/4+C_MAX_EXP_SIZE_8+2**(G_MAX_ES_SIZE-1)-1 downto G_DATA_WIDTH/4+C_MAX_EXP_SIZE_32));
    
    ovf_reg(2) <= ovf_comp(4*C_MAX_EXP_SIZE_32-1) when Config_port(1)='0' else
                  ovf_comp(4*C_MAX_EXP_SIZE_32-1) or or_reduce(abs_k(G_DATA_WIDTH/2+C_MAX_EXP_SIZE_16+2**G_MAX_ES_SIZE-1 downto G_DATA_WIDTH/2+2*C_MAX_EXP_SIZE_32)) when Config_port(0)='0' else
                  ovf_comp(3*C_MAX_EXP_SIZE_32-1) or or_reduce(abs_k(G_DATA_WIDTH/2+C_MAX_EXP_SIZE_8+2**(G_MAX_ES_SIZE-1)-1 downto G_DATA_WIDTH/2+C_MAX_EXP_SIZE_32));
                                
    ovf_reg(3) <= ovf_reg(2) when Config_port(1)='0' else 
                  ovf_reg(2) when Config_port(0)='0' else 
                  ovf_comp(4*C_MAX_EXP_SIZE_32-1) or or_reduce(abs_k(G_DATA_WIDTH*3/4+C_MAX_EXP_SIZE_8+2**(G_MAX_ES_SIZE-1)-1 downto G_DATA_WIDTH*3/4+C_MAX_EXP_SIZE_32));              
    
    
    -- shift in regime bits
    reg_ovf_process_0: for i in 0 to 1 generate
        offset((2*i+1)*C_MAX_EXP_SIZE_8-1 downto 2*i*C_MAX_EXP_SIZE_8) <= MAX_REG((2*i)*C_MAX_EXP_SIZE_32+C_MAX_EXP_SIZE_8-1 downto (2*i)*C_MAX_EXP_SIZE_32) when ovf_reg(2*i) = '1'  else 
                                                                          abs_k(i*G_DATA_WIDTH/2+C_MAX_EXP_SIZE_8-1 downto i*G_DATA_WIDTH/2);

    end generate;
    reg_ovf_process_1: for i in 0 to 1 generate
        offset((2*i+2)*C_MAX_EXP_SIZE_8-1 downto (2*i+1)*C_MAX_EXP_SIZE_8) <= MAX_REG((2*i+1)*C_MAX_EXP_SIZE_32+C_MAX_EXP_SIZE_8-1 downto (2*i+1)*C_MAX_EXP_SIZE_32) when ovf_reg((2*i+1)) = '1' and Config_port = "11" else 
                                                                              MAX_REG((2*i)*C_MAX_EXP_SIZE_32+2*C_MAX_EXP_SIZE_8-1 downto (2*i)*C_MAX_EXP_SIZE_32+C_MAX_EXP_SIZE_8) when ovf_reg((2*i+1)) = '1' else
                                                                              abs_k((2*i+1)*G_DATA_WIDTH/4+C_MAX_EXP_SIZE_8-1 downto (2*i+1)*G_DATA_WIDTH/4) when Config_port = "11" else
                                                                              abs_k(i*G_DATA_WIDTH/2+2*C_MAX_EXP_SIZE_8-1 downto i*G_DATA_WIDTH/2+C_MAX_EXP_SIZE_8);
    end generate;

    
    --reg = offset-1 if sf_sign = '1' else offset
    ext_sf_sign <= (C_MAX_EXP_SIZE_8-1 downto 0 => sf_sign_ext(3)) & (C_MAX_EXP_SIZE_8-1 downto 0 => sf_sign_ext(2)) & (C_MAX_EXP_SIZE_8-1 downto 0 => sf_sign_ext(1)) & (C_MAX_EXP_SIZE_8-1 downto 0 => sf_sign_ext(0));
    reg_shamt: vector_adder generic map ( G_DATA_WIDTH => 4*C_MAX_EXP_SIZE_8)
               port map (Config_port => Config_port, A => offset, B => ext_sf_sign, C_in => "0000", S => reg, C_out => open);  
                              
    inv_sf_sign_ext <= not sf_sign_ext;
    --pre_ref= "01" & ef when sf_sign = '1' else "10" & ef
    pre_ref <= (inv_sf_sign_ext(3)) & sf_sign_ext(3) & sf_frac(G_DATA_WIDTH-1 downto 0) & x"0" & "00" when Config_port(1)='0' else
               (inv_sf_sign_ext(3)) & sf_sign_ext(3) & sf_frac(G_DATA_WIDTH*3/2-1 downto G_DATA_WIDTH) & "00" & (inv_sf_sign_ext(2)) & sf_sign_ext(2) & sf_frac(G_DATA_WIDTH/2-1 downto 0) & "00" when Config_port(0)='0' else
               (inv_sf_sign_ext(3)) & sf_sign_ext(3) & sf_frac(G_DATA_WIDTH*7/4-1 downto G_DATA_WIDTH*6/4) & (inv_sf_sign_ext(2)) & sf_sign_ext(2) & sf_frac(G_DATA_WIDTH*5/4-1 downto G_DATA_WIDTH) &
               (inv_sf_sign_ext(1)) & sf_sign_ext(1) & sf_frac(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) & (inv_sf_sign_ext(0)) & sf_sign_ext(0) & sf_frac(G_DATA_WIDTH/4-1 downto 0);
    
    
    shift_in_regime : vector_barrel_sr_regime
                      port map(config_port => Config_port, a => pre_ref, shamtv => reg, sign => inv_sf_sign_ext, 
                      s => unrounded, lsb => lsb, guard => guard, round => round, sticky => t2_sticky);
    
    -- round fraction
    sticky_enc <= sticky or t_sticky or t2_sticky;

    round_up <= guard and (lsb or round or sticky_enc);

    add_round <= round_up and not ovf_reg;
    
    rounding: vector_adder generic map ( G_DATA_WIDTH => 32)
              port map (Config_port => Config_port, A => unrounded, B => (others => '0'), C_in => add_round, S => rounded, C_out => open);
    
    -- 2's complement
    sig_ext <= (others => sig(0)) when Config_port(1)='0' else
               sig(2) & sig(2) & sig(0) & sig(0) when Config_port(0)='0' else
               sig(3) & sig(2) & sig(1) & sig(0);  
               
    ext_pos <= (7 downto 0 => sig_ext(3)) & (7 downto 0 => sig_ext(2)) & (7 downto 0 => sig_ext(1)) & (7 downto 0 => sig_ext(0));
    comp_rounded <= rounded xor ext_pos;
    
    complement: vector_adder generic map ( G_DATA_WIDTH => 32)
                port map (Config_port => Config_port, A => comp_rounded, B => (others => '0'), C_in => sig, S => pre_posit, C_out => open);  
                

    r_pos(G_DATA_WIDTH/4-1 downto 0) <= (Config_port(1) and Config_port(0)) & (6 downto 0 => '0') when nar(0) = '1' else
                                        (others => '0') when zero(0) = '1' else
                                        pre_posit(G_DATA_WIDTH/4-1 downto 0);
                                        
    r_pos(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) <= Config_port(1) & (6 downto 0 => '0') when nar(1) = '1' else
                                                    (others => '0') when zero(1) = '1' else
                                                    pre_posit(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4);
    
    r_pos(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) <= (Config_port(1) and Config_port(0)) & (6 downto 0 => '0') when nar(2) = '1' else
                                                       (others => '0') when zero(2) = '1' else
                                                       pre_posit(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2);
                                                       
    r_pos(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) <= '1' & (6 downto 0 => '0') when nar(3) = '1' else
                                                     (others => '0') when zero(3) = '1' else
                                                     pre_posit(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4); 
                                                     
    --seq: process(clk)
    --begin
        --if rising_edge(clk) then
           s_pos <= r_pos;
        --end if;
    --end process;
    
end Behavioral;
