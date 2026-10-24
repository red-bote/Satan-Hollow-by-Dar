---------------------------------------------------------------------------------
-- Basys 3 top level for Satan's Hollow by Red~Bote, derived from
-- satans_hollow_de10_lite.vhd by Dar (darfpga@aol.fr,
-- http://darfpga.blogspot.fr); see that file for its history.
---------------------------------------------------------------------------------
--
-- release rev 01 : initial Basys 3 release
--  (23/10/2026)
--
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features :
--  PS2 keyboard input @onboard USB HID (PS/2 emulation)
--  Joystick input     @JXADC pins 1/2/3/7 = right/left/shield/fire (active low)
--  Audio pwm output   @PmodAMP2 on JA pins 1/2/4 (left channel, mixed);
--                     sw15 = audio disable, sw14 = gain
--
--  Video         : VGA 31kHz/60Hz and TV 15kHz
--  Cocktail mode : NO
--  Sound         : OK
--
-- Uses 1 MMCM (clk_wiz_0) for 40MHz from 100MHz
--
-- Board buttons :
--   btnC : reset game
--   btnU : Add coin 1
--   btnD : Add coin 2
--   btnL : Start 1 player
--   btnR : Start 2 players
--
-- Board switches :
--   sw11 : coin meters dip, sw12 : cocktail dip (down = default '0', up inverts;
--          cocktail marked "KO atm" in the source)
--   sw13 : 0 = 31kHz VGA, 1 = 15kHz TV (csync on hs)
--
-- Keyboard players inputs (MAME defaults) :
--
--   5 : Add coin 1
--   6 : Add coin 2
--   1 : Start 1 player
--   2 : Start 2 players
--   F2 : toggle service mode ON/OFF
--   LEFT CTRL   : fire
--   LEFT ALT    : shield
--   RIGHT arrow : move right
--   LEFT  arrow : move left
--
-- Other details : see satans_hollow.vhd
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;

entity satans_hollow_basys3 is
port(
  clk            : in std_logic;
  btnC           : in std_logic;
  btnU           : in std_logic;
  btnD           : in std_logic;
  btnL           : in std_logic;
  btnR           : in std_logic;
  sw             : in std_logic_vector(15 downto 0);

  vga_r     : out std_logic_vector(3 downto 0);
  vga_g     : out std_logic_vector(3 downto 0);
  vga_b     : out std_logic_vector(3 downto 0);
  vga_hs    : out std_logic;
  vga_vs    : out std_logic;

  JXADC            : in  std_logic_vector(4 downto 0);
  ps2_clk          : in  std_logic;
  ps2_dat          : in  std_logic;
  O_PMODAMP2_AIN   : out std_logic;
  O_PMODAMP2_GAIN  : out std_logic;
  O_PMODAMP2_SHUTD : out std_logic
);
end satans_hollow_basys3;

architecture struct of satans_hollow_basys3 is

  signal clock_40  : std_logic;
  signal reset     : std_logic;
  signal mmcm_locked : std_logic;

  signal clock_div : std_logic_vector(3 downto 0);

  signal r         : std_logic_vector(2 downto 0);
  signal g         : std_logic_vector(2 downto 0);
  signal b         : std_logic_vector(2 downto 0);
  signal hsync     : std_logic;
  signal vsync     : std_logic;
  signal csync     : std_logic;
  signal blankn    : std_logic;
  signal tv15Khz_mode : std_logic;

  signal audio_l           : std_logic_vector(15 downto 0);
  signal audio_r           : std_logic_vector(15 downto 0);
  signal pwm_accumulator_l : std_logic_vector(17 downto 0);

  -- 2-FF synchronizers for the asynchronous inputs
  signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
  signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
  signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
  signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0'); -- U, D, L, R
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
  attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

  signal kbd_intr       : std_logic;
  signal kbd_scancode   : std_logic_vector(7 downto 0);
  signal kbd_rel        : std_logic := '0';
  -- kbd_key : 0 up, 1 down, 2 left, 3 right, 4 left ctrl, 5 left alt,
  --           6 '1', 7 '2', 8 '5', 9 '6', 10 F2
  signal kbd_key        : std_logic_vector(10 downto 0) := (others => '0');
  signal kbd_f2_r       : std_logic := '0';
  signal service        : std_logic := '0'; -- toggled by F2
  signal joy_BBBBFRLDU  : std_logic_vector(8 downto 0);
  signal coin1_in       : std_logic;
  signal coin2_in       : std_logic;
  signal start1_in      : std_logic;
  signal start2_in      : std_logic;

  constant COIN_METERS_DEFAULT : std_logic := '0';
  constant COCKTAIL_DEFAULT    : std_logic := '0';
  signal coin_meters_in        : std_logic;
  signal cocktail_in           : std_logic;

begin

  -- btnC resets the MMCM; the core is held in reset until the MMCM locks
  reset <= btnC or not mmcm_locked;

  tv15Khz_mode <= sw(13);
  -- dips on spare switches, down = default, up inverts the bit
  coin_meters_in <= COIN_METERS_DEFAULT xor sw(11);
  cocktail_in    <= COCKTAIL_DEFAULT xor sw(12);

  -- Clock 40MHz for kick core and sound_board
  clocks : entity work.clk_wiz_0
  port map(
    clk_in1  => clk,
    clk_out1 => clock_40,
    reset    => btnC,
    locked   => mmcm_locked
  );

  -- synchronize asynchronous inputs to the core clock
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      ps2_clk_meta <= ps2_clk;      ps2_clk_s <= ps2_clk_meta;
      ps2_dat_meta <= ps2_dat;      ps2_dat_s <= ps2_dat_meta;
      jxadc_meta   <= JXADC;        jxadc_s   <= jxadc_meta;
      btn_meta     <= btnU & btnD & btnL & btnR;
      btn_s        <= btn_meta;
    end if;
  end process;

  -- Satans hollow
  satans_hollow : entity work.satans_hollow
  port map(
    clock_40   => clock_40,
    reset      => reset,

    tv15Khz_mode => tv15Khz_mode,
    video_r      => r,
    video_g      => g,
    video_b      => b,
    video_csync  => csync,
    video_blankn => blankn,
    video_hs     => hsync,
    video_vs     => vsync,

    separate_audio => '0', -- mixed : mono amp on the left channel
    audio_out_l    => audio_l,
    audio_out_r    => audio_r,

    coin1          => coin1_in,
    coin2          => coin2_in,
    start1         => start1_in,
    start2         => start2_in,

    left           => joy_BBBBFRLDU(2), -- left
    right          => joy_BBBBFRLDU(3), -- right
    fire1          => joy_BBBBFRLDU(4), -- left ctrl : fire
    fire2          => joy_BBBBFRLDU(0), -- left alt  : shield

    left_c         => joy_BBBBFRLDU(2), -- left
    right_c        => joy_BBBBFRLDU(3), -- right
    fire1_c        => joy_BBBBFRLDU(4), -- left ctrl : fire
    fire2_c        => joy_BBBBFRLDU(0), -- left alt  : shield

    coin_meters    => coin_meters_in,
    cocktail       => cocktail_in,    -- KO atm in the source

    service        => service, -- F2 (allow machine settings access)

    dbg_cpu_addr => open
  );

  -- adapt video to 4bits/color only and blank
  vga_r <= r & '0' when blankn = '1' else "0000";
  vga_g <= g & '0' when blankn = '1' else "0000";
  vga_b <= b & '0' when blankn = '1' else "0000";

  -- synchro composite/ synchro horizontale
  -- vga_hs <= csync;
  -- vga_hs <= hsync;
  vga_hs <= csync when tv15Khz_mode = '1' else hsync;
  -- commutation rapide / synchro verticale
  -- vga_vs <= '1';
  -- vga_vs <= vsync;
  vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

  -- clock divider for the pwm sound output
  process (reset, clock_40)
  begin
    if reset='1' then
      clock_div <= (others => '0');
    else
      if rising_edge(clock_40) then
        if clock_div = "1001" then
          clock_div <= (others => '0');
        else
          clock_div <= clock_div + '1';
        end if;
      end if;
    end if;
  end process;

  -- get scancode from keyboard
  keyboard : entity work.io_ps2_keyboard
  port map (
    clk       => clock_40, -- synchrounous clock with core
    kbd_clk   => ps2_clk_s,
    kbd_dat   => ps2_dat_s,
    interrupt => kbd_intr,
    scancode  => kbd_scancode
  );

  -- translate scancode to keys (MAME default keys, PS/2 set 2 codes)
  -- F0 marks a release; E0 is ignored, as in kbd_joystick (keypad 8/2/4/6
  -- also act as arrows, Right Ctrl/Alt as Left Ctrl/Alt).
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      if kbd_intr = '1' then
        if kbd_scancode = x"F0" then
          kbd_rel <= '1';
        elsif kbd_scancode /= x"E0" then
          kbd_rel <= '0';
          if kbd_scancode = x"75" then kbd_key(0)  <= not kbd_rel; end if; -- up arrow
          if kbd_scancode = x"72" then kbd_key(1)  <= not kbd_rel; end if; -- down arrow
          if kbd_scancode = x"6B" then kbd_key(2)  <= not kbd_rel; end if; -- left arrow
          if kbd_scancode = x"74" then kbd_key(3)  <= not kbd_rel; end if; -- right arrow
          if kbd_scancode = x"14" then kbd_key(4)  <= not kbd_rel; end if; -- left ctrl
          if kbd_scancode = x"11" then kbd_key(5)  <= not kbd_rel; end if; -- left alt
          if kbd_scancode = x"16" then kbd_key(6)  <= not kbd_rel; end if; -- 1
          if kbd_scancode = x"1E" then kbd_key(7)  <= not kbd_rel; end if; -- 2
          if kbd_scancode = x"2E" then kbd_key(8)  <= not kbd_rel; end if; -- 5
          if kbd_scancode = x"36" then kbd_key(9)  <= not kbd_rel; end if; -- 6
          if kbd_scancode = x"06" then kbd_key(10) <= not kbd_rel; end if; -- F2
        end if;
      end if;
      -- F2 toggles service mode on press (typematic repeat ignored)
      kbd_f2_r <= kbd_key(10);
      if kbd_f2_r = '0' and kbd_key(10) = '1' then
        service <= not service;
      end if;
    end if;
  end process;

  -- merge keyboard, buttons and JXADC joystick (active low)
  coin1_in  <= kbd_key(8) or btn_s(3); -- 5 or btnU
  coin2_in  <= kbd_key(9) or btn_s(2); -- 6 or btnD
  start1_in <= kbd_key(6) or btn_s(1); -- 1 or btnL
  start2_in <= kbd_key(7) or btn_s(0); -- 2 or btnR
  joy_BBBBFRLDU(0) <= kbd_key(5) or not jxadc_s(2); -- shield : left alt (JXADC3)
  joy_BBBBFRLDU(1) <= '0';
  joy_BBBBFRLDU(2) <= kbd_key(2) or not jxadc_s(1); -- left  (JXADC2)
  joy_BBBBFRLDU(3) <= kbd_key(3) or not jxadc_s(0); -- right (JXADC1)
  joy_BBBBFRLDU(4) <= kbd_key(4) or not jxadc_s(4); -- fire : left ctrl (JXADC7)
  joy_BBBBFRLDU(8 downto 5) <= "0000";

  -- pwm sound output
  process(clock_40)  -- use same clock as kick_sound_board
  begin
    if rising_edge(clock_40) then

      if clock_div = "0000" then
        pwm_accumulator_l  <=  ('0'&pwm_accumulator_l(16 downto 0)) + ('0'&audio_l&'0');
      end if;

    end if;
  end process;

  O_PMODAMP2_AIN   <= pwm_accumulator_l(17);
  O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
  O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
