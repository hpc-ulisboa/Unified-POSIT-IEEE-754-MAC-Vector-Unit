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

entity vector_quire_conversion is
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
end vector_quire_conversion;

architecture Behavioral of vector_quire_conversion is
    
    constant C_CG : integer := 7;
    constant C_NQ_8 : integer := 12;
    constant C_NQ_16 : integer := 28;
    constant C_NQ : integer := 60;
    
    constant Q_sa_size: positive := log2(C_QS/4);
    
    signal sf_full_ctrl: std_logic_vector (3 downto 0);
    signal Config_port_full: std_logic_vector (1 downto 0); 
    
    -- m "fixed point" conversion
    signal m_r_sig, m_op_sig : std_logic_vector(3 downto 0);
    signal ext_mf, mf_inv, mf_cmp : std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
    signal m_quire : std_logic_vector(C_QS-1 downto 0); 
    
    -- c "fixed point" conversion
    signal c_r_sig, c_op_sig : std_logic_vector(3 downto 0);
    signal ext_cf, mc_inv, mc_cmp : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal c_quire : std_logic_vector(C_QS-1 downto 0);
    
begin

    sf_full_ctrl <= "1111" when full_precision = '0' or Config_port(1)='0' else
                    "0011" when Config_port(0) = '0' else
                    "0001";
                    
    Config_port_full <= '0' & Config_port(0) when full_precision = '1' else
                        Config_port;
    
    ---- Convert fractions to quire(fixed-point) 2's complement ----
    --- m ---
    m_op_sig <= m_sig xor ((3 downto 0 => op(0)) and (3 downto 0 => acc)); 
    m_r_sig <= m_op_sig and not m_zero;
    
    -- 2's complement 
    ext_mf <= (15 downto 0 => m_r_sig(3)) & (15 downto 0 => m_r_sig(2)) & (15 downto 0 => m_r_sig(1)) & (15 downto 0 => m_r_sig(0));
    
    mf_inv <= m_frac xor ext_mf;
    
    comp_m_frac: vector_adder generic map (G_DATA_WIDTH => 64)
                 port map (Config_port => Config_port_full, A => mf_inv, B => (63 downto 0 => '0'), C_in => m_r_sig, S => mf_cmp, C_out => open);
    
    -- sign extend
    m_quire <= (C_CG-5 downto 0 => m_r_sig(3)) & mf_cmp & (C_NQ downto 0 => '0') when Config_port_full(1)='0' else   -- 1+7+60+60
               (C_CG-5 downto 0 => m_r_sig(3)) & mf_cmp(2*G_DATA_WIDTH-1 downto G_DATA_WIDTH) & (C_NQ_16 downto 0 => '0') & (C_CG-5 downto 0 => m_r_sig(1)) & mf_cmp(G_DATA_WIDTH-1 downto 0) & (C_NQ_16 downto 0 => '0') when Config_port(0)='0' else -- 1+7+28+28|1+7+28+28
               (C_CG-5 downto 0 => m_r_sig(3)) & mf_cmp(2*G_DATA_WIDTH-1 downto 2*G_DATA_WIDTH*3/4) & (C_NQ_8 downto 0 => '0') & (C_CG-5 downto 0 => m_r_sig(2)) & mf_cmp(2*G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH) & (C_NQ_8 downto 0 => '0') &-- 1+7+12+12|1+7+12+12|1+7+12+12|1+7+12+12
               (C_CG-5 downto 0 => m_r_sig(1)) & mf_cmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) & (C_NQ_8 downto 0 => '0') & (C_CG-5 downto 0 => m_r_sig(0)) & mf_cmp(G_DATA_WIDTH/2-1 downto 0) & (C_NQ_8 downto 0 => '0');  
               
    
    --- c ---
    c_op_sig <= c_sig xor (3 downto 0 => op(0));
    c_r_sig <= c_op_sig and not c_zero;
    
    -- 2's complement 
    ext_cf <= (7 downto 0 => c_r_sig(3)) & (7 downto 0 => c_r_sig(2)) & (7 downto 0 => c_r_sig(1)) & (7 downto 0 => c_r_sig(0));
    
    mc_inv <= c_frac xor ext_cf;
    
    comp_c_frac: vector_adder generic map ( G_DATA_WIDTH => 32)
                 port map (Config_port => Config_port_full, A => mc_inv, B => (31 downto 0 => '0'), C_in => c_r_sig, S => mc_cmp, C_out => open);
   
    -- sign extend
    c_quire <= (C_CG-3 downto 0 => c_r_sig(3)) & mc_cmp & (C_NQ+G_DATA_WIDTH-2 downto 0 => '0') when Config_port_full(1)='0' else     -- 1+7+60+60
               (C_CG-3 downto 0 => c_r_sig(3)) & mc_cmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) & (C_NQ_16+G_DATA_WIDTH/2-2 downto 0 => '0') & (C_CG-3 downto 0 => c_r_sig(1)) & mc_cmp(G_DATA_WIDTH/2-1 downto 0) & (C_NQ_16+G_DATA_WIDTH/2-2 downto 0 => '0') when Config_port(0)='0' else -- 1+7+28+28|1+7+28+28
               (C_CG-3 downto 0 => c_r_sig(3)) & mc_cmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) & (C_NQ_8+G_DATA_WIDTH/4-2 downto 0 => '0') & (C_CG-3 downto 0 => c_r_sig(2)) & mc_cmp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) & (C_NQ_8+G_DATA_WIDTH/4-2 downto 0 => '0')       -- 1+7+12+12|1+7+12+12|1+7+12+12|1+7+12+12
               & (C_CG-3 downto 0 => c_r_sig(1)) & mc_cmp(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) & (C_NQ_8+G_DATA_WIDTH/4-2 downto 0 => '0') & (C_CG-3 downto 0 => c_r_sig(0)) & mc_cmp(G_DATA_WIDTH/4-1 downto 0) & (C_NQ_8+G_DATA_WIDTH/4-2 downto 0 => '0');  
                                  
                     
--    split_add: process(clk)
--    begin
--       if rising_edge(clk) then
--            if rst = '1' then 
--                a_es <= (others => '0');
--                a_format <= '0';
--                a_float_posit <= '0';
--                a_Config_port <= (others => '0');
--                a_Config_port_full <= (others => '0');
--                a_full_precision <= '0';
--                r_m_quire <= (others => '0');
--                r_c_quire <= (others => '0');
--                r_m_sf_fixed <= (others => '0');
--                r_c_sf_fixed <= (others => '0');
--                r_m_op_sig <= (others => '0');
--                r_c_op_sig <= (others => '0');
--                r_m_r_sig <= (others => '0');
--                r_c_r_sig <= (others => '0');
--                r_mult <= '0';
--                r_acc <= '0';
--                r_m_nar <= (others => '0');
--                r_m_zero <= (others => '0'); 
--                r_m_sNan <= (others => '0');
--                r_m_inf <= (others => '0');
--                r_c_nar <= (others => '0');
--                r_c_zero <= (others => '0');
--                r_c_sNaN <= (others => '0');
--                r_c_inf <= (others => '0');
--            elsif stall = '0' then 
                a_es <= es;
                a_format <= format;
                a_float_posit <= float_posit;
                a_Config_port <= Config_port;
                a_Config_port_full <= Config_port_full;
                a_full_precision <= full_precision;
                r_m_quire <= m_quire;
                r_c_quire <= c_quire;
                r_m_sf_fixed <= m_sf;
                r_c_sf_fixed <= c_sf;
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
--            end if;
--        end if;
--    end process;

--    stall_seq: process(clk)
--    begin
--        if rising_edge(clk) then
--            if rst = '1' then
--                a_stall <= '1';
--            else
                a_stall <= stall;
--            end if;
--        end if;
--    end process;

end Behavioral;
