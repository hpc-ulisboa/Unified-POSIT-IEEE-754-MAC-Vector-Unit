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

entity vector_barrel_sr_ef is
    Port ( --clk : in std_logic;
        config_port : in std_logic_vector(1 downto 0);
        a : in std_logic_vector (63 downto 0);
        shamt : in std_logic_vector (2 downto 0);
        sign: in std_logic_vector (3 downto 0);
        s : out std_logic_vector (63 downto 0);
        sticky : out std_logic_vector(3 downto 0)
    );
end vector_barrel_sr_ef;

architecture Behavioral of vector_barrel_sr_ef is

    procedure shift_right_carry_8(value: in std_logic_vector(15 downto 0); shamt: in std_logic_vector(1 downto 0); sign: in std_logic;
                                  signal r : out std_logic_vector(18 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(18 downto 0);
        variable paddings: std_logic_vector(1 downto 0);
        variable i: integer := 0; 
    begin
        paddings := (others => sign);
        result := value & "000";
        if (shamt(0) = '1') then result := paddings(0) & result(18 downto 1); end if;
        if (shamt(1) = '1') then result := paddings(1 downto 0) & result(18 downto 2); end if;
	    r <= result;
        or_red <= or_reduce(result(2 downto 1));
    end;    
    
    
    procedure shift_right_inc_16(value: in std_logic_vector(31 downto 0); shamt: in std_logic; sign: in std_logic;
                                signal r : out std_logic_vector(35 downto 0); signal or_red : out std_logic) is
        variable result: std_logic_vector(35 downto 0);
        variable paddings: std_logic_vector(3 downto 0);
    begin
        paddings := (others => sign);
        result :=  value & x"0";
        if (shamt = '1') then result := paddings(3 downto 0) & result(35 downto 4); end if;
        r <= result;
        or_red <= or_reduce(result(3 downto 0));
    end;
    
    type byte_shift_array is array(0 to 3) of std_logic_vector(18 downto 0);
    type halfword_shift_array is array(0 to 1) of std_logic_vector(35 downto 0);
    
    signal bsh : byte_shift_array;
    signal hwsh : halfword_shift_array;
    signal b_s, hw_s : std_logic_vector(63 downto 0);
    signal sticky_v8, sticky_v16 : std_logic_vector(3 downto 0);
    
    signal bsign : std_logic_vector(3 downto 0);
    signal hwsign : std_logic_vector(1 downto 0);
    
    signal bshamt : std_logic_vector(1 downto 0);
    signal hwshamt : std_logic;

    
begin
    
    -- Special sign configuration needed (sign_ext)
    with config_port select
    bsign <= sign when "11",
             sign(3) & '0' & sign(1) & '0' when "10",
             sign(3) & "000" when others;
    
    with config_port select
    hwsign <= sign(3) & sign(1) when "10",
              sign(3) & '0' when others;
   
   
    bshamt <= shamt(1 downto 0);

    with config_port select              
    hwshamt <= '0' when "11",
                shamt(2) when others;
                               

    byte_shift: for i in 0 to 3 generate
       shift_right_carry_8(a((i+1)*16-1 downto i*16), bshamt, bsign(i), bsh(i), sticky_v8(i));
    end generate;
    
    b_s(63 downto 48) <= bsh(3)(18 downto 3);
    byte_shift_or_even: for i in 0 to 1 generate
       with config_port select
       b_s((2*i+1)*16-1 downto (2*i)*16) <= bsh(2*i)(18 downto 3) when "11",
                                            (bsh(2*i)(18 downto 16) or bsh(2*i+1)(2 downto 0)) & bsh(2*i)(15 downto 3) when others; 
    end generate;
    b_s(31 downto 16) <= bsh(1)(18 downto 3) when config_port(1) = '1' else
                         (bsh(1)(18 downto 16) or bsh(2)(2 downto 0)) & bsh(1)(15 downto 3); 
    
    
    hw_shift: for i in 0 to 1 generate
       shift_right_inc_16(b_s((i+1)*32-1 downto i*32), hwshamt, hwsign(i), hwsh(i), sticky_v16(2*i));
    end generate;
    sticky_v16(1) <= '0';
    sticky_v16(3) <= '0';
       
    hw_s(63 downto 32) <= hwsh(1)(35 downto 4);
    hw_shift_or_even: 
       hw_s(31 downto 0) <= hwsh(0)(35 downto 4) when config_port(1) = '1' else
                            (hwsh(0)(35 downto 32) or hwsh(1)(3 downto 0)) & hwsh(0)(31 downto 4) ; 
            

    s <= hw_s;
    
    sticky <= (3 downto 1 => '0', 0 => sticky_v16(0) or sticky_v8(0))                       when config_port(1)='0' else  -- 32
              '0' & (sticky_v16(2) or sticky_v8(2)) & '0' & (sticky_v16(0) or sticky_v8(0)) when config_port(0)='0' else  -- 16
              sticky_v8;                                                                                                  -- 8
                  
--    seq: process(clk)

--    begin
--        if rising_edge(clk) then
--           C <= r(G_COUNT_WIDTH-1 downto 0);
--           V <= r(G_COUNT_WIDTH);
--        end if;
--    end process;
    
end Behavioral;
