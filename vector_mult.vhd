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

entity vector_mult is
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
end vector_mult;

architecture Behavioral of vector_mult is
    
    signal sf_add : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal S_mult, C_mult, mult_frac : std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
    signal fp_inv: std_logic_vector(3 downto 0);
    signal ovf_mult, ovf_mult_tmp: std_logic_vector(3 downto 0); 
    signal r_zero, r_nar, r_SNaN, r_inf : std_logic_vector(3 downto 0);
    
    signal r_sig : std_logic_vector(3 downto 0);
    signal r_sf  : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal r_frac : std_logic_vector(2*G_DATA_WIDTH-1 downto 0);

begin

    r_nar <= a_nar or b_nar;
    r_zero <= a_zero or b_zero; 
    
    -- fp exceptions
    fp_inv <= (a_inf and b_zero) or (b_inf and a_zero);
    r_SNaN <= a_SNaN or b_SNaN or fp_inv;  
    r_inf <= (a_inf or b_inf) and not r_nar;
       
    
    -- Sign calculation
    r_sig <= a_sig xor b_sig;
   
    -- Multiply fractions
    vector_mult: vector_mult_cs 
                 port map (config_port => Config_port, a => a_frac, b => b_frac, s => S_mult, c => C_mult);
               
    mult_frac <=  std_logic_vector(unsigned(S_mult) + unsigned(C_mult(62 downto 0) & '0'));
    
    ovf_mult_tmp <= (others => mult_frac(2*(G_DATA_WIDTH-2)-1)) when Config_port(1)='0' else  --32
                    mult_frac(2*(G_DATA_WIDTH-2)-1) & mult_frac(2*(G_DATA_WIDTH-2)-1) & mult_frac(2*(G_DATA_WIDTH/2-2)-1) & mult_frac(2*(G_DATA_WIDTH/2-2)-1) when Config_port(0)='0' else --16
                    mult_frac(2*(G_DATA_WIDTH-2)-1) & mult_frac(2*(G_DATA_WIDTH*3/4-2)-1) & mult_frac(2*(G_DATA_WIDTH/2-2)-1) & mult_frac(2*(G_DATA_WIDTH/4-2)-1);

    ovf_mult <= ovf_mult_tmp when Config_port(1)='0' or full_precision ='0'  else
                --"000" & ovf_mult_tmp(3) when Config_port(0)='0' else
                "000" & ovf_mult_tmp(3);

    -- Adjusting for overflow 
    overflow: vector_frac_overflow 
              port map (a => mult_frac, ovf => ovf_mult_tmp, s => r_frac);
 
    -- Exponent addition w/ overflow adjustment
    sf_v: vector_adder generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
          port map (Config_port => Config_port, A => a_sf, B => b_sf, C_in => ovf_mult , S => sf_add, C_out => open);

    r_sf <= sf_add;
    
    seq: process(clk)      
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                s_sig <= (others => '0');
                s_sf <= (others => '0');
                s_frac <= (others => '0');
                s_nar <= (others => '0');
                s_SNaN <= (others => '0');
                s_inf <= (others => '0');
                s_zero <= (others => '0');
            elsif stall = '0' then
                s_sig <= r_sig;
                s_sf <= r_sf;
                s_frac <= r_frac;
                s_nar <= r_nar;
                s_SNaN <= r_SNaN;
                s_inf <= r_inf;
                s_zero <= r_zero;
            end if;
        end if;
    end process;
   
    
end Behavioral;
