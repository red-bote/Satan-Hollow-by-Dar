-- ****
-- T80(b) core. In an effort to merge and maintain bug fixes ....
--
-- Ver 304 init values of registers on first startup (better simulation)
-- Ver 300 started tidyup
--
-- Latest version from www.fpgaarcade.com (original www.opencores.org)
--
-- $Id: T80_Reg.vhd 1330 2015-05-22 19:55:46Z wolfgang.scherr $
--
-- ****
--
-- T80 Registers, technology independent
--
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
--               MikeJ March 2005
--               Wolfgang Scherr 2011-2015 (email: WoS <at> pin4 <dot> at)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-- The latest version of this file can be found at:
--      http://www.opencores.org/cvsweb.shtml/t51/
--
-- Limitations :
--
-- File history :
--
--      0242 : Initial release
--
--      0244 : Changed to single register file
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity T80_Reg is
	port(
		Clk                     : in std_logic;
		CEN                     : in std_logic;
		WEH                     : in std_logic;
		WEL                     : in std_logic;
		AddrA           : in std_logic_vector(2 downto 0);
		AddrB           : in std_logic_vector(2 downto 0);
		AddrC           : in std_logic_vector(2 downto 0);
		DIH                     : in std_logic_vector(7 downto 0);
		DIL                     : in std_logic_vector(7 downto 0);
		DOAH            : out std_logic_vector(7 downto 0);
		DOAL            : out std_logic_vector(7 downto 0);
		DOBH            : out std_logic_vector(7 downto 0);
		DOBL            : out std_logic_vector(7 downto 0);
		DOCH            : out std_logic_vector(7 downto 0);
		DOCL            : out std_logic_vector(7 downto 0)
	);
end T80_Reg;

architecture rtl of T80_Reg is

	type Register_Image is array (natural range <>) of std_logic_vector(7 downto 0);
	signal      RegsH   : Register_Image(0 to 7)  := (others => (others => '0'));
	signal      RegsL   : Register_Image(0 to 7)  := (others => (others => '0'));

begin

	process (Clk)
	begin
		if Clk'event and Clk = '1' then
			if CEN = '1' then
				if WEH = '1' then
					RegsH(to_integer(unsigned(AddrA))) <= DIH;
				end if;
				if WEL = '1' then
					RegsL(to_integer(unsigned(AddrA))) <= DIL;
				end if;
			end if;
		end if;
	end process;

	DOAH <= RegsH(to_integer(unsigned(AddrA)));
	DOAL <= RegsL(to_integer(unsigned(AddrA)));
	DOBH <= RegsH(to_integer(unsigned(AddrB)));
	DOBL <= RegsL(to_integer(unsigned(AddrB)));
	DOCH <= RegsH(to_integer(unsigned(AddrC)));
	DOCL <= RegsL(to_integer(unsigned(AddrC)));

end;
