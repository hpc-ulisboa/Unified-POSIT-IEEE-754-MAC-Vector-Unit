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

entity vector_fma is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32; --MUST BE 32
        constant G_MAX_ES_SIZE : positive := 3); --MUST BE 3
    Port (
        clk : in std_logic;
        rst : in std_logic;
        enable : in std_logic;
        Config_port : in std_logic_vector(1 downto 0);
        exp_size : in std_logic_vector(4*G_MAX_ES_SIZE-1 downto 0);
        acc_op : in std_logic;
        op : in std_logic_vector(1 downto 0); -- 00 and 01 ADD and SUB, 10 Multiply
        format : in std_logic_vector(3 downto 0); -- 1=> posit; 0=> IEEE; posit(0) => result; posit(1) => C; posit(2) => B; posit(3) => A
        full_precision : in std_logic;
        Va : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        Vb : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        Vc : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
        Vr : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        inexact : out std_logic_vector(3 downto 0);
        underflow : out std_logic_vector(3 downto 0);
        overflow : out std_logic_vector(3 downto 0);
        invalid : out std_logic_vector(3 downto 0);
        stall_o : out std_logic );
end vector_fma;

architecture Behavioral of vector_fma is
    
    signal stall : std_logic;
    
    -- Outputs (registered) of input register
    signal d_stall : std_logic;
    signal d_Config_port : std_logic_vector(1 downto 0);
    signal d_exp_size : std_logic_vector(4*G_MAX_ES_SIZE-1 downto 0);
    signal d_acc_op : std_logic;
    signal d_op : std_logic_vector(1 downto 0);
    signal d_format : std_logic_vector(3 downto 0);
    signal d_full_precision : std_logic;
    signal d_Va, d_Vb, d_Vc : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    
    -- shared decode signals
    signal float_posit: std_logic;
    signal rst_full, rst_frac : std_logic_vector(3 downto 0);
    
    -- Outputs (registered) of decode stages
    signal a_sf, b_sf, c_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal a_frac, b_frac, c_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal a_sig, b_sig, c_sig : std_logic_vector(3 downto 0);
    signal a_nar, b_nar, c_nar : std_logic_vector(3 downto 0);
    signal a_SNaN, b_SNaN, c_SNaN : std_logic_vector(3 downto 0);
    signal a_inf, b_inf, c_inf : std_logic_vector(3 downto 0);
    signal a_zero, b_zero, c_zero : std_logic_vector(3 downto 0);
   
   
    -- Outputs (registered) of multiply stage
    signal m_s_sig, m_s_nar, m_s_SNaN, m_s_zero, m_s_inf : std_logic_vector(3 downto 0);
    signal m_s_sf  : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal m_s_frac : std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
    signal m_c_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal m_c_sig : std_logic_vector(3 downto 0);
    signal m_c_nar, m_c_SNaN, m_c_zero, m_c_inf : std_logic_vector(3 downto 0);
    signal m_c_sf  : std_logic_vector(G_DATA_WIDTH-1 downto 0);         
    
    -- Outputs (registered) of add/accumulate stage
    signal a_s_sig : std_logic_vector(3 downto 0);
    signal a_s_sf  : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal a_s_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal a_s_nar, a_s_sNaN : std_logic_vector(3 downto 0);
    signal a_s_inf, a_s_zero : std_logic_vector(3 downto 0);
    signal a_s_sticky : std_logic_vector(3 downto 0);
    
    
    -- Signal propagation
    signal m_stall, a_stall, e_stall : std_logic;
    signal m_es, a_es, e_es : std_logic_vector(G_MAX_ES_SIZE-1 downto 0);
    signal m_format, a_format, e_format : std_logic;
    signal m_float_posit, a_float_posit, e_float_posit : std_logic;
    signal m_Config_port, a_Config_port, e_Config_port : std_logic_vector(1 downto 0);
    signal m_full_precision, a_full_precision : std_logic;
    signal m_acc_op, a_acc_op : std_logic;
    signal m_op, a_op : std_logic_vector (1 downto 0);
    
begin
    
    
    stall <= not enable;
------------------------------------------------------
-- Input Register
------------------------------------------------------
    input_reg: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                d_Config_port <= (others => '0');
                d_exp_size <= (others => '0');
                d_acc_op <= '0';
                d_op <= (others => '0');
                d_format <= (others => '0');
                d_full_precision <= '0';
                d_Va <= (others => '0');
                d_Vb <= (others => '0');
                d_Vc <= (others => '0');
            elsif stall = '0' then 
                d_Config_port <= Config_port;
                d_exp_size <= exp_size;
                d_acc_op <= acc_op;
                d_op <= op;
                d_format <= format;
                d_full_precision <= full_precision;
                d_Va <= Va;
                d_Vb <= Vb;
                d_Vc <= Vc;
            end if;
        end if;
    end process;
    
    input_reg_stall_process: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                d_stall <= '1';
            else
                d_stall <= stall;
            end if;
        end if;
    end process;
    

------------------------------------------------------
-- Decode Stages for Operands A,B,C
------------------------------------------------------

    -- mix exception handling
    float_posit <= not is_all_ones(d_format(3 downto 1));
        
    rst_full <= "1111" when rst = '1' else
                "0000" when d_full_precision = '0' or d_Config_port(1)='0' else
                "1100" when d_Config_port(0) = '0' else
                "1110";
    
    rst_frac <= "1111" when rst = '1' else
                "0000" when d_full_precision = '0' or d_Config_port(1)='0' else
                "0011" when d_Config_port(0) = '0' else
                "0111";
    
    
    decode_A: vector_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE)
        port map(
            clk => clk,
            rst => rst,
            stall => d_stall,
            Config_port => d_Config_port,
            es => d_exp_size(4*G_MAX_ES_SIZE-1 downto 3*G_MAX_ES_SIZE),
            V => d_Va,
            format => d_format(3),
            rst_full => rst_full,
            rst_frac => rst_frac,
            full_precision => d_full_precision,
            sig => a_sig,
            sf => a_sf,
            frac => a_frac,
            nar => a_nar,
			sNaN => a_sNaN,
			inf => a_inf,
            zero => a_zero
        );
    
    decode_B: vector_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE)
        port map(
            clk => clk,
            rst => rst,
            stall => d_stall,
            Config_port => d_Config_port,
            es => d_exp_size(3*G_MAX_ES_SIZE-1 downto 2*G_MAX_ES_SIZE),
            V => d_Vb,
            format => d_format(2),
            full_precision => d_full_precision,
            rst_full => rst_full,
            rst_frac => rst_frac,
            sig => b_sig,
            sf => b_sf,
            frac => b_frac,
            nar => b_nar,
      		sNaN => b_sNaN,
      		inf => b_inf,
            zero => b_zero
        );
    
    decode_C: vector_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE)
        port map(
            clk => clk,
            rst => rst,
            stall => d_stall,
            Config_port => d_Config_port,
            es => d_exp_size(2*G_MAX_ES_SIZE-1 downto G_MAX_ES_SIZE),
            V => d_Vc,
            format => d_format(1),
            full_precision => d_full_precision,
            rst_full => rst_full,
            rst_frac => rst_frac,
            sig => c_sig,
            sf => c_sf,
            frac => c_frac,
            nar => c_nar,
            sNaN => c_sNaN,
			inf => c_inf,
            zero => c_zero
        );
         
------------------------------------------------------
-- Decode Signal Propagation (es, format, float_posit, Config_port, full_precision, acc, op)
------------------------------------------------------

    decode_progagate: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                m_es <= (others => '0');
                m_format <= '0';
                m_float_posit <= '0';
                m_Config_port <= (others => '0');
                m_full_precision <= '0';
                m_acc_op <= '0';
                m_op <= (others => '0');
            elsif d_stall = '0' then
                m_es <= d_exp_size(G_MAX_ES_SIZE-1 downto 0);
                m_format <= d_format(0);
                m_float_posit <= float_posit;
                m_Config_port <= d_Config_port;
                m_full_precision <= d_full_precision;
                m_acc_op <= d_acc_op;
                m_op <= d_op;
            end if;
        end if;
    end process;
    
    decode_stall_seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                m_stall <= '1';
            else
                m_stall <= d_stall;
            end if;
        end if;
    end process;
     
------------------------------------------------------
-- Multiply Stage => S = A * B
------------------------------------------------------

    multiply : vector_mult
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
        port map(
            clk => clk,
            rst => rst,
            stall => m_stall,
            Config_port => m_Config_port,
            full_precision => m_full_precision,
            a_sig => a_sig,
            a_sf => a_sf,
            a_frac => a_frac,
            a_zero => a_zero,
            a_nar => a_nar,
            a_SNaN => a_SNaN,
            a_inf => a_inf,
            
            b_sig => b_sig,
            b_sf => b_sf,
            b_frac => b_frac,
            b_zero => b_zero,
            b_nar => b_nar,
            b_SNaN => b_SNaN,
            b_inf => b_inf,
            
            s_sig => m_s_sig,
            s_sf => m_s_sf,
            s_frac => m_s_frac,
            s_zero => m_s_zero,
            s_nar => m_s_nar,
            s_SNaN => m_s_SNaN,
            s_inf => m_s_inf
        );
         
    mult_seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                m_c_sig <= (others => '0');
                m_c_frac <= (others => '0');
                m_c_sf <= (others => '0');
                m_c_nar <= (others => '0');
                m_c_SNaN <= (others => '0');
                m_c_zero <= (others => '0');
                m_c_inf <= (others => '0');
            elsif m_stall = '0' then
                m_c_sig <= c_sig;
                m_c_frac <= c_frac;
                m_c_sf <= c_sf;
                m_c_nar <= c_nar;
                m_c_SNaN <= c_SNaN;
                m_c_zero <= c_zero;
                m_c_inf <= c_inf;
            end if;
        end if;
    end process;
    
------------------------------------------------------
-- Multiply Signal Propagation (es, format, float_posit, Config_port, full_precision, acc, op)
------------------------------------------------------

    mult_progagate: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                a_es <= (others => '0');
                a_format <= '0';
                a_float_posit <= '0';
                a_Config_port <= (others => '0');
                a_full_precision <= '0';
                a_acc_op <= '0';
                a_op <= (others => '0');
            elsif m_stall = '0' then
                a_es <= m_es;
                a_format <= m_format;
                a_float_posit <= m_float_posit;
                a_Config_port <= m_Config_port;        
                a_full_precision <= m_full_precision;
                a_acc_op <= m_acc_op;
                a_op <= m_op;
            end if;
        end if;
    end process;
    
    mult_stall_seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                a_stall <= '1';
            else
                a_stall <= m_stall;
            end if;
        end if;
    end process;
 
------------------------------------------------------
-- Add Stage => S = M + C
------------------------------------------------------

    add : vector_quire_add
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE)
        port map(
            clk => clk,
            rst => rst,
            stall => a_stall,
            acc => a_acc_op,
            op => a_op,
            es => a_es,
            format => a_format,
            float_posit => a_float_posit,
            Config_port => a_Config_port,
            full_precision => a_full_precision,

            m_sig => m_s_sig,
            m_sf => m_s_sf,
            m_frac => m_s_frac,
            m_nar => m_s_nar,
            m_sNaN => m_s_SNaN,
            m_zero => m_s_zero,
            m_inf => m_s_inf,
            
            c_sig => m_c_sig,
            c_sf => m_c_sf,
            c_frac => m_c_frac,
            c_nar => m_c_nar,
            c_sNaN => m_c_SNaN,
            c_zero => m_c_zero,
            c_inf => m_c_inf,
            
            s_stall => e_stall,
            s_es => e_es,
            s_format => e_format,
            s_float_posit => e_float_posit,
            s_Config_port => e_Config_port,
            s_sig => a_s_sig,
            s_sf => a_s_sf,
            s_frac => a_s_frac,
            s_nar => a_s_nar,
            s_sNaN => a_s_sNaN,
            s_inf => a_s_inf,
            s_zero => a_s_zero,
            s_sticky => a_s_sticky
        );   


------------------------------------------------------
-- Encode stage
------------------------------------------------------

    encode : vector_encode
    generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE)
    port map(
        clk => clk,
        rst => rst,
        stall => e_stall,
        es => e_es,
        Config_port => e_Config_port,
        format => e_format,
        float_posit => e_float_posit,
        nar => a_s_nar,
        sNaN => a_s_sNaN,
        zero => a_s_zero,
        inf => a_s_inf,
        sig => a_s_sig,
        sf => a_s_sf,
        frac => a_s_frac,
        sticky => a_s_sticky,
        inexact => inexact,
        underflow => underflow,
        overflow => overflow,
        invalid => invalid,
        Vr => Vr,
        stall_o => stall_o
    );
    
end Behavioral;
