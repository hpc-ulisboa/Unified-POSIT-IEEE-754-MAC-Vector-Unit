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

entity vector_barrel_sl_p is
    Generic ( 
            constant G_DATA_WIDTH : positive := 32);
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (G_DATA_WIDTH-1 downto 0);
        shamtv : in std_logic_vector (4*(log2(G_DATA_WIDTH/4)+1)-1 downto 0);
        s : out std_logic_vector (G_DATA_WIDTH-1 downto 0)
    );
end vector_barrel_sl_p;

architecture Behavioral of vector_barrel_sl_p is
    
    constant Q_sa_size: positive := log2(G_DATA_WIDTH/4);
    
    function shift_left_carry_Quarter(value: std_logic_vector(G_DATA_WIDTH/4-1 downto 0); shamt: std_logic_vector(Q_sa_size-1 downto 0)) return std_logic_vector is
        variable result: std_logic_vector(G_DATA_WIDTH/2-1 downto 0);
        variable paddings: std_logic_vector(G_DATA_WIDTH/8-1 downto 0);
        variable i: integer := 0;
    begin
        paddings := (others => '0');
        result := (G_DATA_WIDTH/4-1 downto 0 => '0') & value;
        while i < Q_sa_size loop
	       if (shamt(i) = '1') then result := result((2*G_DATA_WIDTH/4 - 2**i - 1) downto 0) & paddings(2**i - 1 downto 0);
	       end if;
	       i:=i+1;
	    end loop;
        return result;
    end;    
        
    
    function shift_left_inc_Half(value: std_logic_vector(G_DATA_WIDTH/2-1 downto 0); shamt: std_logic) return std_logic_vector is
        variable result: std_logic_vector(G_DATA_WIDTH-1 downto 0);
        variable paddings: std_logic_vector(G_DATA_WIDTH/4-1 downto 0);
    begin
        paddings := (others => '0');
        result := (G_DATA_WIDTH/2-1 downto 0 => '0') & value;
        if (shamt = '1') then result := result(G_DATA_WIDTH*3/4-1 downto 0) & paddings(G_DATA_WIDTH/4-1 downto 0); end if;
        return result;
    end;
    
    function shift_left_inc_All(value: std_logic_vector(G_DATA_WIDTH-1 downto 0); shamt: std_logic) return std_logic_vector is
        variable result: std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
        variable paddings: std_logic_vector(G_DATA_WIDTH/2-1 downto 0);
    begin
        paddings := (others => '0');
        result := (G_DATA_WIDTH-1 downto 0 => '0') & value;
        if (shamt = '1') then result := result(2*G_DATA_WIDTH*3/4-1 downto 0) & paddings(G_DATA_WIDTH/2-1 downto 0); end if;
        return result;
    end;

    type Q_shift_array is array(0 to 3) of std_logic_vector(G_DATA_WIDTH/2-1 downto 0);
    type H_shift_array is array(0 to 1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
    type Q_shamt_vector is array(0 to 3) of std_logic_vector(Q_sa_size-1 downto 0);
    
    signal Qsh : Q_shift_array;
    signal Hsh : H_shift_array;
    signal Ash : std_logic_vector(2*G_DATA_WIDTH-1 downto 0);
    signal Q_s, H_s : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    signal Qshamtv : Q_shamt_vector;
    signal Hshamtv : std_logic_vector(1 downto 0);
    signal Ashamtv : std_logic;
    
begin

    Qshamtv(0) <= shamtv(Q_sa_size-1 downto 0);
    with config_port select
    Qshamtv(1) <= shamtv(2*Q_sa_size downto Q_sa_size+1) when "11",
                  shamtv(Q_sa_size-1 downto 0) when others;
    with config_port select
    Qshamtv(2) <= shamtv(3*Q_sa_size+1 downto 2*(Q_sa_size+1)) when "11",
                  shamtv(3*Q_sa_size+1 downto 2*(Q_sa_size+1)) when "10",
                  shamtv(Q_sa_size-1 downto 0) when others;
    with config_port select
    Qshamtv(3) <= shamtv(4*(Q_sa_size)+2 downto 3*(Q_sa_size+1)) when "11",
                  shamtv(3*Q_sa_size+1 downto 2*(Q_sa_size+1)) when "10",
                  shamtv(Q_sa_size-1 downto 0) when others;
    
    
    with config_port select              
    Hshamtv(0) <= '0' when "11",
                   shamtv(Q_sa_size) when others;
    with config_port select              
    Hshamtv(1) <= '0' when "11",
                   shamtv(2*(Q_sa_size+1)+Q_sa_size) when "10",
                   shamtv(Q_sa_size) when others;
   
    with config_port select              
    Ashamtv <= '0' when "11",
               '0' when "10",
               shamtv(Q_sa_size+1) when others;


    Q_shift: for i in 0 to 3 generate
       Qsh(i) <= shift_left_carry_Quarter(a((i+1)*(G_DATA_WIDTH/4)-1 downto i*(G_DATA_WIDTH/4)), Qshamtv(i));
    end generate;
    
    Q_s(G_DATA_WIDTH/4-1 downto 0) <= Qsh(0)(G_DATA_WIDTH/4-1 downto 0);                        
    Q_shift_or_odd: for i in 0 to 1 generate
       with config_port select
       Q_s((2*i+2)*(G_DATA_WIDTH/4)-1 downto (2*i+1)*(G_DATA_WIDTH/4)) <= Qsh(2*i+1)(G_DATA_WIDTH/4-1 downto 0) when "11",
                                                                          Qsh(2*i)(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) or Qsh(2*i+1)(G_DATA_WIDTH/4-1 downto 0) when others; 
    end generate;
    with config_port select
    Q_s(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH/2) <= Qsh(2)(G_DATA_WIDTH/4-1 downto 0) when "11",
                                                     Qsh(2)(G_DATA_WIDTH/4-1 downto 0) when "10",
                                                     Qsh(1)(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/4) or Qsh(2)(G_DATA_WIDTH/4-1 downto 0) when others;

     
    H_shift: for i in 0 to 1 generate
       Hsh(i) <= shift_left_inc_Half(Q_s((i+1)*(G_DATA_WIDTH/2)-1 downto i*(G_DATA_WIDTH/2)), Hshamtv(i));
    end generate;
    
    H_s(G_DATA_WIDTH/2-1 downto 0) <= Hsh(0)(G_DATA_WIDTH/2-1 downto 0);

    with config_port select
    H_s(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) <= Hsh(1)(G_DATA_WIDTH/2-1 downto 0) when "11",
                                                 Hsh(1)(G_DATA_WIDTH/2-1 downto 0) when "10",
                                                 Hsh(0)(G_DATA_WIDTH-1 downto G_DATA_WIDTH/2) or Hsh(1)(G_DATA_WIDTH/2-1 downto 0) when others; 


      
    Ash <= shift_left_inc_All(H_s(G_DATA_WIDTH-1 downto 0), Ashamtv);
    
    s <= Ash(G_DATA_WIDTH-1 downto 0);
    
    
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;

