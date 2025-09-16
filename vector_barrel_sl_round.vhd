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


entity vector_barrel_sl_round is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (127 downto 0);
        shamtv : in std_logic_vector (23 downto 0);
        s : out std_logic_vector (31 downto 0);
        sticky : out std_logic_vector(3 downto 0)
    );
end vector_barrel_sl_round;

architecture Behavioral of vector_barrel_sl_round is
         
    procedure shift_left_carry_Quarter(value: std_logic_vector(31 downto 0); shamt: std_logic_vector(4 downto 0);
                                       signal r : out std_logic_vector(63 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(63 downto 0);
        variable paddings: std_logic_vector(15 downto 0);
        variable i: integer := 0;
    begin
        paddings := (others => '0');
        result := (31 downto 0 => '0') & value;
        while i < 5 loop
	       if (shamt(i) = '1') then result := result(64 - 2**i - 1 downto 0) & paddings(2**i - 1 downto 0);
	       end if;
	       i:=i+1;
	    end loop;
        r <= result;
        or_red <= or_reduce(result(32-8-1 downto 0));
    end;    
        
    
    procedure shift_left_inc_Half(value: std_logic_vector(63 downto 0); shamt: std_logic;
                                  signal r : out std_logic_vector(127 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(127 downto 0);
        variable paddings: std_logic_vector(31 downto 0);
    begin
        paddings := (others => '0');
        result := (63 downto 0 => '0') & value;
        if (shamt = '1') then result := result(95 downto 0) & paddings(31 downto 0); end if;
        r <= result;
        or_red <= or_reduce(result(64-16-1 downto 0));
    end;
    
    procedure shift_left_inc_All(value: std_logic_vector(127 downto 0); shamt: std_logic;
                                 signal r : out std_logic_vector(255 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(255 downto 0);
        variable paddings: std_logic_vector(63 downto 0);
    begin
        paddings := (others => '0');
        result := (127 downto 0 => '0') & value;
        if (shamt = '1') then result := result(191 downto 0) & paddings(63 downto 0); end if;
        r <= result;
        or_red <= or_reduce(result(128-32-1 downto 0));
    end;

    type Q_shift_array is array(0 to 3) of std_logic_vector(63 downto 0);
    type H_shift_array is array(0 to 1) of std_logic_vector(127 downto 0);
    type Q_shamt_vector is array(0 to 3) of std_logic_vector(4 downto 0);
    
    signal Qsh : Q_shift_array;
    signal Hsh : H_shift_array;
    signal Ash : std_logic_vector(255 downto 0);
    signal Q_s, H_s : std_logic_vector(127 downto 0);
    signal sticky_Q, sticky_H, sticky_A : std_logic_vector(3 downto 0);
    
    signal Qshamtv : Q_shamt_vector;
    signal Hshamtv : std_logic_vector(1 downto 0);
    signal Ashamtv : std_logic;
    
begin

    Qshamtv(0) <= shamtv(4 downto 0);
    with config_port select
    Qshamtv(1) <= shamtv(10 downto 6) when "11",
                  shamtv(4 downto 0) when others;
    with config_port select
    Qshamtv(2) <= shamtv(16 downto 12) when "11",
                  shamtv(16 downto 12) when "10",
                  shamtv(4 downto 0) when others;
    with config_port select
    Qshamtv(3) <= shamtv(22 downto 18) when "11",
                  shamtv(16 downto 12) when "10",
                  shamtv(4 downto 0) when others;
    
    
    with config_port select              
    Hshamtv(0) <= '0' when "11",
                   shamtv(5) when others;
    with config_port select              
    Hshamtv(1) <= '0' when "11",
                   shamtv(17) when "10",
                   shamtv(5) when others;
   
    with config_port select              
    Ashamtv <= '0' when "11",
               '0' when "10",
               shamtv(6) when others;


    Q_shift: for i in 0 to 3 generate
        shift_left_carry_Quarter(a((i+1)*32-1 downto i*32), Qshamtv(i), Qsh(i), sticky_Q(i));
    end generate;
    
    Q_s(31 downto 0) <= Qsh(0)(31 downto 0);
    Q_shift_or_odd: for i in 0 to 1 generate
        with config_port select
        Q_s((2*i+2)*32-1 downto (2*i+1)*32) <= Qsh(2*i+1)(31 downto 0) when "11",
                                             Qsh(2*i)(63 downto 32) or Qsh(2*i+1)(31 downto 0) when others; 
    end generate;
    with config_port select
    Q_s(95 downto 64) <= Qsh(2)(31 downto 0) when "11",
                         Qsh(2)(31 downto 0) when "10",
                         Qsh(1)(63 downto 32) or Qsh(2)(31 downto 0) when others;

     
    H_shift: for i in 0 to 1 generate
        shift_left_inc_Half(Q_s((i+1)*64-1 downto i*64), Hshamtv(i), Hsh(i), sticky_H(2*i));
    end generate;
    sticky_H(1) <= '0';
    sticky_H(3) <= '0';
    
    H_s(63 downto 0) <= Hsh(0)(63 downto 0);

    with config_port select
    H_s(127 downto 64) <= Hsh(1)(63 downto 0) when "11",
                          Hsh(1)(63 downto 0) when "10",
                          Hsh(0)(127 downto 64) or Hsh(1)(63 downto 0) when others; 


    shift_left_inc_All(H_s(127 downto 0), Ashamtv, Ash, sticky_A(0));
    sticky_A(3 downto 1) <= (others => '0');
    
         
    s <= Ash(127 downto 96) when config_port(1)='0' else
         Hsh(1)(63 downto 48) & Hsh(0)(63 downto 48) when config_port(0)='0' else
         Qsh(3)(31 downto 24) & Qsh(2)(31 downto 24) &
         Qsh(1)(31 downto 24) & Qsh(0)(31 downto 24);
         

--    s <= Ash(G_DATA_WIDTH-1 downto G_DATA_WIDTH-G_DATA_WIDTH/4)                                                              when config_port(1)='0' else
--         Ash(G_DATA_WIDTH-1 downto G_DATA_WIDTH-G_DATA_WIDTH/8) & Ash(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/2-G_DATA_WIDTH/8) when config_port(0)='0' else
--         Ash(G_DATA_WIDTH-1 downto G_DATA_WIDTH-G_DATA_WIDTH/16) & Ash(G_DATA_WIDTH*3/4-1 downto G_DATA_WIDTH*3/4-G_DATA_WIDTH/16) &
--         Ash(G_DATA_WIDTH/2-1 downto G_DATA_WIDTH/2-G_DATA_WIDTH/16) & Ash(G_DATA_WIDTH/4-1 downto G_DATA_WIDTH/4-G_DATA_WIDTH/16);
    
    sticky <= (3 downto 1 => '0', 0 => sticky_A(0)) when config_port(1)='0' else
              '0' & sticky_H(2) & '0' & sticky_H(0) when config_port(0)='0' else
              sticky_Q;
    
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;

