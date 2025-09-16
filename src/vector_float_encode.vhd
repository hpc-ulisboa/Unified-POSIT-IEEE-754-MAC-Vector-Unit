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

entity vector_float_encode is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32);
    Port ( Config_port: in std_logic_vector(1 downto 0);
           qNaN : in std_logic_vector(3 downto 0);
           sNaN : in std_logic_vector(3 downto 0);
           inf : in std_logic_vector(3 downto 0);
           zero : in std_logic_vector(3 downto 0);
           sig : in std_logic_vector(3 downto 0);
           sf : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
           frac : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
           sticky : in std_logic_vector(3 downto 0);
           inexact : out std_logic_vector(3 downto 0);
           underflow : out std_logic_vector(3 downto 0);
           overflow : out std_logic_vector(3 downto 0);
           invalid : out std_logic_vector(3 downto 0);
           s_fp : out std_logic_vector(G_DATA_WIDTH-1 downto 0) );
end vector_float_encode;

architecture Behavioral of vector_float_encode is
    
    constant EXP_WIDTH_8 : integer := EXP_width(G_DATA_WIDTH/4);
    constant EXP_WIDTH_16 : integer := EXP_width(G_DATA_WIDTH/2);
    constant EXP_WIDTH_32 : integer := EXP_width(G_DATA_WIDTH);
    
    constant FRAC_WIDTH_8 : integer := G_DATA_WIDTH/4-EXP_WIDTH_8-1;
    constant FRAC_WIDTH_16 : integer := G_DATA_WIDTH/2-EXP_WIDTH_16-1;
    constant FRAC_WIDTH_32 : integer := G_DATA_WIDTH-EXP_WIDTH_32-1;
    
    
    constant BIAS_8 : integer := 2**(EXP_WIDTH_8-1)-1;
    constant BIAS_16 : integer := 2**(EXP_WIDTH_16-1)-1;
    constant BIAS_32 : integer := 2**(EXP_WIDTH_32-1)-1;
    
    constant BIAS_8_V : std_logic_vector (G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(BIAS_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(BIAS_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(BIAS_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(BIAS_8, G_DATA_WIDTH/4));
    constant BIAS_16_V : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(BIAS_16, G_DATA_WIDTH/2)) & std_logic_vector(to_unsigned(BIAS_16, G_DATA_WIDTH/2));
    constant BIAS_32_V : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(BIAS_32, G_DATA_WIDTH));
    
    signal BIAS, sf_biased: std_logic_vector (G_DATA_WIDTH-1 downto 0);
    signal sf_zero, sf_biased_sign_ext : std_logic_vector (3 downto 0);
    signal denormal, den_ovf : std_logic_vector (3 downto 0);
    signal sf_shamt: std_logic_vector(4*log2(G_DATA_WIDTH/4)-1 downto 0);
    signal frac_den: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal t_sticky_den: std_logic_vector (3 downto 0);
    signal a_exp: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal frac_unrounded, unrounded: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal lsb, guard, round: std_logic_vector(3 downto 0);
    signal t_sticky_8_0, t_sticky_16_0: std_logic;
    signal t_sticky, sticky_enc: std_logic_vector(3 downto 0);
    signal round_up: std_logic_vector(3 downto 0);
    signal pre_float: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal ovf, r_inf, NaN : std_logic_vector (3 downto 0);
    signal canonical_NaN, infinity: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    signal und_lsb, und_guard, und_round: std_logic_vector(3 downto 0);
    signal und_t_sticky_8_0, und_t_sticky_16_0: std_logic;
    signal und_t_sticky, und_sticky: std_logic_vector(3 downto 0);
    signal und_round_up, und_ovf_frac: std_logic_vector(3 downto 0);
    signal und_round_up_v: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal config_ext_adj, excep, discarded: std_logic_vector(3 downto 0);
    
begin
    
    BIAS <= BIAS_32_V when Config_port(1)='0' else
            BIAS_16_V when Config_port(0)='0' else
            BIAS_8_V;
            
    add_bias: vector_adder generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
              port map (Config_port => Config_port, A => sf, B => BIAS, C_in => "0000", S => sf_biased, C_out => open);
    
    -- Denormal frac adjustment
    exp_zero: vector_zero_detect generic map (G_DATA_WIDTH => G_DATA_WIDTH)
              port map (Config_port => Config_port, v_a => sf_biased, v_z => sf_zero);
    
    sf_biased_sign_ext <= (3 downto 0 => sf_biased(G_DATA_WIDTH-1)) when Config_port(1)='0' else 
                          sf_biased(G_DATA_WIDTH-1) & sf_biased(G_DATA_WIDTH-1) & sf_biased(G_DATA_WIDTH/2-1) & sf_biased(G_DATA_WIDTH/2-1) when Config_port(0)='0' else
                          sf_biased(G_DATA_WIDTH-1) & sf_biased(G_DATA_WIDTH*3/4-1) & sf_biased(G_DATA_WIDTH/2-1) & sf_biased(G_DATA_WIDTH/4-1);
                                         
    denormal <= sf_biased_sign_ext or sf_zero;
    

    den_ovf(0) <= not is_all_ones(sf_biased(12 downto 5)) when Config_port(1)='0' else
                  not is_all_ones(sf_biased(11 downto 4)) when Config_port(0)='0' else
                  not is_all_ones(sf_biased(6 downto 3));
    
    den_ovf(1) <= not is_all_ones(sf_biased(14 downto 11)) when Config_port="11" else
                  '0';
                  
    den_ovf(2) <= '0' when Config_port(1)='0' else
                  not is_all_ones(sf_biased(27 downto 20)) when Config_port(0)='0' else
                  not is_all_ones(sf_biased(22 downto 19));
    
    den_ovf(3) <= not is_all_ones(sf_biased(30 downto 27)) when Config_port="11" else
                  '0';
    
    sf_shamt(2 downto 0) <= (others => '0') when den_ovf(0)='1' else
                            sf_biased(2 downto 0);

    sf_shamt(5 downto 3) <= sf_biased(10 downto 8) when Config_port="11" and den_ovf(1)= '0' else
                            sf_biased(5 downto 3) when not (Config_port="11") and den_ovf(0)= '0' else
                            (others => '0');
    
    sf_shamt(8 downto 6) <= (others => '0') when den_ovf(2)='1' else
                            sf_biased(18 downto 16);

    sf_shamt(11 downto 9) <= sf_biased(26 downto 24) when Config_port="11" and den_ovf(3)= '0' else
                             sf_biased(21 downto 19) when Config_port(1)='1' and den_ovf(2)= '0' else
                             (others => '0');
                             
    -- special shifter. sf_zero='0'=> shift 1, shamout(0)='0' => shift 1, shamout(1)='0' => shift 2, etc
    den_exp : vector_barrel_sr_den
              port map(config_port => config_port, a => frac, shamtv => sf_shamt, zero => sf_zero, s => frac_den, sticky => t_sticky_den);
    
    exp_sel: for i in 0 to 3 generate
        a_exp((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= sf_biased((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when denormal(i) = '0' else
                                                                 (others => '0');
                 
    end generate;
    
    --     1 1    0
    --     1 0    frac((i+1)*G_DATA_WIDTH/4-1) /G_DATA_WIDTH*3/4
    --     0 1    frac((i+1)*G_DATA_WIDTH/4-1) /G_DATA_WIDTH*3/4
    --     0 0    frac((i+1)*G_DATA_WIDTH/4-1) /G_DATA_WIDTH*3/4
    frac_unrounded(G_DATA_WIDTH/4-1 downto 0) <= frac_den(G_DATA_WIDTH/4-1 downto 0) when denormal(0)='1' else
                                                 ((config_port(1) nand config_port(0)) and frac(G_DATA_WIDTH/4-1)) & frac(G_DATA_WIDTH/4-2 downto 0);
    
    frac_unrounded(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) <= frac_den(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) when denormal(2)='1' else
                                                                ((config_port(1) nand config_port(0)) and frac(G_DATA_WIDTH*3/4-1)) & frac(G_DATA_WIDTH*3/4-2 downto G_DATA_WIDTH/2);  
    --     1 1    0
    --     1 0    0
    --     0 1    frac((i+1)*G_DATA_WIDTH/2-1)
    --     0 0    frac((i+1)*G_DATA_WIDTH/2-1)                                                 
    frac_unrounded(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) <= frac_den(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) when denormal(1)='1' else
                                                              (not config_port(1) and frac(G_DATA_WIDTH/2-1)) & frac(G_DATA_WIDTH/2-2 downto G_DATA_WIDTH/4);
    -- '0'
    frac_unrounded(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) <= frac_den(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) when denormal(3)='1' else
                                                              '0' & frac(G_DATA_WIDTH-2 downto G_DATA_WIDTH*3/4);                                                          
    
    unrounded <= sig(0) & a_exp(EXP_WIDTH_32-1 downto 0) & frac_unrounded(G_DATA_WIDTH-2 downto G_DATA_WIDTH-FRAC_WIDTH_32-1) when Config_port(1)='0' else 
                 sig(2) & a_exp(G_DATA_WIDTH/2+EXP_WIDTH_16-1 downto G_DATA_WIDTH/2) & frac_unrounded(G_DATA_WIDTH-2 downto G_DATA_WIDTH-FRAC_WIDTH_16-1) & sig(0) & a_exp(EXP_WIDTH_16-1 downto 0) & frac_unrounded(G_DATA_WIDTH/2-2 downto G_DATA_WIDTH/2-FRAC_WIDTH_16-1) when Config_port(0)='0' else
                 sig(3) & a_exp(G_DATA_WIDTH*3/4+EXP_WIDTH_8-1 downto G_DATA_WIDTH*3/4) & frac_unrounded(G_DATA_WIDTH-2 downto G_DATA_WIDTH-FRAC_WIDTH_8-1) & sig(2) & a_exp(G_DATA_WIDTH/2+EXP_WIDTH_8-1 downto G_DATA_WIDTH/2) & frac_unrounded(G_DATA_WIDTH*3/4-2 downto G_DATA_WIDTH*3/4-FRAC_WIDTH_8-1) &
                 sig(1) & a_exp(G_DATA_WIDTH/4+EXP_WIDTH_8-1 downto G_DATA_WIDTH/4) & frac_unrounded(G_DATA_WIDTH/2-2 downto G_DATA_WIDTH/2-FRAC_WIDTH_8-1) & sig(0) & a_exp(EXP_WIDTH_8-1 downto 0) & frac_unrounded(G_DATA_WIDTH/4-2 downto G_DATA_WIDTH/4-FRAC_WIDTH_8-1);
                                                        
    -- Rounding  
    lsb <= (3 downto 1 => '0', 0 => frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_32-1)) when config_port(1)='0' else
           '0' &  frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_16-1) & '0' & frac_unrounded(G_DATA_WIDTH/2-FRAC_WIDTH_16-1) when config_port(0)='0' else  
           frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_8-1) & frac_unrounded(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-1) & frac_unrounded(G_DATA_WIDTH/2-FRAC_WIDTH_8-1) & frac_unrounded(G_DATA_WIDTH/4-FRAC_WIDTH_8-1); 
           
    guard <= (3 downto 1 => '0', 0 => frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_32-2)) when config_port(1)='0' else
             '0' &  frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_16-2) & '0' & frac_unrounded(G_DATA_WIDTH/2-FRAC_WIDTH_16-2) when config_port(0)='0' else  
             frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_8-2) & frac_unrounded(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-2) & frac_unrounded(G_DATA_WIDTH/2-FRAC_WIDTH_8-2) & frac_unrounded(G_DATA_WIDTH/4-FRAC_WIDTH_8-2); 
             
    round <= (3 downto 1 => '0', 0 => frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_32-3)) when config_port(1)='0' else
             '0' &  frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_16-3) & '0' & frac_unrounded(G_DATA_WIDTH/2-FRAC_WIDTH_16-3) when config_port(0)='0' else  
             frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_8-3) & frac_unrounded(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-3) & frac_unrounded(G_DATA_WIDTH/2-FRAC_WIDTH_8-3) & frac_unrounded(G_DATA_WIDTH/4-FRAC_WIDTH_8-3); 
    

    t_sticky_8_0 <= or_reduce(frac_unrounded(G_DATA_WIDTH/4-FRAC_WIDTH_8-4 downto 0));
    t_sticky_16_0 <= t_sticky_8_0 or frac_unrounded(G_DATA_WIDTH/4-FRAC_WIDTH_8-3);
    t_sticky <= (3 downto 1 => '0', 0 => or_reduce(frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_32-4 downto G_DATA_WIDTH/4-FRAC_WIDTH_8-2)) or t_sticky_16_0) when config_port(1)='0' else
                '0' & or_reduce(frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_16-4 downto G_DATA_WIDTH/2)) & '0' & t_sticky_16_0 when config_port(0)='0' else
                or_reduce(frac_unrounded(G_DATA_WIDTH-FRAC_WIDTH_8-4 downto G_DATA_WIDTH*3/4)) & or_reduce(frac_unrounded(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-4 downto G_DATA_WIDTH/2)) & 
                or_reduce(frac_unrounded(G_DATA_WIDTH/2-FRAC_WIDTH_8-4 downto G_DATA_WIDTH/4)) & t_sticky_8_0;
    
    sticky_enc <= sticky or t_sticky or (denormal and t_sticky_den);
    
    round_up <= guard and (lsb or round or sticky_enc);
    
    add_round: vector_adder generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
               port map (Config_port => Config_port, A => unrounded, B => (others => '0'), C_in => round_up, S => pre_float, C_out => open);

    -- Exceptions
    ovf_logic: vector_float_ovf
               port map (Config_port => Config_port, sf => sf_biased, pre_float => pre_float, denormal => denormal, zero => zero, ovf => ovf);
    
    r_inf <= ovf or inf;
    
    NaN <= qNaN or sNaN;
    
    -- FP Pack
    canonical_NaN <= '0' & (EXP_WIDTH_32 downto 0 => '1') & (FRAC_WIDTH_32-2 downto 0 => '0') when config_port(1)='0' else
                     '0' & (EXP_WIDTH_16 downto 0 => '1') & (FRAC_WIDTH_16-2 downto 0 => '0') & '0' & (EXP_WIDTH_16 downto 0 => '1') & (FRAC_WIDTH_16-2 downto 0 => '0') when config_port(0)='0' else
                     '0' & (EXP_WIDTH_8 downto 0 => '1') & (FRAC_WIDTH_8-2 downto 0 => '0') & '0' & (EXP_WIDTH_8 downto 0 => '1') & (FRAC_WIDTH_8-2 downto 0 => '0') &
                     '0' & (EXP_WIDTH_8 downto 0 => '1') & (FRAC_WIDTH_8-2 downto 0 => '0') & '0' & (EXP_WIDTH_8 downto 0 => '1') & (FRAC_WIDTH_8-2 downto 0 => '0');
    
    infinity <= sig(0) & (EXP_WIDTH_32-1 downto 0 => '1') & (FRAC_WIDTH_32-1 downto 0 => '0') when config_port(1)='0' else
                sig(2) & (EXP_WIDTH_16-1 downto 0 => '1') & (FRAC_WIDTH_16-1 downto 0 => '0') & sig(0) & (EXP_WIDTH_16-1 downto 0 => '1') & (FRAC_WIDTH_16-1 downto 0 => '0') when config_port(0)='0' else
                sig(3) & (EXP_WIDTH_8-1 downto 0 => '1') & (FRAC_WIDTH_8-1 downto 0 => '0') & sig(2) & (EXP_WIDTH_8-1 downto 0 => '1') & (FRAC_WIDTH_8-1 downto 0 => '0') &
                sig(1) & (EXP_WIDTH_8-1 downto 0 => '1') & (FRAC_WIDTH_8-1 downto 0 => '0') & sig(0) & (EXP_WIDTH_8-1 downto 0 => '1') & (FRAC_WIDTH_8-1 downto 0 => '0');
    
    s_fp(G_DATA_WIDTH/4-1 downto 0) <= canonical_NaN(G_DATA_WIDTH/4-1 downto 0) when NaN(0) = '1' else
                                       infinity(G_DATA_WIDTH/4-1 downto 0) when r_inf(0) = '1' else 
                                       (config_port(1) and config_port(0) and sig(0)) & (G_DATA_WIDTH/4-2 downto 0 => '0') when zero(0) ='1' else
                                       pre_float(G_DATA_WIDTH/4-1 downto 0);
    
    s_fp(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) <= canonical_NaN(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) when NaN(1) = '1' else
                                                    infinity(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) when r_inf(1) = '1' else 
                                                    (config_port(1) and sig(1)) & (G_DATA_WIDTH/4-2 downto 0 => '0') when zero(1) ='1' else
                                                    pre_float(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4);
                                                    
    s_fp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) <= canonical_NaN(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) when NaN(2) = '1' else
                                                      infinity(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) when r_inf(2) = '1' else 
                                                      (config_port(1) and config_port(0) and sig(2)) & (G_DATA_WIDTH/4-2 downto 0 => '0') when zero(2) ='1' else
                                                      pre_float(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2);
 
    s_fp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) <= canonical_NaN(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) when NaN(3) = '1' else
                                                    infinity(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) when r_inf(3) = '1' else 
                                                    sig(3) & (G_DATA_WIDTH/4-2 downto 0 => '0') when zero(3) ='1' else
                                                    pre_float(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4);  
    
    --Underflow Logic (tininess) - round the result to the destination precision without regard for the exponent range.
    --If this temporary rounded result is not in the normal exponent range for the destination format, then the tininess condition occurs.
    
    und_lsb <= (3 downto 1 => '0', 0 => frac(G_DATA_WIDTH-FRAC_WIDTH_32-1)) when config_port(1)='0' else
               '0' &  frac(G_DATA_WIDTH-FRAC_WIDTH_16-1) & '0' & frac(G_DATA_WIDTH/2-FRAC_WIDTH_16-1) when config_port(0)='0' else  
               frac(G_DATA_WIDTH-FRAC_WIDTH_8-1) & frac(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-1) & frac(G_DATA_WIDTH/2-FRAC_WIDTH_8-1) & frac(G_DATA_WIDTH/4-FRAC_WIDTH_8-1); 
           
    und_guard <= (3 downto 1 => '0', 0 => frac(G_DATA_WIDTH-FRAC_WIDTH_32-2)) when config_port(1)='0' else
                 '0' &  frac(G_DATA_WIDTH-FRAC_WIDTH_16-2) & '0' & frac(G_DATA_WIDTH/2-FRAC_WIDTH_16-2) when config_port(0)='0' else  
                 frac(G_DATA_WIDTH-FRAC_WIDTH_8-2) & frac(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-2) & frac(G_DATA_WIDTH/2-FRAC_WIDTH_8-2) & frac(G_DATA_WIDTH/4-FRAC_WIDTH_8-2); 
             
    und_round <= (3 downto 1 => '0', 0 => frac(G_DATA_WIDTH-FRAC_WIDTH_32-3)) when config_port(1)='0' else
                 '0' &  frac(G_DATA_WIDTH-FRAC_WIDTH_16-3) & '0' & frac(G_DATA_WIDTH/2-FRAC_WIDTH_16-3) when config_port(0)='0' else  
                 frac(G_DATA_WIDTH-FRAC_WIDTH_8-3) & frac(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-3) & frac(G_DATA_WIDTH/2-FRAC_WIDTH_8-3) & frac(G_DATA_WIDTH/4-FRAC_WIDTH_8-3); 
    

    und_t_sticky_8_0 <= or_reduce(frac(G_DATA_WIDTH/4-FRAC_WIDTH_8-4 downto 0));
    und_t_sticky_16_0 <= und_t_sticky_8_0 or frac(G_DATA_WIDTH/4-FRAC_WIDTH_8-3);
    und_t_sticky <= (3 downto 1 => '0', 0 => or_reduce(frac(G_DATA_WIDTH-FRAC_WIDTH_32-4 downto G_DATA_WIDTH/4-FRAC_WIDTH_8-2)) or t_sticky_16_0) when config_port(1)='0' else
                    '0' & or_reduce(frac(G_DATA_WIDTH-FRAC_WIDTH_16-4 downto G_DATA_WIDTH/2)) & '0' & und_t_sticky_16_0 when config_port(0)='0' else
                    or_reduce(frac(G_DATA_WIDTH-FRAC_WIDTH_8-4 downto G_DATA_WIDTH*3/4)) & or_reduce(frac(G_DATA_WIDTH*3/4-FRAC_WIDTH_8-4 downto G_DATA_WIDTH/2)) & 
                    or_reduce(frac(G_DATA_WIDTH/2-FRAC_WIDTH_8-4 downto G_DATA_WIDTH/4)) & und_t_sticky_8_0;
    
    und_sticky <= und_t_sticky or sticky;
    
    und_round_up <= und_guard and (und_lsb or und_round or und_sticky);

    und_round_up_v <= (FRAC_WIDTH_32-1 downto 0 => '0') & und_round_up(0) & (G_DATA_WIDTH-FRAC_WIDTH_32-2 downto 0 => '0') when config_port(1)='0' else
                      (FRAC_WIDTH_16-1 downto 0 => '0') & und_round_up(2) & (G_DATA_WIDTH/2-FRAC_WIDTH_16-2 downto 0 => '0') & (FRAC_WIDTH_16-1 downto 0 => '0') & und_round_up(0) & (G_DATA_WIDTH/2-FRAC_WIDTH_16-2 downto 0 => '0') when config_port(0)='0' else
                      (FRAC_WIDTH_8-1 downto 0 => '0') & und_round_up(3) & (G_DATA_WIDTH/4-FRAC_WIDTH_8-2 downto 0 => '0') & (FRAC_WIDTH_8-1 downto 0 => '0') & und_round_up(2) & (G_DATA_WIDTH/4-FRAC_WIDTH_8-2 downto 0 => '0') &
                      (FRAC_WIDTH_8-1 downto 0 => '0') & und_round_up(1) & (G_DATA_WIDTH/4-FRAC_WIDTH_8-2 downto 0 => '0') & (FRAC_WIDTH_8-1 downto 0 => '0') & und_round_up(0) & (G_DATA_WIDTH/4-FRAC_WIDTH_8-2 downto 0 => '0');
                        
    und_add_round: vector_adder generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
                   port map (Config_port => Config_port, A => frac, B => und_round_up_v, C_in => (others => '0'), S => open, C_out => und_ovf_frac);
    
    -- Status Flags
    config_ext_adj <= "0001" when config_port(1)='0' else
                      "0101" when config_port(0)='0' else
                      "1111";
                      
    excep <= (NaN nor inf) and config_ext_adj;
    discarded <= round or guard or sticky_enc;
    
    inexact <= (ovf or discarded) and excep;
    underflow <= (sf_biased_sign_ext or (sf_zero and (not und_ovf_frac)) or zero) and discarded and excep;
    overflow <= ovf and excep;
    invalid <= sNaN and config_ext_adj;
    
end Behavioral;
