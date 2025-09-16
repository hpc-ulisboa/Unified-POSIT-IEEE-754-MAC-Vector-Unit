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

entity vector_quire_normalization is
    Generic ( 
        constant G_DATA_WIDTH : positive := 32;
        constant G_MAX_ES_SIZE : positive :=3;
        constant C_QS : positive := 128);
    Port ( clk : in std_logic;
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
end vector_quire_normalization;

architecture Behavioral of vector_quire_normalization is
    
    constant C_CG : integer := 7;
    
    constant CLZ_OFFSET_8 : std_logic_vector (G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_CG, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_CG, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_CG, G_DATA_WIDTH/4)) & std_logic_vector(to_unsigned(C_CG, G_DATA_WIDTH/4));
    constant CLZ_OFFSET_16 : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_CG, G_DATA_WIDTH/2)) & std_logic_vector(to_unsigned(C_CG, G_DATA_WIDTH/2));
    constant CLZ_OFFSET_32 : std_logic_vector(G_DATA_WIDTH-1 downto 0) :=  std_logic_vector(to_unsigned(C_CG, G_DATA_WIDTH));
    signal CLZ_OFFSET : std_logic_vector(G_DATA_WIDTH-1 downto 0);

     -- Normalization
    signal v_zero, v_sign : std_logic_vector(3 downto 0);
    signal quire_nar: std_logic_vector(3 downto 0); 
    signal inv_quire_Cin : std_logic_vector(3 downto 0);
    signal s_quire_zero : std_logic_vector(3 downto 0);
    signal sig : std_logic_vector(3 downto 0);
    signal ext_q, inv_quire, comp_quire : std_logic_vector(C_QS-1 downto 0);
    signal zc : std_logic_vector(4*(log2(C_QS/4)+1)-1 downto 0);
    
    
    signal r_frac, r_frac_tmp : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal n_t_sticky_full_16, n_t_sticky_full: std_logic;
    signal n_t_sticky, r_sticky: std_logic_vector(3 downto 0);
    signal pad_zc, inv_pad_zc : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_sf_offset, r_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0); 
    
    signal rst_full: std_logic_vector (3 downto 0);   
    
begin
    
    
    sign_zero: vector_zero_sign_detect_p generic map (G_DATA_WIDTH => C_QS)
        port map (config_port => aa_Config_port_full, v_a => r_quire, v_z => v_zero, v_s => v_sign);
               
    -- nar or quire overflow
    quire_nar <=  r_quire_nar_tmp or r_overflow;
    r_quire_nar <= quire_nar;
    
    s_quire_zero <= r_quire_zero or v_zero;
    quire_zero <= s_quire_zero;
    
    sign_exp: for i in 0 to 3 generate
        sig(i) <= r_expt_sig(i) when r_quire_zero(i)='1' or r_quire_inf(i)='1' else
                  v_sign(i);
    end generate;
        r_sig <= sig;
        
    -- 2's complement             
    ext_q <= (31 downto 0 => v_sign(3)) & (31 downto 0 => v_sign(2)) & (31 downto 0 => v_sign(1)) & (31 downto 0 => v_sign(0));
    
    inv_quire <= r_quire xor ext_q;
	-- TODO: This can be removed (temporary solution). See TODO comment on vector_quire_op
    inv_quire_Cin <= (not r_sub_min_loss) and v_sign;
    quire_comp: vector_adder generic map ( G_DATA_WIDTH => C_QS)
                port map (Config_port => aa_Config_port_full, A => inv_quire, B => (others => '0'), C_in => inv_quire_Cin, S => comp_quire, C_out => open);
               

    leading_zeroes: vector_lzc128 
                    port map (config_port => aa_Config_port_full, a => comp_quire, c => zc, v => open);
    
    
    shift_fraction: vector_barrel_sl_round
                    port map (config_port => aa_Config_port_full, a => comp_quire, shamtv => zc, s => r_frac_tmp, sticky => n_t_sticky);
    
    
    r_frac(G_DATA_WIDTH/4-1 downto 0) <= r_frac_tmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) when aa_Config_port="11" and aa_full_precision ='1' else
                                         r_frac_tmp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) when aa_Config_port(1)='1' and aa_full_precision ='1' else
                                         r_frac_tmp(G_DATA_WIDTH/4-1 downto 0);
                                                      
    r_frac(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) <= r_frac_tmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) when aa_Config_port="10" and aa_full_precision ='1' else
                                                      r_frac_tmp(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4);                                                    
    
    r_frac(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) <= r_frac_tmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2); 
    
    
    n_t_sticky_full_16 <= or_reduce(r_frac_tmp(G_DATA_WIDTH/2-1 downto 0));
    
    n_t_sticky_full <= or_reduce(r_frac_tmp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2)) or n_t_sticky_full_16 when aa_Config_port ="11" else
                       n_t_sticky_full_16;
    
    
    r_sticky <= n_t_sticky or aa_sticky or ("000" & n_t_sticky_full) when aa_full_precision ='1' else
                n_t_sticky or aa_sticky;
    
    pad_zc <= x"00" & zc when aa_Config_port_full(1)='0' else 
              x"0" & zc(4*(log2(C_QS/4)+1)-1 downto 2*(log2(C_QS/4)+1)) & x"0" & zc(2*(log2(C_QS/4)+1)-1 downto 0) when aa_Config_port(0)='0' else 
              "00" & zc(4*(log2(C_QS/4)+1)-1 downto 3*(log2(C_QS/4)+1)) & "00" & zc(3*(log2(C_QS/4)+1)-1 downto 2*(log2(C_QS/4)+1)) & 
              "00" & zc(2*(log2(C_QS/4)+1)-1 downto (log2(C_QS/4)+1)) & "00" & zc((log2(C_QS/4)+1)-1 downto 0);

    inv_pad_zc <= not pad_zc;
    

    CLZ_OFFSET <= CLZ_OFFSET_32 when aa_Config_port_full(1)='0' else
                  CLZ_OFFSET_16 when aa_Config_port(0)='0' else
                  CLZ_OFFSET_8;
    
    offset: vector_adder generic map ( G_DATA_WIDTH => 32)  -- align with zero count
            port map (Config_port => aa_Config_port, A => CLZ_OFFSET, B => inv_pad_zc, C_in => "1111", S => r_sf_offset, C_out => open);
    
    
    sf_add: vector_adder generic map ( G_DATA_WIDTH => G_DATA_WIDTH)                          
        port map (Config_port => aa_Config_port, A => r_quire_sf, B => r_sf_offset, C_in => "0000", S => r_sf, C_out => open);
    
    
    rst_full <= "1111" when rst = '1' else
                "0000" when aa_full_precision = '0' or aa_Config_port(1)='0' else
                "1100" when aa_Config_port(0) = '0' else
                "1110";
           
    full_precision_rst: for i in 0 to 3 generate
        out_seq_rst: process(clk)
        begin
            if rising_edge(clk) then
                if rst_full(i) = '1' then
                    s_frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= (others => '0');
                    s_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= (others => '0');
                    s_sig(i) <= '0';
                    s_nar(i) <= '0';
                    s_sNaN(i) <= '0';
                    s_inf(i) <= '0';
                    s_zero(i) <= '0'; -- todo: ver se em modo full precision os outros vetores s�o 0
                    s_sticky(i) <= '0';
                elsif aa_stall = '0' then
                    s_frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= r_frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
                    s_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= r_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
                    s_sig(i) <= sig(i);
                    s_nar(i) <= quire_nar(i);
                    s_sNaN(i) <= r_quire_sNaN(i);
                    s_inf(i) <= r_quire_inf(i);
                    s_zero(i) <= s_quire_zero(i);
                    s_sticky(i) <= r_sticky(i);
                end if;
            end if;
        end process;
    end generate;
      
    out_seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                s_es <= (others => '0');
                s_format <= '0';
                s_float_posit <= '0';
                s_Config_port <= (others => '0');
            elsif aa_stall = '0' then
                s_es <= aa_es;
                s_format <= aa_format;
                s_float_posit <= aa_float_posit;
                s_Config_port <= aa_Config_port;
            end if;
        end if;
    end process;
    
    stall_seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                s_stall <= '1';
            else
                s_stall <= aa_stall;
            end if;
        end if;
    end process;
    
end Behavioral;
