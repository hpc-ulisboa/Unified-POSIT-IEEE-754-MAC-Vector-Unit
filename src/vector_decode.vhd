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

entity vector_decode is
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
        rst_frac: in std_logic_vector(3 downto 0);
        sig : out std_logic_vector(3 downto 0);
        sf : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        frac : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        nar : out std_logic_vector(3 downto 0);
        sNaN : out std_logic_vector(3 downto 0);
        inf : out std_logic_vector(3 downto 0);
        zero : out std_logic_vector(3 downto 0) );
end vector_decode;

architecture Behavioral of vector_decode is
    
    --posit
    signal p_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal p_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal p_sig : std_logic_vector(3 downto 0);
    signal p_nar : std_logic_vector(3 downto 0);
    signal p_zero : std_logic_vector(3 downto 0);
    
    --IEEE
    signal f_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal f_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal f_sig : std_logic_vector(3 downto 0);
    signal f_qNaN : std_logic_vector(3 downto 0);
    signal f_sNaN : std_logic_vector(3 downto 0);
    signal f_inf: std_logic_vector(3 downto 0);
    signal f_zero : std_logic_vector(3 downto 0);
    
    -- Outputs of decode stages
    signal v_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal v_frac_tmp, v_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal v_sig_tmp, v_sig : std_logic_vector(3 downto 0);
    signal v_nar : std_logic_vector(3 downto 0);
    signal v_SNaN : std_logic_vector(3 downto 0);
    signal v_inf : std_logic_vector(3 downto 0);
    signal v_zero_tmp, v_zero : std_logic_vector(3 downto 0);
    
begin
    posit_decode : vector_posit_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE)
        port map(
            Config_port => Config_port,
            es => es,
            pos => V,
            sig => p_sig,
            sf => p_sf,
            frac => p_frac,
            nar => p_nar,
            zero => p_zero
        );

    float_decode: vector_float_decode
        generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
        port map(
            Config_port => Config_port,
            fp => V,
            sig => f_sig,
            sf => f_sf,
            frac => f_frac,
            qNaN => f_qNaN,
            sNaN => f_sNaN,
            inf => f_inf,
            zero => f_zero
        );
        
    -- Select posit or IEEE 
    v_sig_tmp <= p_sig when format = '1' else
                 f_sig;
                 
    v_sig <= (others => v_sig_tmp(0)) when full_precision ='1' else
             v_sig_tmp;
    
    v_sf <= p_sf when format = '1' else
            f_sf;
            
    v_frac_tmp <= p_frac when format = '1' else
                  f_frac;
    
    v_frac(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4) <= v_frac_tmp(G_DATA_WIDTH/4-1 downto 0) when Config_port="11" and full_precision ='1' else
                                                      v_frac_tmp(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) when Config_port(1)='1' and full_precision ='1' else
                                                      v_frac_tmp(G_DATA_WIDTH-1 downto G_DATA_WIDTH*3/4);
                                                      
    v_frac(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) <= v_frac_tmp(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) when Config_port="10" and full_precision ='1' else
                                                        v_frac_tmp(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2);                                                    
    
    v_frac(G_DATA_WIDTH/2-1 downto 0) <= v_frac_tmp(G_DATA_WIDTH/2-1 downto 0); 
    
    v_nar <= p_nar when format = '1' else
             f_qNaN;
    v_sNaN <= x"0" when format = '1' else
              f_sNaN;
    v_inf <= x"0" when format = '1' else
             f_inf;
             
    v_zero_tmp <= p_zero when format = '1' else
                  f_zero;

    v_zero <= (others => v_zero_tmp(0)) when full_precision ='1' else
               v_zero_tmp;
    
    seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sig <= (others => '0');
                zero <= (others => '0');
            elsif stall = '0' then
                sig <= v_sig;
                zero <= v_zero;
            end if;
        end if;
    end process;
    
    full_precision_rst: for i in 0 to 3 generate
        seq: process(clk)
        begin
            if rising_edge(clk) then
                if rst_full(i) = '1' then
                    sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= (others => '0');
                    nar(i) <= '0';
                    sNaN(i) <= '0';
                    inf(i) <= '0';
                elsif stall = '0' then
                    sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= v_sf((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
                    nar(i) <= v_nar(i);
                    sNaN(i) <= v_sNaN(i);
                    inf(i) <= v_inf(i);
                end if;
            end if;
        end process;
    end generate;
    
    full_precision_rst_frac: for i in 0 to 3 generate
        seq: process(clk)
        begin
            if rising_edge(clk) then
                if rst_frac(i) = '1' then
                    frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= (others => '0');
                elsif stall = '0' then
                    frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4) <= v_frac((i+1)*G_DATA_WIDTH/4-1 downto i*G_DATA_WIDTH/4);
                end if;
            end if;
        end process;
    end generate;

end Behavioral;
