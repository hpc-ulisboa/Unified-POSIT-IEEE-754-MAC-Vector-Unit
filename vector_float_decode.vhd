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

entity vector_float_decode is
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
end vector_float_decode;

architecture Behavioral of vector_float_decode is

    constant EXP_WIDTH_8 : integer := EXP_width(G_DATA_WIDTH/4);
    constant EXP_WIDTH_16 : integer := EXP_width(G_DATA_WIDTH/2);
    constant EXP_WIDTH_32 : integer := EXP_width(G_DATA_WIDTH);
    
    constant BIAS_8 : integer := 2**(EXP_WIDTH_8-1)-1;
    constant BIAS_16 : integer := 2**(EXP_WIDTH_16-1)-1;
    constant BIAS_32 : integer := 2**(EXP_WIDTH_32-1)-1;
    
    constant BIAS_8_V : std_logic_vector (4*EXP_WIDTH_8-1 downto 0) :=  std_logic_vector(to_signed(-BIAS_8, EXP_WIDTH_8)) & std_logic_vector(to_signed(-BIAS_8, EXP_WIDTH_8)) & std_logic_vector(to_signed(-BIAS_8, EXP_WIDTH_8)) & std_logic_vector(to_signed(-BIAS_8, EXP_WIDTH_8));
    constant BIAS_16_V : std_logic_vector(4*EXP_WIDTH_8-1 downto 0) :=  std_logic_vector(to_signed(-BIAS_16, 2*EXP_WIDTH_8)) & std_logic_vector(to_signed(-BIAS_16, 2*EXP_WIDTH_8));
    constant BIAS_32_V : std_logic_vector(4*EXP_WIDTH_8-1 downto 0) :=  std_logic_vector(to_signed(-BIAS_32, 4*EXP_WIDTH_8));
    
     
    signal exp: std_logic_vector(4*EXP_WIDTH_8-1 downto 0);
    signal expZ, expF, fracZ : std_logic_vector(3 downto 0);
    signal BIAS, unbiased_exp: std_logic_vector(4*EXP_WIDTH_8-1 downto 0);
    signal frac_MSB : std_logic_vector(3 downto 0);
    signal NaN : std_logic_vector(3 downto 0);
    
    signal r_sig: std_logic_vector(3 downto 0);
    signal r_sf : std_logic_vector(G_DATA_WIDTH-1 downto 0);
	signal r_frac : std_logic_vector(G_DATA_WIDTH-1 downto 0);
	signal r_sNaN, r_qNaN, r_inf, r_zero: std_logic_vector(3 downto 0);
	
begin
    
	exp <= x"00" & fp(G_DATA_WIDTH-2 downto G_DATA_WIDTH-EXP_WIDTH_32-1) when Config_port(1)='0' else
	       "000" & fp(G_DATA_WIDTH-2 downto G_DATA_WIDTH-EXP_WIDTH_16-1) & "000" & fp(G_DATA_WIDTH/2-2 downto G_DATA_WIDTH/2-EXP_WIDTH_16-1) when Config_port(0)='0' else
	       fp(G_DATA_WIDTH-2 downto G_DATA_WIDTH-EXP_WIDTH_8-1) & fp(G_DATA_WIDTH*3/4-2 downto G_DATA_WIDTH*3/4-EXP_WIDTH_8-1) & 
	       fp(G_DATA_WIDTH/2-2 downto G_DATA_WIDTH/2-EXP_WIDTH_8-1) & fp(G_DATA_WIDTH/4-2 downto G_DATA_WIDTH/4-EXP_WIDTH_8-1);
	  
    exp_zero: vector_zero_detect generic map (G_DATA_WIDTH => 4*EXP_WIDTH_8)
              port map (Config_port => Config_port, v_a => exp, v_z => expZ);
   
    exp_all_ones: vector_all_ones_detect
                  port map (Config_port => Config_port, v_a => exp, v_f => expF);
                  
    frac_zero : vector_frac_zero_detect
                port map (Config_port => Config_port, v_a => fp, v_z => fracZ);
    
    BIAS <= BIAS_32_V when Config_port(1)='0' else
            BIAS_16_V when Config_port(0)='0' else
            BIAS_8_V;
            
	unbias: vector_adder generic map ( G_DATA_WIDTH => 4*EXP_WIDTH_8)                          
            port map (Config_port => Config_port, A => exp, B => BIAS, C_in => expZ, S => unbiased_exp, C_out => open);
            
    r_sig <= (others => fp(G_DATA_WIDTH-1)) when Config_port(1)='0' else
             fp(G_DATA_WIDTH-1) & fp(G_DATA_WIDTH-1) & fp(G_DATA_WIDTH/2-1) & fp(G_DATA_WIDTH/2-1) when Config_port(0)='0' else
             fp(G_DATA_WIDTH-1) & fp(G_DATA_WIDTH*3/4-1) & fp(G_DATA_WIDTH/2-1) & fp(G_DATA_WIDTH/4-1);
            
	r_sf <= (G_DATA_WIDTH/2-1 downto 0 => unbiased_exp(4*EXP_WIDTH_8-1)) & unbiased_exp when Config_port(1)='0' else
	        (G_DATA_WIDTH/4-1 downto 0 => unbiased_exp(4*EXP_WIDTH_8-1)) & unbiased_exp(4*EXP_WIDTH_8-1 downto 2*EXP_WIDTH_8) & (G_DATA_WIDTH/4-1 downto 0 => unbiased_exp(2*EXP_WIDTH_8-1)) & unbiased_exp(2*EXP_WIDTH_8-1 downto 0) when Config_port(0)='0' else
	        (G_DATA_WIDTH/8-1 downto 0 => unbiased_exp(4*EXP_WIDTH_8-1)) & unbiased_exp(4*EXP_WIDTH_8-1 downto 3*EXP_WIDTH_8) & (G_DATA_WIDTH/8-1 downto 0 => unbiased_exp(3*EXP_WIDTH_8-1)) & unbiased_exp(3*EXP_WIDTH_8-1 downto 2*EXP_WIDTH_8) &
	        (G_DATA_WIDTH/8-1 downto 0 => unbiased_exp(2*EXP_WIDTH_8-1)) & unbiased_exp(2*EXP_WIDTH_8-1 downto EXP_WIDTH_8) & (G_DATA_WIDTH/8-1 downto 0 => unbiased_exp(EXP_WIDTH_8-1)) & unbiased_exp(EXP_WIDTH_8-1 downto 0);
	                      	                              
	r_frac <=  "00" & not expZ(3) & fp(G_DATA_WIDTH-EXP_WIDTH_32-2 downto 0) & x"0" & "00" when Config_port(1)='0' else
	           "00" & not expZ(3) & fp(G_DATA_WIDTH-EXP_WIDTH_16-2 downto G_DATA_WIDTH/2) & "000" & "00" & not expZ(1) & fp(G_DATA_WIDTH/2-EXP_WIDTH_16-2 downto 0) & "000" when Config_port(0)='0' else
	           "00" & not expZ(3) & fp(G_DATA_WIDTH-EXP_WIDTH_8-2 downto G_DATA_WIDTH*3/4) & "00" & "00" & not expZ(2) & fp(G_DATA_WIDTH*3/4-EXP_WIDTH_8-2 downto G_DATA_WIDTH/2) & "00" & 
	           "00" & not expZ(1) & fp(G_DATA_WIDTH/2-EXP_WIDTH_8-2 downto G_DATA_WIDTH/4) & "00" & "00" & not expZ(0) & fp(G_DATA_WIDTH/4-EXP_WIDTH_8-2 downto 0) & "00";
    
    frac_MSB <= (others => fp(G_DATA_WIDTH-EXP_WIDTH_32-2)) when Config_port(1)='0' else
                fp(G_DATA_WIDTH-EXP_WIDTH_16-2) & fp(G_DATA_WIDTH-EXP_WIDTH_16-2) & fp(G_DATA_WIDTH/2-EXP_WIDTH_16-2) & fp(G_DATA_WIDTH/2-EXP_WIDTH_16-2) when Config_port(0)='0' else
                fp(G_DATA_WIDTH-EXP_WIDTH_8-2) & fp(G_DATA_WIDTH*3/4-EXP_WIDTH_8-2) & fp(G_DATA_WIDTH/2-EXP_WIDTH_8-2) & fp(G_DATA_WIDTH/4-EXP_WIDTH_8-2);
                
    NaN <= expF and (not fracZ);
	r_sNaN <= NaN and (not frac_MSB);
	r_qNaN <= NaN and frac_MSB;
	
	r_inf <= expF and fracZ;
	r_zero <= expZ and fracZ;
	
    --seq: process(clk)
    --begin
       -- if rising_edge(clk) then
           sig <= r_sig;
           sf <= r_sf;
           frac <= r_frac;
           sNaN <= r_sNaN;
           qNaN <= r_qNaN;
           inf <= r_inf;
           zero <= r_zero;
       -- end if;
   --end process;	

end Behavioral;
