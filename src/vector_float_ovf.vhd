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

entity vector_float_ovf is
    Port (
        config_port : in std_logic_vector(1 downto 0);
        sf : in std_logic_vector(31 downto 0);
        pre_float : in std_logic_vector (31 downto 0);
        denormal : in std_logic_vector (3 downto 0);
        zero : in std_logic_vector(3 downto 0);
        ovf : out std_logic_vector (3 downto 0)
    );
end vector_float_ovf;

architecture Behavioral of vector_float_ovf is
    
    constant EXP_WIDTH_8 : integer := EXP_width(8);
    constant EXP_WIDTH_16 : integer := EXP_width(16);
    constant EXP_WIDTH_32 : integer := EXP_width(32);
    
    signal sf_8_F : std_logic_vector(3 downto 0);
    signal sf_16_F : std_logic_vector(1 downto 0);
    signal sf_32_F : std_logic;
    
    signal sf_8_ovf : std_logic_vector(3 downto 0);
    signal sf_16_ovf : std_logic_vector(1 downto 0);
    signal sf_16_ovf_0_tmp, sf_32_ovf : std_logic;
    
    signal exp_rounded_8_F: std_logic_vector(3 downto 0);
    signal exp_rounded_16_F: std_logic_vector(1 downto 0);
    signal exp_rounded_32_F: std_logic;
    
    signal execption: std_logic_vector(3 downto 0);
    
    signal ovf_16: std_logic_vector(1 downto 0);
    signal ovf_32: std_logic;
    
begin

    sf_byte_all_1: for i in 0 to 3 generate
        sf_8_F(i) <= is_all_ones(sf(i*8+EXP_WIDTH_8-1 downto i*8));
    end generate;
    
    sf_16_F(0) <= sf_8_F(0) and sf(EXP_WIDTH_8);
    sf_16_F(1) <= sf_8_F(2) and sf(16+EXP_WIDTH_8);
    
    sf_32_F <= sf_16_F(0) and is_all_ones(sf(EXP_WIDTH_32-1 downto EXP_WIDTH_8+1));
    
    
    sf_byte_ovf: for i in 0 to 3 generate
        sf_8_ovf(i) <= or_reduce(sf(i*8+6 downto i*8+EXP_WIDTH_8));
    end generate;
    
    sf_16_ovf_0_tmp <= or_reduce(sf(11 downto EXP_WIDTH_16+3));
    sf_16_ovf(0) <= sf_16_ovf_0_tmp or or_reduce(sf(EXP_WIDTH_16+2 downto EXP_WIDTH_16));
    sf_16_ovf(1) <= or_reduce(sf(27 downto 16+EXP_WIDTH_16));
    
    sf_32_ovf <= sf_16_ovf_0_tmp or sf(12);
    
    
    exp_rounded_8_all_1: for i in 0 to 3 generate
        exp_rounded_8_F(i) <= is_all_ones(pre_float((i+1)*8-2 downto (i+1)*8-EXP_WIDTH_8-1));
    end generate;
    
    exp_rounded_16_F(0) <= exp_rounded_8_F(1) and pre_float(15-EXP_WIDTH_16);
    exp_rounded_16_F(1) <= exp_rounded_8_F(3) and pre_float(31-EXP_WIDTH_16);
    
    exp_rounded_32_F <= exp_rounded_16_F(1) and is_all_ones(pre_float(30-EXP_WIDTH_16 downto 31-EXP_WIDTH_32));
    
    
    
    execption <= denormal nor zero;
    
    
    ovf_16(0) <= (sf_16_ovf(0) or sf_16_F(0) or exp_rounded_16_F(0)) and execption(0);
    ovf_16(1) <= (sf_16_ovf(1) or sf_16_F(1) or exp_rounded_16_F(1)) and execption(2);
    
    ovf_32 <= (sf_32_ovf or sf_32_F or exp_rounded_32_F) and execption(0);
    
    
    ovf <= (others => ovf_32) when Config_port(1)='0' else 
           ovf_16(1) & ovf_16(1) & ovf_16(0) & ovf_16(0) when Config_port(0)='0' else
           (sf_8_ovf or sf_8_F or exp_rounded_8_F) and execption;
    
end Behavioral;
