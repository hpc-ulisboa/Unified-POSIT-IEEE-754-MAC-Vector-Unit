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


use work.vector_Pkg.all;

entity vector_quire_op is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3;
        constant C_QS : positive := 128);
    Port ( 
           clk : in std_logic;
           rst : in std_logic;
           a_stall : in std_logic;
           a_es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
           a_format : in std_logic;
           a_float_posit : in std_logic;
           a_Config_port : in std_logic_vector (1 downto 0);
           a_Config_port_full : in std_logic_vector (1 downto 0);
           a_full_precision : in std_logic;
           r_m_quire : in std_logic_vector(C_QS-1 downto 0);
           r_c_quire : in std_logic_vector(C_QS-1 downto 0);
           r_m_sf_fixed : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
           r_c_sf_fixed : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
           r_m_op_sig : in std_logic_vector(3 downto 0);
           r_c_op_sig : in std_logic_vector(3 downto 0);
           r_m_r_sig : in std_logic_vector(3 downto 0);
           r_c_r_sig : in std_logic_vector(3 downto 0);
           r_mult : in std_logic;
           r_acc : in std_logic;
           r_m_nar : in std_logic_vector(3 downto 0);
           r_m_zero : in std_logic_vector(3 downto 0);
           r_m_sNan : in std_logic_vector(3 downto 0);
           r_m_inf : in std_logic_vector(3 downto 0);
           r_c_nar : in std_logic_vector(3 downto 0);
           r_c_zero : in std_logic_vector(3 downto 0);
           r_c_sNaN : in std_logic_vector(3 downto 0);
           r_c_inf: in std_logic_vector(3 downto 0);
           
           quire_zero : in std_logic_vector(3 downto 0);
           r_quire_nar : in std_logic_vector(3 downto 0);
           r_sig : in std_logic_vector(3 downto 0);
           
           aa_stall : out std_logic;
           aa_es : out std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
           aa_format : out std_logic;
           aa_float_posit : out std_logic;
           aa_Config_port : out std_logic_vector (1 downto 0);
           aa_Config_port_full : out std_logic_vector (1 downto 0);
           aa_full_precision : out std_logic;
           aa_sticky: out std_logic_vector(3 downto 0);
           r_quire: out std_logic_vector(C_QS-1 downto 0);
           r_sub_min_loss: out std_logic_vector(3 downto 0);
           r_quire_sf: out std_logic_vector(G_DATA_WIDTH-1 downto 0);
           r_quire_nar_tmp: out std_logic_vector(3 downto 0);
           r_quire_sNaN: out std_logic_vector(3 downto 0);
           r_quire_inf: out std_logic_vector(3 downto 0);
           r_quire_zero: out std_logic_vector(3 downto 0);
           r_expt_sig : out std_logic_vector(3 downto 0);
           r_overflow: out std_logic_vector(3 downto 0)
     );
end vector_quire_op;

architecture Behavioral of vector_quire_op is


    -- Quire Accumulation / Addition
    signal add_quire : std_logic_vector(C_QS-1 downto 0);
    signal add_sf, inv_add_sf, sf_sub: std_logic_vector(G_DATA_WIDTH-1 downto 0);
	signal inv_r_m_sf_fixed, sf_sub_swap: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal add_zero, add_nar: std_logic_vector(3 downto 0);
    signal m_sf_fixed_sign, c_sf_fixed_sign : std_logic_vector(3 downto 0);
    signal m_sf_fixed_sign_full, c_sf_fixed_sign_full : std_logic_vector(3 downto 0);
    signal xor_sf, sf_inf, sf_inf_full, align_sel: std_logic_vector(3 downto 0);
    signal a_sf, align_shamt : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal align_quire, fixed_quire, shift_quire : std_logic_vector(C_QS-1 downto 0);
    signal align_sign, fixed_sign: std_logic_vector(3 downto 0);
    signal t_sticky: std_logic_vector(3 downto 0);
    signal diff_sign, sub_min_loss: std_logic_vector(3 downto 0);
    signal shift_quire_zero: std_logic_vector(3 downto 0);
    signal sat_16: std_logic;
    signal sat_sel : std_logic_vector(3 downto 0);
    signal sat_shamt : std_logic_vector(4*(log2(C_QS/4)+1)-1 downto 0);
    signal sf_inc, sf_cout: std_logic_vector(3 downto 0);
    signal quire_sf_sign, diff_sign_sf, overflow: std_logic_vector(3 downto 0);
    signal s_quire_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal s_quire_tmp, s_quire: std_logic_vector(C_QS-1 downto 0);
    
    
    signal add_sNaN, add_inf, add_sig : std_logic_vector(3 downto 0);
    signal s_quire_zero : std_logic_vector(3 downto 0);
    signal s_quire_inf : std_logic_vector(3 downto 0);
    signal s_quire_nar, s_quire_sNaN : std_logic_vector(3 downto 0);
    signal zero_sig, fp_inf_sig, expt_sig : std_logic_vector(3 downto 0); 
    
    
    signal quire : std_logic_vector(C_QS-1 downto 0);
    signal quire_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal quire_sNaN, quire_inf: std_logic_vector(3 downto 0); 

begin
    
    ---- Align and add/acc ----
    
    -- select from register or operand C
    add_quire <= quire when r_acc = '1' else
                 r_c_quire;
                 
    add_sf <= quire_sf when r_acc = '1' else
              r_c_sf_fixed;
              
    add_zero <= quire_zero when r_acc = '1' else
                r_c_zero;
    
    add_nar <= r_quire_nar when r_acc = '1' else
               r_c_nar;    
    
    -- equalize exponents
    m_sf_fixed_sign <= (others=> r_m_sf_fixed(G_DATA_WIDTH-1)) when a_Config_port(1)='0' else 
                        r_m_sf_fixed(G_DATA_WIDTH-1) & r_m_sf_fixed(G_DATA_WIDTH-1) & r_m_sf_fixed(G_DATA_WIDTH/2-1) & r_m_sf_fixed(G_DATA_WIDTH/2-1) when a_Config_port(0)='0' else 
                        r_m_sf_fixed(G_DATA_WIDTH-1) & r_m_sf_fixed(G_DATA_WIDTH*3/4-1) & r_m_sf_fixed(G_DATA_WIDTH/2-1) & r_m_sf_fixed(G_DATA_WIDTH/4-1);
    
    m_sf_fixed_sign_full <= (others=> m_sf_fixed_sign(0)) when a_full_precision='1' else
                            m_sf_fixed_sign;
    
    c_sf_fixed_sign <= (others=> add_sf(G_DATA_WIDTH-1)) when a_Config_port(1)='0' else 
                        add_sf(G_DATA_WIDTH-1) & add_sf(G_DATA_WIDTH-1) & add_sf(G_DATA_WIDTH/2-1) & add_sf(G_DATA_WIDTH/2-1) when a_Config_port(0)='0' else 
                        add_sf(G_DATA_WIDTH-1) & add_sf(G_DATA_WIDTH*3/4-1) & add_sf(G_DATA_WIDTH/2-1) & add_sf(G_DATA_WIDTH/4-1);
    
    c_sf_fixed_sign_full <= (others=> c_sf_fixed_sign(0)) when a_full_precision='1' else
                            c_sf_fixed_sign;
                     
    xor_sf <= m_sf_fixed_sign_full xor c_sf_fixed_sign_full;
             
    inv_add_sf <= not add_sf;         
    sf_comparison: vector_adder generic map ( G_DATA_WIDTH => 32)
                   port map (Config_port => a_Config_port, A => r_m_sf_fixed, B => inv_add_sf, C_in => "1111", S => sf_sub, C_out => open);
    
	inv_r_m_sf_fixed <= not r_m_sf_fixed;
    sf_comparison_swap: vector_adder generic map ( G_DATA_WIDTH => 32)
						port map (Config_port => a_Config_port, A => add_sf, B => inv_r_m_sf_fixed, C_in => "1111", S => sf_sub_swap, C_out => open);
	
    sf_inf <= (others=> sf_sub(G_DATA_WIDTH-1)) when a_Config_port(1)='0' else
              sf_sub(G_DATA_WIDTH-1) & sf_sub(G_DATA_WIDTH-1) & sf_sub(G_DATA_WIDTH/2-1) & sf_sub(G_DATA_WIDTH/2-1) when a_Config_port(0)='0' else 
              sf_sub(G_DATA_WIDTH-1) & sf_sub(G_DATA_WIDTH*3/4-1) & sf_sub(G_DATA_WIDTH/2-1) & sf_sub(G_DATA_WIDTH/4-1);  
    
    sf_inf_full <= (others=> sf_inf(0)) when a_full_precision='1' else
                   sf_inf;
    

    swap_logic: for i in 0 to 3 generate
        align_sel(i) <= '0' when (xor_sf(i) = '1' and m_sf_fixed_sign_full(i) = '0' and r_m_zero(i)='0') -- sfm > sfc and m != 0
                                 or (xor_sf(i) = '0' and not sf_inf_full(i)= '1' and r_m_zero(i)='0')   -- sfm >= sfc and m != 0
                                 or (add_zero(i)='1' and m_sf_fixed_sign_full(i)='1') else              -- c=0 and sfm<0
                        '1';
    end generate;
    
    swap: for i in 0 to 3 generate
        a_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= r_m_sf_fixed((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when align_sel(i)='0' else
                                                                add_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4); 
    
        --b_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= add_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when align_sel(i)='0' else
        --                                                        r_m_sf_fixed((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);    
        
        fixed_quire((i+1)*C_QS/4-1 downto i*C_QS/4) <= r_m_quire((i+1)*C_QS/4-1 downto i*C_QS/4) when align_sel(i) = '0' else
                                                       add_quire((i+1)*C_QS/4-1 downto i*C_QS/4);
        
        fixed_sign(i) <= r_c_r_sig(i) when align_sel(i) = '1' else
                         r_m_r_sig(i);
        
        align_quire((i+1)*C_QS/4-1 downto i*C_QS/4) <= r_m_quire((i+1)*C_QS/4-1 downto i*C_QS/4) when align_sel(i) = '1' else
                                                       add_quire((i+1)*C_QS/4-1 downto i*C_QS/4); 
        
        align_sign(i) <= r_m_r_sig(i) when align_sel(i) = '1' else
                         r_c_r_sig(i);
        
		align_shamt((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= sf_sub((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when align_sel(i) = '0' else
																	   sf_sub_swap((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
					
    end generate;
    	
    sat_16 <= or_reduce(align_shamt(12 downto 7));

    sat_sel(0) <= align_shamt(13) or sat_16 when a_Config_port(1)='0' else
                  sat_16 or (align_shamt(6) and not a_full_precision) when a_Config_port(0)='0' else
                  align_shamt(7) or (or_reduce(align_shamt(6 downto 5)) and not a_full_precision);
                  
    sat_sel(1) <= or_reduce(align_shamt(15 downto 13)) when a_Config_port_full="11" else
                  '0';
    
    sat_sel(2) <= '0' when a_Config_port(1)='0' else
                  or_reduce(align_shamt(28 downto 22)) when a_Config_port(0)='0' else
                  or_reduce(align_shamt(23 downto 21));
                  
    sat_sel(3) <= or_reduce(align_shamt(31 downto 29)) when a_Config_port="11" else
                  '0';
                  
    -- 8 bits does not sat in full precision mode
    sat_shamt(5 downto 0) <= align_shamt(5 downto 0) when sat_sel(0)= '0' else
                             (others => '1');
                                 
    sat_shamt(11 downto 6) <= align_shamt(13 downto 8) when sat_sel(1)= '0' else
                              align_shamt(11 downto 6) when not a_Config_port_full="11" and sat_sel(0)= '0' else
                              (others => '1');
    
    sat_shamt(17 downto 12) <= align_shamt(21 downto 16) when sat_sel(2)= '0' else
                               (others => '1'); 
    
    sat_shamt(23 downto 18) <= align_shamt(29 downto 24) when sat_sel(3)= '0' else
                               (others => '1');
                               
    
    align_shifter : vector_barrel_sr_round
                    port map(config_port => a_Config_port_full, a => align_quire, shamtv => sat_shamt, sign => align_sign, s => shift_quire, sticky => t_sticky);
    
    quire_all_shifted: vector_zero_detect generic map (G_DATA_WIDTH => C_QS)
                       port map (Config_port => a_Config_port, v_a => shift_quire, v_z => shift_quire_zero);
    
    diff_sign <= align_sign xor fixed_sign;
	-- TODO: This can be removed (temporary solution). When the effective operation is a subtration the carry-in of the complement cannot be '1'
    sub_min_loss <= ((shift_quire_zero and (diff_sign)) or (align_sign)) and t_sticky; 

    --aligned_quire <= shift_quire(C_QS-1 downto 1) & (shift_quire(0) or sub_min_loss);
    
    
    -- add quires
    quire_add: vector_adder generic map ( G_DATA_WIDTH => C_QS)
               port map (Config_port => a_Config_port_full, A => shift_quire, B => fixed_quire, C_in => "0000", S => s_quire_tmp, C_out => open);
               
    
    quire_adj: vector_quire_adjust
               port map (Config_port => a_Config_port_full, a => s_quire_tmp, s => s_quire, sf_inc => sf_inc);
    
    sf_add: vector_adder generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
            port map (Config_port => a_Config_port, A => a_sf, B => (others => '0'), C_in => sf_inc, S => s_quire_sf, C_out => sf_cout);
    
    quire_sf_sign <= (others=> s_quire_sf(G_DATA_WIDTH-1)) when a_Config_port(1)='0' else 
                     s_quire_sf(G_DATA_WIDTH-1) & s_quire_sf(G_DATA_WIDTH-1) & s_quire_sf(G_DATA_WIDTH/2-1) & s_quire_sf(G_DATA_WIDTH/2-1) when a_Config_port(0)='0' else 
                     s_quire_sf(G_DATA_WIDTH-1) & s_quire_sf(G_DATA_WIDTH*3/4-1) & s_quire_sf(G_DATA_WIDTH/2-1) & s_quire_sf(G_DATA_WIDTH/4-1);
    
    diff_sign_sf <= m_sf_fixed_sign xor c_sf_fixed_sign;
    
    overflow <= ((quire_sf_sign xor sf_cout) and not diff_sign_sf);
    
    -- fp exceptions 
    add_sNaN <= r_c_sNaN when r_acc = '0' else
                quire_sNaN;
    
    add_inf <= r_c_inf when r_acc = '0' else
               quire_inf;
               
    add_sig <= r_c_op_sig when r_acc = '0' else
               r_sig;
               
    s_quire_zero <= add_zero and r_m_zero;
 
    s_quire_inf <= r_m_inf or add_inf;   
            
    s_quire_nar <= add_nar or r_m_nar;
    
    -- sNaN or +inf-inf  
    s_quire_sNaN <= add_sNaN or r_m_sNan or ((r_m_inf and add_inf) and (r_m_op_sig xor add_sig));
    
    zero_sig <= r_m_op_sig and add_sig when r_mult='0' else
                r_m_op_sig;
                       
    sel_exp: for i in 0 to 3 generate
        fp_inf_sig(i) <= add_sig(i) when add_inf(i) ='1' else
                         r_m_op_sig(i);
                                
        expt_sig(i) <= fp_inf_sig(i) when s_quire_inf(i)='1' else
                       zero_sig(i);
    end generate;
            
                   
    seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                aa_es <= (others => '0');
                aa_format <= '0';
                aa_float_posit <= '0';
                aa_Config_port <= (others => '0');
                aa_Config_port_full <= (others => '0');
                aa_full_precision <= '0';
                aa_sticky <= (others => '0');
                quire <= (others => '0');
                r_sub_min_loss <= (others => '0');
                quire_sf <= (others => '0');
                r_quire_nar_tmp <= (others => '0');
                quire_sNaN <= (others => '0');
                quire_inf <= (others => '0');
                r_quire_zero <= (others => '0');
                r_expt_sig <= (others => '0');
                r_overflow <= (others => '0');
            elsif a_stall = '0' then
                aa_es <= a_es;
                aa_format <= a_format;
                aa_float_posit <= a_float_posit;
                aa_Config_port <= a_Config_port;
                aa_Config_port_full <= a_Config_port_full;
                aa_full_precision <= a_full_precision;
                aa_sticky <= t_sticky;
                quire <= s_quire;
                r_sub_min_loss <= sub_min_loss;
                quire_sf <= s_quire_sf;
                r_quire_nar_tmp <= s_quire_nar;
                quire_sNaN <= s_quire_sNaN;
                quire_inf <= s_quire_inf;
                r_quire_zero <= s_quire_zero;
                r_expt_sig <= expt_sig;
                r_overflow <= overflow;
            end if;        
        end if;
    end process;
    
    stall_seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                aa_stall <= '1';
            else
                aa_stall <= a_stall;
            end if;
        end if;
    end process; 
      
    r_quire <= quire;
    r_quire_sf <= quire_sf;
    r_quire_sNaN <= quire_sNaN;
    r_quire_inf <= quire_inf;
    
end Behavioral;
