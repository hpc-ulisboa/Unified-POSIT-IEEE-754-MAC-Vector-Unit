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

use work.vector_Pkg.all;

entity vector_quire_add is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3);
    Port ( 
        clk : in std_logic;
        rst : in std_logic;
        stall : in std_logic;
        acc : in std_logic;
        op : in std_logic_vector(1 downto 0);
        es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
        format : in std_logic;
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
        
        s_stall : out std_logic;
        s_es : out std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
        s_format : out std_logic;
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
end vector_quire_add;

architecture Behavioral of vector_quire_add is
    
    constant C_CG : integer := 7;
    constant C_NQ : integer := 60;
    constant C_QS : integer := 2*C_NQ+C_CG+1;
    
    -- signals propagation
    signal a_stall, aa_stall : std_logic;
    signal a_es, aa_es : std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
    signal a_format, aa_format : std_logic;
    signal a_float_posit, aa_float_posit : std_logic;
    signal a_Config_port, aa_Config_port : std_logic_vector (1 downto 0);
    signal a_Config_port_full, aa_Config_port_full : std_logic_vector (1 downto 0);
    signal a_full_precision, aa_full_precision : std_logic;
    
    -- Outputs (registered) of "fixed point" conversion
    signal r_c_quire, r_m_quire: std_logic_vector(C_QS-1 downto 0);
    signal r_m_sf_fixed, r_c_sf_fixed: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_m_op_sig, r_c_op_sig: std_logic_vector(3 downto 0);
    signal r_m_r_sig, r_c_r_sig: std_logic_vector(3 downto 0);
    signal r_mult, r_acc : std_logic;
    signal r_m_nar, r_m_zero, r_m_inf, r_m_sNan : std_logic_vector(3 downto 0);
    signal r_c_nar, r_c_zero, r_c_inf, r_c_sNaN : std_logic_vector(3 downto 0);

    -- Outputs (registered) of Quire Accumulation / Addition
    signal aa_sticky : std_logic_vector(3 downto 0);
    signal r_sub_min_loss : std_logic_vector(3 downto 0);
    signal r_quire : std_logic_vector(C_QS-1 downto 0);
    signal r_quire_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_quire_nar_tmp, r_quire_sNaN : std_logic_vector(3 downto 0);
    signal r_quire_inf : std_logic_vector(3 downto 0);
    signal r_quire_zero, r_expt_sig : std_logic_vector(3 downto 0);
    signal r_overflow: std_logic_vector(3 downto 0);
    
    
    -- Normalization signals for acc
    signal quire_zero : std_logic_vector(3 downto 0);
    signal r_quire_nar: std_logic_vector(3 downto 0); 
    signal r_sig : std_logic_vector(3 downto 0);


begin

    v_quire_conversion: vector_quire_conversion generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE, C_QS => C_QS)
        port map (
            clk => clk,
            rst => rst,
            stall => stall,
            acc => acc,
            op => op,
            es => es,
            format => format,
            float_posit => float_posit,
            Config_port => Config_port,
            full_precision => full_precision,
            
            m_sig => m_sig,
            m_sf => m_sf,
            m_frac => m_frac,
            m_nar => m_nar,
            m_sNaN => m_sNaN,
            m_zero => m_zero,
            m_inf => m_inf,
            
            c_sig => c_sig,
            c_sf => c_sf,
            c_frac => c_frac,
            c_nar => c_nar,
            c_sNaN => c_sNaN,
            c_zero => c_zero,
            c_inf => c_inf,
            
            a_stall => a_stall,
            a_es => a_es,
            a_format => a_format,
            a_float_posit => a_float_posit,
            a_Config_port => a_Config_port,
            a_Config_port_full => a_Config_port_full,
            a_full_precision => a_full_precision,
            r_m_quire => r_m_quire,
            r_c_quire => r_c_quire,
            r_m_sf_fixed => r_m_sf_fixed,
            r_c_sf_fixed => r_c_sf_fixed,
            r_m_op_sig => r_m_op_sig,
            r_c_op_sig => r_c_op_sig,
            r_m_r_sig => r_m_r_sig,
            r_c_r_sig => r_c_r_sig,
            r_mult => r_mult,
            r_acc => r_acc,
            r_m_nar => r_m_nar,
            r_m_zero => r_m_zero,
            r_m_sNan => r_m_sNan,
            r_m_inf => r_m_inf,
            r_c_nar => r_c_nar,
            r_c_zero => r_c_zero,
            r_c_sNaN => r_c_sNaN,
            r_c_inf => r_c_inf
        );
    
    
    v_quire_op: vector_quire_op generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE, C_QS => C_QS)    
        port map (
            clk => clk,
            rst => rst,
            a_stall => a_stall,
            a_es => a_es,
            a_format => a_format,
            a_float_posit => a_float_posit,
            a_Config_port => a_Config_port,
            a_Config_port_full => a_Config_port_full,
            a_full_precision => a_full_precision,
            r_m_quire => r_m_quire,
            r_c_quire => r_c_quire,
            r_m_sf_fixed => r_m_sf_fixed,
            r_c_sf_fixed => r_c_sf_fixed,
            r_m_op_sig => r_m_op_sig,
            r_c_op_sig => r_c_op_sig,
            r_m_r_sig => r_m_r_sig,
            r_c_r_sig => r_c_r_sig,
            r_mult => r_mult,
            r_acc => r_acc,
            r_m_nar => r_m_nar,
            r_m_zero => r_m_zero,
            r_m_sNan => r_m_sNan,
            r_m_inf => r_m_inf,
            r_c_nar => r_c_nar,
            r_c_zero => r_c_zero,
            r_c_sNaN => r_c_sNaN,
            r_c_inf => r_c_inf,
            
            quire_zero => quire_zero,
            r_quire_nar => r_quire_nar,
            r_sig => r_sig,
            
            aa_stall => aa_stall,
            aa_es => aa_es,
            aa_format => aa_format,
            aa_float_posit => aa_float_posit,
            aa_Config_port => aa_Config_port,
            aa_Config_port_full => aa_Config_port_full,
            aa_full_precision => aa_full_precision,
            aa_sticky => aa_sticky,
            r_quire => r_quire,
            r_sub_min_loss => r_sub_min_loss,
            r_quire_sf => r_quire_sf,
            r_quire_nar_tmp => r_quire_nar_tmp,
            r_quire_sNaN => r_quire_sNaN,
            r_quire_inf => r_quire_inf,
            r_quire_zero => r_quire_zero,
            r_expt_sig => r_expt_sig,
            r_overflow => r_overflow
        );    

    v_quire_normalization: vector_quire_normalization generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE, C_QS => C_QS)
        port map (
            clk => clk,
            rst => rst,
            aa_stall => aa_stall,
            aa_es => aa_es,
            aa_format => aa_format,
            aa_float_posit => aa_float_posit,
            aa_Config_port => aa_Config_port,
            aa_Config_port_full => aa_Config_port_full,
            aa_full_precision => aa_full_precision,
            aa_sticky => aa_sticky,
            r_quire => r_quire,
            r_sub_min_loss => r_sub_min_loss,
            r_quire_sf => r_quire_sf,
            r_quire_nar_tmp => r_quire_nar_tmp,
            r_quire_sNaN => r_quire_sNaN,
            r_quire_inf => r_quire_inf,
            r_quire_zero => r_quire_zero,
            r_expt_sig => r_expt_sig,
            r_overflow => r_overflow,
                 
            quire_zero => quire_zero,
            r_quire_nar => r_quire_nar,
            r_sig => r_sig,
            
            s_stall => s_stall,
            s_es => s_es,
            s_format => s_format,
            s_float_posit => s_float_posit,
            s_Config_port => s_Config_port,
            s_sig => s_sig,
            s_sf => s_sf,
            s_frac => s_frac,
            s_nar => s_nar,
            s_sNaN => s_sNaN,
            s_inf => s_inf,
            s_zero => s_zero,
            s_sticky => s_sticky
        );    
    
    
end Behavioral;
