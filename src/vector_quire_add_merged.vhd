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
use ieee.std_logic_misc.all;

use work.vector_Pkg.all;

entity vector_quire_add_merged is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3);
    Port ( clk : in std_logic;
        acc : in std_logic;
        op : in std_logic_vector(1 downto 0);
        es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
        posit : in std_logic;
        float_posit : in std_logic;
        Config_port : in std_logic_vector(1 downto 0);
        full_precision : in std_logic;
        
        m_sig : in std_logic_vector(3 downto 0);
        m_sf  : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        m_frac : in std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
        m_nar : in std_logic_vector(3 downto 0);
        m_sNaN : in std_logic_vector(3 downto 0);
        m_zero : in std_logic_vector(3 downto 0);
        m_inf : in std_logic_vector(3 downto 0);
        
        c_sig : in std_logic_vector(3 downto 0);
        c_sf  : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        c_frac : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        c_nar : in std_logic_vector(3 downto 0);
        c_sNaN : in std_logic_vector(3 downto 0);
        c_zero : in std_logic_vector(3 downto 0);
        c_inf : in std_logic_vector(3 downto 0);
        
        s_es : out std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
        s_posit : out std_logic;
        s_float_posit: out std_logic;
        s_Config_port : out std_logic_vector(1 downto 0);
        s_sig : out std_logic_vector(3 downto 0);
        s_sf  : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        s_frac : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        s_nar : out std_logic_vector(3 downto 0);
        s_sNaN : out std_logic_vector(3 downto 0);
        s_inf : out std_logic_vector(3 downto 0);
        s_zero : out std_logic_vector(3 downto 0);
        s_sticky : out std_logic_vector(3 downto 0)
     );
end vector_quire_add_merged;

architecture Behavioral of vector_quire_add_merged is
    
    constant C_CG : integer := 7;
    constant C_NQ_8 : integer := 12;
    constant C_NQ_16 : integer := 28;
    constant C_NQ : integer := 60;
    constant C_QS : integer := 2*C_NQ+C_CG+1;
    
    
    constant Q_sa_size: positive := log2(C_QS/4);
    constant INT_SAT_8 : std_logic_vector (G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_NQ_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_NQ_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_NQ_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_NQ_8, G_DATA_WIDTH/4));
    constant INT_SAT_16 : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_NQ_16, G_DATA_WIDTH/2)) & std_logic_vector(to_unsigned(C_NQ_16, G_DATA_WIDTH/2));
    constant INT_SAT_32 : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_NQ, G_DATA_WIDTH));
    signal INT_SAT, inv_INT_SAT : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    constant CLZ_OFFSET_8 : std_logic_vector (G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_CG+C_NQ_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_CG+C_NQ_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_CG+C_NQ_8, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_CG+C_NQ_8, G_DATA_WIDTH/4));
    constant CLZ_OFFSET_16 : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_CG+C_NQ_16, G_DATA_WIDTH/2)) & std_logic_vector(to_unsigned(C_CG+C_NQ_16, G_DATA_WIDTH/2));
    constant CLZ_OFFSET_32 : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_CG+C_NQ, G_DATA_WIDTH));
    signal CLZ_OFFSET : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    
    
    signal Config_port_full: std_logic_vector (1 downto 0); 
    signal sf_full_ctrl, rst: std_logic_vector (3 downto 0);
    
    -- signals propagation
    signal a_es, aa_es, aaa_es : std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
    signal a_posit, aa_posit, aaa_posit : std_logic;
    signal a_float_posit, aa_float_posit, aaa_float_posit : std_logic;
    signal a_Config_port, aa_Config_port, aaa_Config_port : std_logic_vector (1 downto 0);
    signal a_Config_port_full, aa_Config_port_full, aaa_Config_port_full : std_logic_vector (1 downto 0);
    signal a_full_precision, aa_full_precision, aaa_full_precision : std_logic;
    
    -- m "fixed point" conversion
    signal m_r_sig, m_op_sig : std_logic_vector(3 downto 0);
    signal ext_mf, mf_inv, mf_cmp : std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
    signal m_sf_sign, m_sf_ovf : std_logic_vector(3 downto 0);
    signal m_sf_sign_full, m_sf_ovf_full : std_logic_vector(3 downto 0);
    signal m_sf_sat, m_sf_fixed : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal m_fixed_shamt : std_logic_vector(4*(log2(C_QS/4)+1)-1 downto 0);
    signal sm_frac, m_quire : std_logic_vector(C_QS-1 downto 0); 
    
    -- c "fixed point" conversion
    signal c_r_sig, c_op_sig : std_logic_vector(3 downto 0);
    signal ext_cf, mc_inv, mc_cmp : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal c_sf_sign, c_sf_ovf : std_logic_vector(3 downto 0);
    signal c_sf_sign_full, c_sf_ovf_full : std_logic_vector(3 downto 0);
    signal c_sf_sat, c_sf_fixed : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal c_fixed_shamt : std_logic_vector(4*(log2(C_QS/4)+1)-1 downto 0);
    signal sc_frac, c_quire : std_logic_vector(C_QS-1 downto 0);
    
    
    -- Outputs (registered) of "fixed point" conversion
    signal r_c_quire, r_m_quire: std_logic_vector(C_QS-1 downto 0);
    signal r_m_sf_fixed, r_c_sf_fixed: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_m_op_sig, r_c_op_sig: std_logic_vector(3 downto 0);
    signal r_m_r_sig, r_c_r_sig: std_logic_vector(3 downto 0);
    signal r_mult, r_acc : std_logic;
    signal r_m_nar, r_m_zero, r_m_inf, r_m_sNan : std_logic_vector(3 downto 0);
    signal r_c_nar, r_c_zero, r_c_inf, r_c_sNaN : std_logic_vector(3 downto 0);
    
    
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
    signal s_quire_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal s_quire: std_logic_vector(C_QS-1 downto 0);
    signal quire_Cout: std_logic_vector(3 downto 0);
    
    signal add_sNaN, add_inf, add_sig : std_logic_vector(3 downto 0);
    signal s_quire_zero : std_logic_vector(3 downto 0);
    signal s_quire_inf : std_logic_vector(3 downto 0);
    signal s_quire_nar, s_quire_sNaN : std_logic_vector(3 downto 0);
    signal zero_sig, fp_inf_sig, expt_sig : std_logic_vector(3 downto 0); 

    
    -- Outputs (registered) of Quire Accumulation / Addition
    signal aa_sticky : std_logic_vector(3 downto 0);
    signal r_sub_min_loss, r_diff_sign : std_logic_vector(3 downto 0);
    signal r_quire : std_logic_vector(C_QS-1 downto 0);
    signal r_quire_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_quire_nar_tmp, r_quire_sNaN : std_logic_vector(3 downto 0);
    signal r_quire_inf : std_logic_vector(3 downto 0);
    signal r_quire_zero, r_expt_sig : std_logic_vector(3 downto 0);
    signal r_quire_Cout: std_logic_vector(3 downto 0);
    
    -- Normalization
    signal v_zero, v_sign : std_logic_vector(3 downto 0);
    signal overflow, r_quire_nar: std_logic_vector(3 downto 0); 
    signal inv_quire_Cin : std_logic_vector(3 downto 0);
    signal quire_zero : std_logic_vector(3 downto 0);
    signal r_sig : std_logic_vector(3 downto 0);
    signal ext_q, inv_quire, comp_quire : std_logic_vector(C_QS-1 downto 0);
    signal zc : std_logic_vector(4*(log2(C_QS/4)+1)-1 downto 0);
    
    signal aaa_sticky : std_logic_vector(3 downto 0);
    signal ss_sig : std_logic_vector(3 downto 0);
    signal ss_comp_quire : std_logic_vector(C_QS-1 downto 0);
    signal ss_quire_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal ss_quire_nar, ss_quire_sNaN: std_logic_vector(3 downto 0);
    signal ss_quire_inf, ss_quire_zero : std_logic_vector(3 downto 0);
    signal ss_zc : std_logic_vector(4*(log2(C_QS/4)+1)-1 downto 0);
    
    signal r_frac, r_frac_tmp : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal n_t_sticky_full_16, n_t_sticky_full: std_logic;
    signal n_t_sticky, r_sticky: std_logic_vector(3 downto 0);
    signal pad_zc, inv_pad_zc : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_sf_offset, r_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);    

begin

    sf_full_ctrl <= "1111" when full_precision = '0' or Config_port(1)='0' else
                    "0011" when Config_port(0) = '0' else
                    "0001";
                    
    Config_port_full <= '0' & Config_port(0) when full_precision = '1' else
                        Config_port;

    
    -- TODO: alterar para suportar acc com apenas com um valor de 8 ou 16
    INT_SAT <= INT_SAT_32 when Config_port_full(1)='0' else
               INT_SAT_16 when Config_port(0)='0' else
               INT_SAT_8;
    
	--todo: usar constantes em vez de fazer o complemento para 2
    inv_INT_SAT <= not INT_SAT;
    
    ---- Convert fractions to quire(fixed-point) 2's complement ----
    --- m ---
	--Todo: não precisa ser bitwise, posso extender depois
    m_op_sig <= m_sig xor ((3 downto 0 => op(0)) and (3 downto 0 => acc)); 
    m_r_sig <= m_op_sig and not m_zero;
    
    -- 2's complement 
	--Todo: não precisa de ser o m_r_sig, pode ser o m_op_sig. O 2's complement de 0 é 0. O mesmo no carry in
    ext_mf <= (15 downto 0 => m_r_sig(3)) & (15 downto 0 => m_r_sig(2)) & (15 downto 0 => m_r_sig(1)) & (15 downto 0 => m_r_sig(0));
    
    mf_inv <= m_frac xor ext_mf;
    
    comp_m_frac: vector_adder generic map (G_DATA_WIDTH => 64)
                 port map (Config_port => Config_port_full, A => mf_inv, B => (63 downto 0 => '0'), C_in => m_r_sig, S => mf_cmp, C_out => open);
    
    -- sign extend
    sm_frac <= (C_NQ+C_CG-5 downto 0 => m_r_sig(3)) & mf_cmp & '0' when Config_port_full(1)='0' else   -- 1+7+60+60
               (C_NQ_16+C_CG-5 downto 0 => m_r_sig(3)) & mf_cmp(2*G_DATA_WIDTH-1 downto G_DATA_WIDTH) & '0' & (C_NQ_16+C_CG-5 downto 0 => m_r_sig(1)) & mf_cmp(G_DATA_WIDTH-1 downto 0) & '0' when Config_port(0)='0' else -- 1+7+28+28|1+7+28+28
               (C_NQ_8+C_CG-5 downto 0 => m_r_sig(3)) & mf_cmp(2*G_DATA_WIDTH-1 downto 2*G_DATA_WIDTH*3/4) & '0' & (C_NQ_8+C_CG-5 downto 0 => m_r_sig(2)) & mf_cmp(2*G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH) & '0' &-- 1+7+12+12|1+7+12+12|1+7+12+12|1+7+12+12
               (C_NQ_8+C_CG-5 downto 0 => m_r_sig(1)) & mf_cmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) & '0' & (C_NQ_8+C_CG-5 downto 0 => m_r_sig(0)) & mf_cmp(G_DATA_WIDTH/2-1 downto 0) & '0';  
    
    m_sat: vector_adder generic map ( G_DATA_WIDTH => 32)
           port map (Config_port => Config_port, A => m_sf, B => inv_INT_SAT, C_in => "1111", S => m_sf_sat, C_out => open);
    
    m_sf_sign <= (others=> m_sf(G_DATA_WIDTH-1)) when Config_port(1)='0' else
                 m_sf(G_DATA_WIDTH-1) & m_sf(G_DATA_WIDTH-1) & m_sf(G_DATA_WIDTH/2-1) & m_sf(G_DATA_WIDTH/2-1) when Config_port(0)='0' else
                 m_sf(G_DATA_WIDTH-1) & m_sf(G_DATA_WIDTH*3/4-1) & m_sf(G_DATA_WIDTH/2-1) & m_sf(G_DATA_WIDTH/4-1);
          
    m_sf_sign_full <= (others=> m_sf_sign(0)) when full_precision ='1' else
                      m_sf_sign;
    
    m_sf_ovf <= (others => m_sf_sat(G_DATA_WIDTH-1) nor m_sf(G_DATA_WIDTH-1)) when Config_port(1)='0' else
                (1 downto 0 => m_sf_sat(G_DATA_WIDTH-1) nor m_sf(G_DATA_WIDTH-1)) & (1 downto 0 => m_sf_sat(G_DATA_WIDTH/2-1) nor m_sf(G_DATA_WIDTH/2-1)) when Config_port(0)='0' else
                (m_sf_sat(G_DATA_WIDTH-1) nor m_sf(G_DATA_WIDTH-1)) & (m_sf_sat(G_DATA_WIDTH*3/4-1) nor m_sf(G_DATA_WIDTH*3/4-1)) & (m_sf_sat(G_DATA_WIDTH/2-1) nor m_sf(G_DATA_WIDTH/2-1)) & (m_sf_sat(G_DATA_WIDTH/4-1) nor m_sf(G_DATA_WIDTH/4-1)); 

    m_sf_ovf_full <= (others=> m_sf_ovf(0)) when full_precision ='1' else
                      m_sf_ovf;
                      
    --todo: alterar Q_sa_size, Q_sa_size+1 é = 8, substituir por G_DATA_WIDTH/4                  
    m_shamt: for i in 0 to 3 generate
        m_fixed_shamt((i+1)*Q_sa_size+i downto i*(Q_sa_size+1)) <= (others=> '0') when m_sf_sign_full(i)='1' or sf_full_ctrl(i)='0' else
                                                                    INT_SAT(i*G_DATA_WIDTH/4+Q_sa_size downto i*G_DATA_WIDTH/4) when m_sf_ovf_full(i)='1' else
                                                                    m_sf(i*G_DATA_WIDTH/4+Q_sa_size downto i*G_DATA_WIDTH/4);
    end generate;
    
    m_sf_fixedp: for i in 0 to 3 generate
        m_sf_fixed((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= m_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when m_sf_sign(i)='1' else
                                                                      m_sf_sat((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when m_sf_ovf(i)='1' else
                                                                      (others=> '0');
    end generate;
    
    m_fixed_conv: vector_barrel_sl_p generic map ( G_DATA_WIDTH => C_QS)
                  port map( config_port => Config_port_full, a => sm_frac, shamtv => m_fixed_shamt, s => m_quire);
    
    --- c ---
    c_op_sig <= c_sig xor (3 downto 0 => op(0));
    c_r_sig <= c_op_sig and not c_zero;    
    
    -- 2's complement 
	--Todo: não precisa de ser o c_r_sig, pode ser o c_op_sig. O 2's complement de 0 é 0. O mesmo no carry in
    ext_cf <= (7 downto 0 => c_r_sig(3)) & (7 downto 0 => c_r_sig(2)) & (7 downto 0 => c_r_sig(1)) & (7 downto 0 => c_r_sig(0));
    
    mc_inv <= c_frac xor ext_cf;
    
    comp_c_frac: vector_adder generic map ( G_DATA_WIDTH => 32)
                 port map (Config_port => Config_port_full, A => mc_inv, B => (31 downto 0 => '0'), C_in => c_r_sig, S => mc_cmp, C_out => open);
   
    -- sign extend
    sc_frac <= (C_NQ+C_CG-3 downto 0 => c_r_sig(3)) & mc_cmp & (G_DATA_WIDTH-2 downto 0 => '0') when Config_port_full(1)='0' else     -- 1+7+60+60
               (C_NQ_16+C_CG-3 downto 0 => c_r_sig(3)) & mc_cmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) & (G_DATA_WIDTH/2-2 downto 0 => '0') & (C_NQ_16+C_CG-3 downto 0 => c_r_sig(1)) & mc_cmp(G_DATA_WIDTH/2-1 downto 0) & (G_DATA_WIDTH/2-2 downto 0 => '0') when Config_port(0)='0' else -- 1+7+28+28|1+7+28+28
               (C_NQ_8+C_CG-3 downto 0 => c_r_sig(3)) & mc_cmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) & (G_DATA_WIDTH/4-2 downto 0 => '0') & (C_NQ_8+C_CG-3 downto 0 => c_r_sig(2)) & mc_cmp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) & (G_DATA_WIDTH/4-2 downto 0 => '0')       -- 1+7+12+12|1+7+12+12|1+7+12+12|1+7+12+12
               & (C_NQ_8+C_CG-3 downto 0 => c_r_sig(1)) & mc_cmp(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) & (G_DATA_WIDTH/4-2 downto 0 => '0') & (C_NQ_8+C_CG-3 downto 0 => c_r_sig(0)) & mc_cmp(G_DATA_WIDTH/4-1 downto 0) & (G_DATA_WIDTH/4-2 downto 0 => '0');  
       
    c_sat: vector_adder generic map ( G_DATA_WIDTH => 32)
           port map (Config_port => Config_port, A => c_sf, B => inv_INT_SAT, C_in => "1111", S => c_sf_sat, C_out => open);

    c_sf_sign <= (others=> c_sf(G_DATA_WIDTH-1)) when Config_port(1)='0' else
                 c_sf(G_DATA_WIDTH-1) & c_sf(G_DATA_WIDTH-1) & c_sf(G_DATA_WIDTH/2-1) & c_sf(G_DATA_WIDTH/2-1) when Config_port(0)='0' else
                 c_sf(G_DATA_WIDTH-1) & c_sf(G_DATA_WIDTH*3/4-1) & c_sf(G_DATA_WIDTH/2-1) & c_sf(G_DATA_WIDTH/4-1);
                 
    c_sf_sign_full <= (others=> c_sf_sign(0)) when full_precision ='1' else
                      c_sf_sign;
    
    c_sf_ovf <= (others => c_sf_sat(G_DATA_WIDTH-1) nor c_sf(G_DATA_WIDTH-1)) when Config_port(1)='0' else
                (1 downto 0 => c_sf_sat(G_DATA_WIDTH-1) nor c_sf(G_DATA_WIDTH-1)) & (1 downto 0 => c_sf_sat(G_DATA_WIDTH/2-1) nor c_sf(G_DATA_WIDTH/2-1)) when Config_port(0)='0' else
                (c_sf_sat(G_DATA_WIDTH-1) nor c_sf(G_DATA_WIDTH-1)) & (c_sf_sat(G_DATA_WIDTH*3/4-1) nor c_sf(G_DATA_WIDTH*3/4-1)) & (c_sf_sat(G_DATA_WIDTH/2-1) nor c_sf(G_DATA_WIDTH/2-1)) & (c_sf_sat(G_DATA_WIDTH/4-1) nor c_sf(G_DATA_WIDTH/4-1)); 
    
    c_sf_ovf_full <= (others=> c_sf_ovf(0)) when full_precision ='1' else
                      c_sf_ovf;
    
    c_shamt: for i in 0 to 3 generate
        c_fixed_shamt((i+1)*Q_sa_size+i downto i*(Q_sa_size+1)) <= (others=> '0') when c_sf_sign_full(i)='1' or sf_full_ctrl(i)='0' else
                                                                   INT_SAT(i*G_DATA_WIDTH/4+Q_sa_size downto i*G_DATA_WIDTH/4) when c_sf_ovf_full(i)='1' else
                                                                   c_sf(i*G_DATA_WIDTH/4+Q_sa_size downto i*G_DATA_WIDTH/4);
    end generate;
    
    c_sf_fixedp: for i in 0 to 3 generate
        c_sf_fixed((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= c_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when c_sf_sign(i)='1' else
                                                                      c_sf_sat((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when c_sf_ovf(i)='1' else
                                                                      (others=> '0');
    end generate;
    
    c_fixed_conv: vector_barrel_sl_p generic map ( G_DATA_WIDTH => C_QS)
                     port map( config_port => Config_port_full, a => sc_frac, shamtv => c_fixed_shamt, s => c_quire);
    
    split_add: process(clk)
    begin
       if rising_edge(clk) then
            a_es <= es;
            a_posit <= posit;
            a_float_posit <= float_posit;
            a_Config_port <= Config_port;
            a_Config_port_full <= Config_port_full;
            a_full_precision <= full_precision;
            r_m_quire <= m_quire;
            r_c_quire <= c_quire;
            r_m_sf_fixed <= m_sf_fixed;
            r_c_sf_fixed <= c_sf_fixed;
            r_m_op_sig <= m_op_sig;
            r_c_op_sig <= c_op_sig;
            r_m_r_sig <= m_r_sig;
            r_c_r_sig <= c_r_sig;
            r_mult <= op(1);
            r_acc <= acc;
            r_m_nar <= m_nar;
            r_m_zero <= m_zero; 
            r_m_sNan <= m_sNan;
            r_m_inf <= m_inf;
            r_c_nar <= c_nar;
            r_c_zero <= c_zero;
            r_c_sNaN <= c_sNaN;
            r_c_inf <= c_inf;
       end if;
    end process;
    
    ---- Align and add/acc ----
    
    -- select from register or operand C
    add_quire <= r_quire when r_acc = '1' else
                 r_c_quire;
                 
    add_sf <= r_quire_sf when r_acc = '1' else
              r_c_sf_fixed;
              
    add_zero <= quire_zero when r_acc = '1' else
                r_c_zero;
    
    add_nar <= r_quire_nar when r_acc = '1' else
               r_c_nar;    
    
    -- equalize exponents
    m_sf_fixed_sign <= (others=> r_m_sf_fixed(G_DATA_WIDTH-1)) when a_Config_port(1)='0' else 
                        r_m_sf_fixed(G_DATA_WIDTH-1) & r_m_sf_fixed(G_DATA_WIDTH-1) & r_m_sf_fixed(G_DATA_WIDTH/2-1) & r_m_sf_fixed(G_DATA_WIDTH/2-1) when a_Config_port(0)='0' else 
                        r_m_sf_fixed(G_DATA_WIDTH-1) & r_m_sf_fixed(G_DATA_WIDTH*3/4-1) & r_m_sf_fixed(G_DATA_WIDTH/2-1) & r_m_sf_fixed(G_DATA_WIDTH/4-1);
    --todo: apagar m_sf_fixed_sign_full e utilizar o m_sf_fixed_sign com o a_Config_port(1)='0' substituido por a_Config_port_full(1)='0'
    m_sf_fixed_sign_full <= (others=> m_sf_fixed_sign(0)) when a_full_precision='1' else
                            m_sf_fixed_sign;
    
    c_sf_fixed_sign <= (others=> add_sf(G_DATA_WIDTH-1)) when a_Config_port(1)='0' else 
                        add_sf(G_DATA_WIDTH-1) & add_sf(G_DATA_WIDTH-1) & add_sf(G_DATA_WIDTH/2-1) & add_sf(G_DATA_WIDTH/2-1) when a_Config_port(0)='0' else 
                        add_sf(G_DATA_WIDTH-1) & add_sf(G_DATA_WIDTH*3/4-1) & add_sf(G_DATA_WIDTH/2-1) & add_sf(G_DATA_WIDTH/4-1);
    --todo: apagar c_sf_fixed_sign_full e utilizar o c_sf_fixed_sign com o a_Config_port(1)='0' substituido por a_Config_port_full(1)='0'
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
                                                                --r_m_sf_fixed((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);    
        
        fixed_quire((i+1)*C_QS/4-1 downto i*C_QS/4) <= r_m_quire((i+1)*C_QS/4-1 downto i*C_QS/4) when align_sel(i) = '0' else
                                                       add_quire((i+1)*C_QS/4-1 downto i*C_QS/4);
        --todo: esta errado no caso de acc. substituir o r_c_r_sig por um sinal com o bit de sinal da quire
        fixed_sign(i) <= r_c_r_sig(i) when align_sel(i) = '1' else
                         r_m_r_sig(i);
        
        align_quire((i+1)*C_QS/4-1 downto i*C_QS/4) <= r_m_quire((i+1)*C_QS/4-1 downto i*C_QS/4) when align_sel(i) = '1' else
                                                       add_quire((i+1)*C_QS/4-1 downto i*C_QS/4); 
        --todo: esta errado no caso de acc. substituir o r_c_r_sig por um sinal com o bit de sinal da quire
        align_sign(i) <= r_m_r_sig(i) when align_sel(i) = '1' else
                         r_c_r_sig(i);
		
		align_shamt((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= sf_sub((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) when align_sel(i) = '0' else
																	   sf_sub_swap((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
                    
    end generate;
    
    s_quire_sf <= a_sf;
    
--    inv_b_sf <= not b_sf;
	--TODO: tentar com o sf_sub e utilizar o shifter que aceite shamt em 2's complement
--    sf_shamt: vector_adder generic map ( G_DATA_WIDTH => 32)
--              port map (Config_port => a_Config_port, A => a_sf, B => inv_b_sf, C_in => "1111", S => align_shamt, C_out => open);
              
    sat_16 <= or_reduce(align_shamt(12 downto 7));
    --Todo: Ver o que � melhor, Or reduce ou is_zero
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
    sub_min_loss <= ((shift_quire_zero and (diff_sign)) or (align_sign)) and t_sticky;

    --aligned_quire <= shift_quire(C_QS-1 downto 1) & (shift_quire(0) or sub_min_loss);
    
    
    -- add quires
    quire_add: vector_adder generic map ( G_DATA_WIDTH => C_QS)
               port map (Config_port => a_Config_port_full, A => shift_quire, B => fixed_quire, C_in => "0000", S => s_quire, C_out => quire_Cout);
    
    -- fp exceptions 
    add_sNaN <= r_c_sNaN when r_acc = '0' else
                r_quire_sNaN;
    
    add_inf <= r_c_inf when r_acc = '0' else
               r_quire_inf;
               
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
           aa_es <= a_es;
           aa_posit <= posit;
           aa_float_posit <= a_float_posit;
           aa_Config_port <= a_Config_port;
           aa_Config_port_full <= a_Config_port_full;
           aa_full_precision <= a_full_precision;
           aa_sticky <= t_sticky;
           r_quire <= s_quire;
           r_sub_min_loss <= sub_min_loss;
           r_diff_sign <= diff_sign;
           r_quire_sf <= s_quire_sf;
           r_quire_nar_tmp <= s_quire_nar;
           r_quire_sNaN <= s_quire_sNaN;
           r_quire_inf <= s_quire_inf;
           r_quire_zero <= s_quire_zero;
           r_expt_sig <= expt_sig;
           r_quire_Cout <= quire_Cout;
        end if;
    end process;
    

    sign_zero: vector_zero_sign_detect_p generic map (G_DATA_WIDTH => C_QS)
               port map (config_port => aa_Config_port_full, v_a => r_quire, v_z => v_zero, v_s => v_sign);
               
    -- nar or quire overflow
    overflow <= ((v_sign xor r_quire_Cout) and not r_diff_sign);
    r_quire_nar <= r_quire_nar_tmp or overflow;
    
    quire_zero <= r_quire_zero or v_zero;
    
    sign_exp: for i in 0 to 3 generate
        r_sig(i) <= r_expt_sig(i) when r_quire_zero(i)='1' or r_quire_inf(i)='1' else
                    v_sign(i);
    end generate;
    
    -- 2's complement             
    ext_q <= (31 downto 0 => v_sign(3)) & (31 downto 0 => v_sign(2)) & (31 downto 0 => v_sign(1)) & (31 downto 0 => v_sign(0));
    
    inv_quire <= r_quire xor ext_q;
    inv_quire_Cin <= (not r_sub_min_loss) and v_sign;
    quire_comp: vector_adder generic map ( G_DATA_WIDTH => C_QS)
                port map (Config_port => aa_Config_port_full, A => inv_quire, B => (others => '0'), C_in => inv_quire_Cin, S => comp_quire, C_out => open);
               

    leading_zeroes: vector_lzc128 
                    port map (config_port => aa_Config_port_full, a => comp_quire, c => zc, v => open);
    
--    split_seq: process(clk)
--    begin
--        if rising_edge(clk) then
            aaa_es <= aa_es;
            aaa_posit <= aa_posit;
            aaa_float_posit <= aa_float_posit;
            aaa_Config_port <= aa_Config_port;
            aaa_Config_port_full <= aa_Config_port_full;
            aaa_full_precision <= aa_full_precision;
            aaa_sticky <= aa_sticky;
            ss_sig <= r_sig;
            ss_comp_quire <= comp_quire;
            ss_quire_sf <= r_quire_sf;
            ss_quire_nar <= r_quire_nar;
            ss_quire_sNaN <= r_quire_sNaN;
            ss_quire_inf <= r_quire_inf;
            ss_quire_zero <= quire_zero;
            ss_zc <= zc;
--        end if;
--    end process;
    
    -- Todo: experimentar o resultado(s) com o final e n�o com os interm�dios (basta descomentar no componente)
    shift_fraction: vector_barrel_sl_round
                    port map (config_port => aaa_Config_port_full, a => ss_comp_quire, shamtv => ss_zc, s => r_frac_tmp, sticky => n_t_sticky);
    
    
    r_frac(G_DATA_WIDTH/4-1 downto 0) <= r_frac_tmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) when aaa_Config_port="11" and aaa_full_precision ='1' else
                                         r_frac_tmp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) when aaa_Config_port(1)='1' and aaa_full_precision ='1' else
                                         r_frac_tmp(G_DATA_WIDTH/4-1 downto 0);
                                                      
    r_frac(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) <= r_frac_tmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) when aaa_Config_port="10" and aaa_full_precision ='1' else
                                                      r_frac_tmp(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4);                                                    
    
    r_frac(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) <= r_frac_tmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2); 
    
    
    n_t_sticky_full_16 <= or_reduce(r_frac_tmp(G_DATA_WIDTH/2-1 downto 0));
    
    n_t_sticky_full <= or_reduce(r_frac_tmp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2)) or n_t_sticky_full_16 when aaa_Config_port ="11" else
                       n_t_sticky_full_16;
    
    
    r_sticky <= n_t_sticky or aaa_sticky or ("000" & n_t_sticky_full) when aaa_full_precision ='1' else
                n_t_sticky or aaa_sticky;
    
    --TODO: testar inverter e depois extender
    pad_zc <= x"00" & ss_zc when aaa_Config_port_full(1)='0' else 
              x"0" & ss_zc(4*(log2(C_QS/4)+1)-1 downto 2*(log2(C_QS/4)+1)) & x"0" & ss_zc(2*(log2(C_QS/4)+1)-1 downto 0) when aaa_Config_port(0)='0' else 
              "00" & ss_zc(4*(log2(C_QS/4)+1)-1 downto 3*(log2(C_QS/4)+1)) & "00" & ss_zc(3*(log2(C_QS/4)+1)-1 downto 2*(log2(C_QS/4)+1)) & 
              "00" & ss_zc(2*(log2(C_QS/4)+1)-1 downto (log2(C_QS/4)+1)) & "00" & ss_zc((log2(C_QS/4)+1)-1 downto 0);

    inv_pad_zc <= not pad_zc;
    

    CLZ_OFFSET <= CLZ_OFFSET_32 when aaa_Config_port_full(1)='0' else
                  CLZ_OFFSET_16 when aaa_Config_port(0)='0' else
                  CLZ_OFFSET_8;
    
	-- todo: comfirmar que não há problemas em utilizar o zc no modo full precision
    offset: vector_adder generic map ( G_DATA_WIDTH => 32)  -- align with zero count
            port map (Config_port => aaa_Config_port, A => CLZ_OFFSET, B => inv_pad_zc, C_in => "1111", S => r_sf_offset, C_out => open);
    
    
    sf_add: vector_adder generic map ( G_DATA_WIDTH => G_DATA_WIDTH)                          
        port map (Config_port => aaa_Config_port, A => ss_quire_sf, B => r_sf_offset, C_in => "0000", S => r_sf, C_out => open);
    
    
    rst <= "0000" when aaa_full_precision = '0' or aaa_Config_port(1)='0' else
           "1100" when aaa_Config_port(0) = '0' else
           "1110";
           
    full_precision_rst: for i in 0 to 3 generate
        out_seq_rst: process(clk)
        begin
            if rising_edge(clk) then
                if rst(i) = '1' then
                    s_frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= (others => '0');
                    s_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= (others => '0');
                    s_sig(i) <= '0';
                    s_nar(i) <= '0';
                    s_sNaN(i) <= '0';
                    s_inf(i) <= '0';
                    s_zero(i) <= '1';
                    s_sticky(i) <= '0';
                else
                    s_frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= r_frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
                    s_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= r_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
                    s_sig(i) <= ss_sig(i);
                    s_nar(i) <= ss_quire_nar(i);
                    s_sNaN(i) <= ss_quire_sNaN(i);
                    s_inf(i) <= ss_quire_inf(i);
                    s_zero(i) <= ss_quire_zero(i);
                    s_sticky(i) <= r_sticky(i);
                end if;
            end if;
        end process;
    end generate;
      
    out_seq: process(clk)
    begin
        if rising_edge(clk) then
           s_es <= aaa_es;
           s_posit <= aaa_posit;
           s_float_posit <= aaa_float_posit;
           s_Config_port <= aaa_Config_port;
        end if;
    end process;
    
end Behavioral;
