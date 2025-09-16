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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;


entity vector_barrel_sr_regime is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (39 downto 0);
        shamtv : in std_logic_vector (11 downto 0);
        sign: in std_logic_vector (3 downto 0);
        s : out std_logic_vector (31 downto 0);
        lsb : out std_logic_vector (3 downto 0);
        guard : out std_logic_vector (3 downto 0);
        round : out std_logic_vector (3 downto 0);
        sticky : out std_logic_vector(3 downto 0)
    );
end vector_barrel_sr_regime;

architecture Behavioral of vector_barrel_sr_regime is

    procedure shift_right_carry_10(value: in std_logic_vector(9 downto 0); shamt: in std_logic_vector(2 downto 0); sign: in std_logic;
                                  signal r : out std_logic_vector(19 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(19 downto 0);
        variable paddings: std_logic_vector(3 downto 0);
        variable i: integer := 0; 
    begin
        paddings := (others => sign);
        result := value & X"00" & "00";
        while i < 3 loop
	       if (shamt(i) = '1') then result := paddings(2**i - 1 downto 0) & result(19 downto 2**i);
	       end if;
	       i:=i+1;
	    end loop;
	    r <= result;
        or_red <= or_reduce(result(9 downto 3));
    end;    
    
    
    procedure shift_right_inc_20(value: in std_logic_vector(19 downto 0); shamt: in std_logic; sign: in std_logic;
                                signal r : out std_logic_vector(39 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(39 downto 0);
        variable paddings: std_logic_vector(7 downto 0);
    begin
        paddings := (others => sign);
        result :=  value & X"00000";
        if (shamt = '1') then result := paddings(7 downto 0) & result(39 downto 8); end if;
        r <= result;
        or_red <= or_reduce(result(19 downto 20-8));
    end;
    
    procedure shift_right_inc_40(value: in std_logic_vector(39 downto 0); shamt: in std_logic; sign: in std_logic;
                                 signal r : out std_logic_vector(79 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(79 downto 0);
        variable paddings: std_logic_vector(15 downto 0);
    begin
        paddings := (others => sign);
        result := value & X"0000000000";
        if (shamt = '1') then result := paddings(15 downto 0) & result(79 downto 16); end if;
        r <= result;
        or_red <= or_reduce(result(39 downto 40-16));
    end;


    type byte_shift_array is array(0 to 3) of std_logic_vector(19 downto 0);
    type halfword_shift_array is array(0 to 1) of std_logic_vector(39 downto 0);
    type byte_shamt_vector is array(0 to 3) of std_logic_vector(2 downto 0);
    
    signal bsh : byte_shift_array;
    signal hwsh : halfword_shift_array;
    signal wsh : std_logic_vector(79 downto 0);
    signal b_s, hw_s : std_logic_vector(39 downto 0);
    signal sticky_v8, sticky_v16, sticky_v32 : std_logic_vector(3 downto 0);
    
    signal bsign : std_logic_vector(3 downto 0);
    signal hwsign : std_logic_vector(1 downto 0);
    signal wsign : std_logic;
    
    signal bshamtv : byte_shamt_vector;
    signal hwshamtv : std_logic_vector(1 downto 0);
    signal wshamtv : std_logic;
    
begin
    
    with config_port select
    bsign <= sign when "11",
             sign(3) & '0' & sign(1) & '0' when "10",
             sign(3) & "000" when others;
    
    with config_port select
    hwsign <= sign(3) & sign(1) when "10",
              sign(3) & '0' when others;
   
    wsign <= sign(3);
    
    bshamtv(0) <= shamtv(2 downto 0);
    with config_port select
    bshamtv(1) <= shamtv(5 downto 3) when "11",
                  shamtv(2 downto 0) when others;
    with config_port select
    bshamtv(2) <= shamtv(8 downto 6) when "11",
                  shamtv(8 downto 6) when "10",
                  shamtv(2 downto 0) when others;
    with config_port select
    bshamtv(3) <= shamtv(11 downto 9) when "11",
                  shamtv(8 downto 6) when "10",
                  shamtv(2 downto 0) when others;
    
    with config_port select              
    hwshamtv(0) <= '0' when "11",
                   shamtv(3) when others;
    with config_port select              
    hwshamtv(1) <= '0' when "11",
                   shamtv(9) when "10",
                   shamtv(3) when others;


    with config_port select              
    wshamtv <= '0' when "11",
               '0' when "10",
               shamtv(4) when others;
               

    byte_shift: for i in 0 to 3 generate
       shift_right_carry_10(a((i+1)*10-1 downto i*10), bshamtv(i), bsign(i), bsh(i), sticky_v8(i));
    end generate;
    
    b_s(39 downto 40-10) <= bsh(3)(19 downto 10);
    byte_shift_or_even: for i in 0 to 1 generate
       with config_port select
       b_s((2*i+1)*10-1 downto (2*i)*10) <= bsh(2*i)(19 downto 10) when "11",
                                            (bsh(2*i)(19 downto 13) or bsh(2*i+1)(9 downto 3)) & bsh(2*i)(12 downto 10)when others; -- frist 3 bits are always '0' bsh(2*i+1)(2 downto 0)
    end generate;
    b_s(19 downto 10) <= bsh(1)(19 downto 10) when config_port(1) = '1' else
                         (bsh(1)(19 downto 13) or bsh(2)(9 downto 3)) & bsh(1)(12 downto 10); -- frist 3 bits are always '0'
    
    
    hw_shift: for i in 0 to 1 generate
       shift_right_inc_20(b_s((i+1)*20-1 downto i*20), hwshamtv(i), hwsign(i), hwsh(i), sticky_v16(2*i));
    end generate;
    sticky_v16(1) <= '0';
    sticky_v16(3) <= '0';
       
    hw_s(39 downto 40-20) <= hwsh(1)(39 downto 20);
    hw_shift_or_even: 
       hw_s(19 downto 0) <= hwsh(0)(39 downto 20) when config_port(1) = '1' else
                            (hwsh(0)(39 downto 32) or hwsh(1)(19 downto 12)) & hwsh(0)(31 downto 20); -- frist 12 bits are always '0'
            

    w_shift:
        shift_right_inc_40(hw_s(39 downto  0), wshamtv, wsign, wsh, sticky_v32(0));
        sticky_v32(3 downto 1) <= (others => '0');
           
    s <= '0' & wsh(79 downto 49) when config_port(1)='0' else
         '0' & hwsh(1)(39 downto 25) & '0' & hwsh(0)(39 downto 25) when config_port(0)='0' else
         '0' & bsh(3)(19 downto 13) & '0' & bsh(2)(19 downto 13) & '0' & bsh(1)(19 downto 13) & '0' & bsh(0)(19 downto 13);
         
    lsb <= (3 downto 1 => '0', 0 => wsh(49)) when config_port(1)='0' else
           '0' &  hwsh(1)(25) & '0' & hwsh(0)(25) when config_port(0)='0' else  
           bsh(3)(13) & bsh(2)(13) & bsh(1)(13) & bsh(0)(13); 
           
    guard <= (3 downto 1 => '0', 0 => wsh(48)) when config_port(1)='0' else
             '0' &  hwsh(1)(24) & '0' & hwsh(0)(24) when config_port(0)='0' else  
             bsh(3)(12) & bsh(2)(12) & bsh(1)(12) & bsh(0)(12); 
             
    round <= (3 downto 1 => '0', 0 => wsh(47)) when config_port(1)='0' else
             '0' &  hwsh(1)(23) & '0' & hwsh(0)(23) when config_port(0)='0' else  
             bsh(3)(11) & bsh(2)(11) & bsh(1)(11) & bsh(0)(11); 
    
    sticky <= (3 downto 1 => '0', 0 => sticky_v32(0) or sticky_v16(0) or sticky_v8(0) or or_reduce(wsh(46 downto 40))) when config_port(1)='0' else
              '0' & (sticky_v16(2) or sticky_v8(2) or or_reduce(hwsh(1)(22 downto 20))) & '0' & (sticky_v16(0) or sticky_v8(0) or or_reduce(hwsh(0)(22 downto 20))) when config_port(0)='0' else
              (sticky_v8(3) or bsh(3)(10)) & (sticky_v8(2) or bsh(2)(10)) & (sticky_v8(1) or bsh(1)(10)) & (sticky_v8(0) or bsh(0)(10));                                                                                                  --8
                  
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;
