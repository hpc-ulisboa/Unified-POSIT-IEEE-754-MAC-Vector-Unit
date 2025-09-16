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

package vector_Pkg is

----------------------------------------------------------------------------------------------
-- STANDARD FUNCTIONS IN vector_Pkg
----------------------------------------------------------------------------------------------    

    function EXP_width(fp_size : integer) return integer;
    function log2(A: integer) return integer;
    function ceil_log2(Arg: integer) return integer;
    function is_all_ones(d : std_logic_vector) return std_logic;
    function is_zero(d : std_logic_vector) return std_logic;
--    function is_not_zero(d : std_logic_vector) return std_logic;
--    function notx(d : std_logic_vector) return boolean;
    
    
------------------------------------------------------------------------------------------------
-- STANDARD COMPONENTS IN vector_Pkg
----------------------------------------------------------------------------------------------
    
    component vector_zero_sign_detect is
        Port ( --clk : in std_logic;
            config_port : in std_logic_vector(1 downto 0);
            v_a : in std_logic_vector (31 downto 0);
            v_z : out std_logic_vector (3 downto 0);
            v_s : out std_logic_vector (3 downto 0)
        );
    end component;
    
    component vector_zero_sign_detect_p is
        Generic ( 
                constant G_DATA_WIDTH : positive := 32);
        Port ( --clk : in std_logic;
            config_port : in std_logic_vector(1 downto 0);
            v_a : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
            v_z : out std_logic_vector (3 downto 0);
            v_s : out std_logic_vector (3 downto 0)
        );
    end component;
    
    component vector_zero_detect is
    Generic ( 
            constant G_DATA_WIDTH : positive := 32);
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);  -- 00 & 01 - 32bits; 10 - 16bits; 11 - 8bits
        v_a : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
        v_z : out std_logic_vector (3 downto 0)
    );
    end component;
    
    component vector_frac_zero_detect is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);  -- 00 & 01 - 32bits; 10 - 16bits; 11 - 8bits
        v_a : in std_logic_vector (31 downto 0);
        v_z : out std_logic_vector (3 downto 0)
    );
    end component;
    
    component vector_all_ones_detect is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        v_a : in std_logic_vector (15 downto 0);
        v_f : out std_logic_vector (3 downto 0)
    );
    end component;
    
    component vector_float_ovf is
    Port (
        config_port : in std_logic_vector(1 downto 0);
        sf : in std_logic_vector(31 downto 0);
        pre_float : in std_logic_vector (31 downto 0);
        denormal : in std_logic_vector (3 downto 0);
        zero : in std_logic_vector(3 downto 0);
        ovf : out std_logic_vector (3 downto 0)
    );
    end component;
    
    component vector_adder is
        Generic ( 
            constant G_DATA_WIDTH : positive := 32);
        
        Port (
            Config_port : in std_logic_vector(1 downto 0); 
            A : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
            B : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
            C_in : in std_logic_vector(3 downto 0);
      
            S : out std_logic_vector(G_DATA_WIDTH-1 downto 0); 
            C_out : out std_logic_vector(3 downto 0));
    end component;
    
    component vector_lzc32 is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector (1 downto 0);
        a : in std_logic_vector (31 downto 0);
        c : out std_logic_vector (15 downto 0);
        v : out std_logic_vector(3 downto 0)
    );
    end component;
    
    component vector_lzc128 is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector (1 downto 0);
        a : in std_logic_vector (127 downto 0);
        c : out std_logic_vector (23 downto 0);
        v : out std_logic_vector(3 downto 0)
    );
    end component;

    component clz is
        Generic ( 
            constant G_DATA_WIDTH : positive := 32;
            constant G_COUNT_WIDTH : positive := 5 
        );
        Port ( --clk : in std_logic;
            A : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
            C : out std_logic_vector (G_COUNT_WIDTH-1 downto 0);
            V : out std_logic
        );
    end component;
    
    component vector_barrel_sl is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (31 downto 0);
        shamtv : in std_logic_vector (15 downto 0);
        s : out std_logic_vector (31 downto 0)
    );
    end component;
    
    component vector_barrel_sl_es is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (31 downto 0);
        shamt : in std_logic_vector (2 downto 0);
        s : out std_logic_vector (31 downto 0)
    );
    end component;
    
    component vector_barrel_sl_es_cpy is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (31 downto 0);
        shamt : in std_logic_vector (2 downto 0);
        s : out std_logic_vector (31 downto 0);
        cpy : out std_logic_vector (19 downto 0)
    );
    end component;
    
    component vector_barrel_sl_p is
        Generic ( 
                constant G_DATA_WIDTH : positive := 32);
        Port ( --clk : in std_logic;
            config_port : in std_logic_vector(1 downto 0);
            a : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
            shamtv : in std_logic_vector (4*(log2(G_DATA_WIDTH/4)+1)-1 downto 0);
            s : out std_logic_vector (G_DATA_WIDTH-1 downto 0)
        );
    end component;
    
    component vector_barrel_sr_round is
        Port ( --clk : in std_logic;
            config_port : in std_logic_vector(1 downto 0);
            a : in std_logic_vector (127 downto 0);
            shamtv : in std_logic_vector (23 downto 0);
            sign: in std_logic_vector (3 downto 0);
            s : out std_logic_vector (127 downto 0);
            sticky : out std_logic_vector(3 downto 0)
        );
    end component;
    
    component vector_barrel_sl_round is
        Port ( --clk : in std_logic;
            config_port : in std_logic_vector(1 downto 0);
            a : in std_logic_vector (127 downto 0);
            shamtv : in std_logic_vector (23 downto 0);
            s : out std_logic_vector (31 downto 0);
            sticky : out std_logic_vector(3 downto 0)
        );
    end component;
    
    
    component vector_barrel_sr_ef is
        Port ( --clk : in std_logic;
            config_port : in std_logic_vector(1 downto 0);
            a : in std_logic_vector (63 downto 0);
            shamt : in std_logic_vector (2 downto 0);
            sign: in std_logic_vector (3 downto 0);
            s : out std_logic_vector (63 downto 0);
            sticky : out std_logic_vector(3 downto 0)
        );
    end component;
    
    component vector_barrel_sr_regime is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (39 downto 0);
        shamtv : in std_logic_vector (11 downto 0);
        sign: in std_logic_vector (3 downto 0);
        s : out std_logic_vector (31 downto 0);
        lsb : out std_logic_vector (3 downto 0);
        guard : out std_logic_vector (3 downto 0);
        round : out std_logic_vector (3 downto 0);
        sticky : out std_logic_vector(3 downto 0)
    );
    end component;
        
    component vector_barrel_sr_den is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (31 downto 0);
        shamtv : in std_logic_vector (11 downto 0);
        zero : in std_logic_vector(3 downto 0);
        s : out std_logic_vector (31 downto 0);
        sticky : out std_logic_vector(3 downto 0)
    );
    end component;
    
    component radix4_booth_enc8 is
    Port ( 
        a : in std_logic_vector(7 downto 0);
        rec : in std_logic_vector(2 downto 0);
        pp : out std_logic_vector(8 downto 0); 
        s : out std_logic);
    end component;
    
    component radix4_mult8_cs is
      Port ( 
        a : in std_logic_vector(7 downto 0);
        b : in std_logic_vector(7 downto 0);
        en : in std_logic;
        s : out std_logic_vector(15 downto 0); 
        c : out std_logic_vector(15 downto 0));
    end component;
    
    component vector_mult_cs is
    Port ( 
        config_port : in std_logic_vector(1 downto 0); 
        a : in std_logic_vector(31 downto 0);
        b : in std_logic_vector(31 downto 0);
        
        s : out std_logic_vector(63 downto 0);
        c : out std_logic_vector(63 downto 0));
    end component;  
    
    component vector_frac_overflow is
    Port ( --clk : in std_logic;
        a : in std_logic_vector (63 downto 0);
        ovf : in std_logic_vector (3 downto 0);
        s : out std_logic_vector (63 downto 0)
    );
    end component;
    
    component vector_quire_adjust is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (127 downto 0);
        s : out std_logic_vector (127 downto 0);
        sf_inc : out std_logic_vector (3 downto 0)
    );
    end component;
    
    component vector_decode is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3);
    Port (
        clk : in std_logic;
        rst : in std_logic;
        stall : in std_logic;
        Config_port : in std_logic_vector(1 downto 0);
        es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
        V : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        format : in std_logic;   -- 1=> posit; 0=> IEEE
        full_precision : in std_logic; 
        rst_full : in std_logic_vector(3 downto 0);
        rst_frac : in std_logic_vector(3 downto 0);
        sig : out std_logic_vector(3 downto 0);
        sf : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        frac : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        nar : out std_logic_vector(3 downto 0);
        sNaN : out std_logic_vector(3 downto 0);
        inf : out std_logic_vector(3 downto 0);
        zero : out std_logic_vector(3 downto 0) );
    end component;

    component vector_posit_decode is
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
    end component;
    
    component vector_float_decode is
        Generic ( 
            constant G_DATA_WIDTH : positive := 32);
        Port (
            Config_port : in std_logic_vector(1 downto 0);
            fp : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
            sig : out std_logic_vector(3 downto 0);
            sf : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
            frac : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
            sNaN : out std_logic_vector(3 downto 0);       --if significand MSB is 0
            qNaN : out std_logic_vector(3 downto 0);       --if significand MSB is 1
            inf : out std_logic_vector(3 downto 0);
            zero : out std_logic_vector(3 downto 0) );
    end component;
    
    
    component vector_mult is
        Generic ( 
            constant G_DATA_WIDTH : positive := 32);
        Port ( 
            clk : in std_logic;
            rst : in std_logic;
            stall : in std_logic;
            Config_port : in std_logic_vector(1 downto 0);
            full_precision: in std_logic;
            a_sig : in std_logic_vector(3 downto 0);
            a_sf : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
            a_frac : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
            a_zero : in std_logic_vector(3 downto 0);
            a_nar : in std_logic_vector(3 downto 0);
            a_SNaN : in std_logic_vector(3 downto 0);
            a_inf : in std_logic_vector(3 downto 0);
            
            b_sig : in std_logic_vector(3 downto 0);
            b_sf: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
            b_frac : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
            b_zero : in std_logic_vector(3 downto 0);
            b_nar : in std_logic_vector(3 downto 0);
            b_SNaN : in std_logic_vector(3 downto 0);
            b_inf : in std_logic_vector(3 downto 0);
            
            s_sig : out std_logic_vector(3 downto 0);
            s_sf  : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
            s_frac : out std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
            s_zero : out std_logic_vector(3 downto 0);
            s_nar : out std_logic_vector(3 downto 0);
            s_SNaN : out std_logic_vector(3 downto 0);
            s_inf : out std_logic_vector(3 downto 0)
            
         );
    end component;

    component vector_quire_add is
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
    end component;
    
    component vector_quire_conversion is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3;
        constant C_QS : positive := 128);
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
        
        a_stall : out std_logic;
        a_es : out std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
        a_format : out std_logic;
        a_float_posit : out std_logic;
        a_Config_port : out std_logic_vector (1 downto 0);
        a_Config_port_full : out std_logic_vector (1 downto 0);
        a_full_precision : out std_logic;
        r_m_quire : out std_logic_vector(C_QS-1 downto 0);
        r_c_quire : out std_logic_vector(C_QS-1 downto 0);
        r_m_sf_fixed : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        r_c_sf_fixed : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        r_m_op_sig : out std_logic_vector(3 downto 0);
        r_c_op_sig : out std_logic_vector(3 downto 0);
        r_m_r_sig : out std_logic_vector(3 downto 0);
        r_c_r_sig : out std_logic_vector(3 downto 0);
        r_mult : out std_logic;
        r_acc : out std_logic;
        r_m_nar : out std_logic_vector(3 downto 0);
        r_m_zero : out std_logic_vector(3 downto 0);
        r_m_sNan : out std_logic_vector(3 downto 0);
        r_m_inf : out std_logic_vector(3 downto 0);
        r_c_nar : out std_logic_vector(3 downto 0);
        r_c_zero : out std_logic_vector(3 downto 0);
        r_c_sNaN : out std_logic_vector(3 downto 0);
        r_c_inf: out std_logic_vector(3 downto 0)
     );
    end component;
    
    component vector_quire_op is
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
    end component;
    
    component vector_quire_normalization is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3;
        constant C_QS : positive := 128);
    Port ( 
           clk : in std_logic;
           rst : in std_logic;
           aa_stall : in std_logic;
           aa_es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
           aa_format : in std_logic;
           aa_float_posit : in std_logic;
           aa_Config_port : in std_logic_vector (1 downto 0);
           aa_Config_port_full : in std_logic_vector (1 downto 0);
           aa_full_precision : in std_logic;
           aa_sticky: in std_logic_vector(3 downto 0);
           r_quire: in std_logic_vector(C_QS-1 downto 0);
           r_sub_min_loss: in std_logic_vector(3 downto 0);
           r_quire_sf: in std_logic_vector(G_DATA_WIDTH-1 downto 0);
           r_quire_nar_tmp: in std_logic_vector(3 downto 0);
           r_quire_sNaN: in std_logic_vector(3 downto 0);
           r_quire_inf: in std_logic_vector(3 downto 0);
           r_quire_zero: in std_logic_vector(3 downto 0);
           r_expt_sig : in std_logic_vector(3 downto 0);
           r_overflow : in std_logic_vector(3 downto 0);
           
           quire_zero : out std_logic_vector(3 downto 0);
           r_quire_nar : out std_logic_vector(3 downto 0);
           r_sig : out std_logic_vector(3 downto 0);
           
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
    end component;
    
    component vector_encode is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3);
    Port (
          clk : in std_logic;
          rst : in std_logic;
          stall : in std_logic;
          es : in std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
          Config_port : in std_logic_vector(1 downto 0);
          format : in std_logic;
          float_posit: in std_logic;
          nar : in std_logic_vector(3 downto 0);
          sNaN : in std_logic_vector(3 downto 0);
          zero : in std_logic_vector(3 downto 0);
          inf : in std_logic_vector(3 downto 0);
          sig : in std_logic_vector(3 downto 0);
          sf : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
          frac : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
          sticky : in std_logic_vector(3 downto 0);
          s_pos : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
          inexact : out std_logic_vector(3 downto 0);
          underflow : out std_logic_vector(3 downto 0);
          overflow : out std_logic_vector(3 downto 0);
          invalid : out std_logic_vector(3 downto 0);
          Vr : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
          stall_o : out std_logic );
    end component;
    
    component vector_posit_encode is
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
    end component;

    
    component vector_float_encode is
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
    end component;
    
    
end vector_Pkg;

package body vector_Pkg is
    
    function EXP_width(fp_size : integer) return integer
    is begin
        if fp_size = 32 then
            return 8;
        elsif fp_size = 16 then
            return 5;
        elsif fp_size = 8 then
            return 4;
        end if;
    end function;
    
    function log2(A: integer) return integer is
    begin
        for I in 1 to 30 loop  -- Works for up to 32 bit integers
            if(2**I > A) then return(I-1);  end if;
        end loop;
        return(30);
    end function;
    
    function ceil_log2(Arg: integer) return integer is
        variable RetVal: integer;
    begin
        RetVal := log2(Arg);
        if (Arg > (2**RetVal)) then
            return(RetVal + 1);
        else
            return(RetVal); 
        end if;
    end function; 
    
-- Check for all ones in the vector
    function is_all_ones(d : std_logic_vector) return std_logic is
        variable z : std_logic_vector(d'range);
    begin
        z := (others => '1');
        if d = z then return '1';
        else return '0';
        end if;
    end;
        
    function is_zero(d : std_logic_vector) return std_logic is
        variable z : std_logic_vector(d'range);
    begin
        z := (others => '0');
        if d = z then return '1';
        else return '0';
        end if;
    end;
    
end vector_Pkg;
