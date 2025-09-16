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

entity vector_encode is
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
end vector_encode;

architecture Behavioral of vector_encode is

    signal posit_nar: std_logic_vector(3 downto 0);
    
    signal V_posit, V_fp: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    signal inexact_fp, underflow_fp, overflow_fp, invalid_fp : std_logic_vector(3 downto 0);
    
    signal V_r: std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal out_inexact, out_underflow, out_overflow, out_invalid : std_logic_vector(3 downto 0);    
        
begin
    
    posit_nar <= sNaN or inf or nar when float_posit='1' else
                 nar;
    
    posit_encode : vector_posit_encode
    generic map ( G_DATA_WIDTH => G_DATA_WIDTH, G_MAX_ES_SIZE => G_MAX_ES_SIZE)
    port map(
        es => es,
        Config_port => Config_port,
        nar => posit_nar,
        zero => zero,
        sig => sig,
        sf => sf,
        frac => frac,
        sticky => sticky,
        s_pos => V_posit
    );
             
    float_encode : vector_float_encode
    generic map ( G_DATA_WIDTH => G_DATA_WIDTH)
    port map(
        Config_port => Config_port,
        qNaN => nar,
        sNaN => sNaN,
        inf => inf,
        zero => zero,
        sig => sig,
        sf => sf,
        frac => frac,
        sticky => sticky,
        inexact => inexact_fp,
        underflow => underflow_fp,
        overflow => overflow_fp,
        invalid => invalid_fp,
        s_fp => V_fp
    );
  
    -- Select posit or IEEE 
    V_r <= V_posit when format = '1' else
           V_fp;
    out_inexact <= x"0" when format = '1' else
                   inexact_fp;
    out_underflow <= x"0" when format = '1' else
                     underflow_fp;
    out_overflow <= x"0" when format = '1' else
                    overflow_fp;
    out_invalid <= x"0" when format = '1' else
                   invalid_fp;

        
    seq_out: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                Vr <= (others => '0');
                inexact <= (others => '0');
                underflow <= (others => '0');
                overflow <= (others => '0');
                invalid <= (others => '0');
            elsif stall = '0' then
                Vr <= V_r;
                inexact <= out_inexact;
                underflow <= out_underflow;
                overflow <= out_overflow;
                invalid <= out_invalid;
            end if;
        end if;
   end process;
   
   stall_seq: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                stall_o <= '1';
            else
                stall_o <= stall;
            end if;
        end if;
    end process;

end Behavioral;
