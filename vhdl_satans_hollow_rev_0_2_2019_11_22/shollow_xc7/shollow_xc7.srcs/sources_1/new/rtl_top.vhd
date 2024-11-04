----------------------------------------------------------------------------------
-- Company: Red~Bote
-- Engineer: Glenn Neidermeier
-- 
-- Create Date: 10/21/2024 09:17:50 PM
-- Design Name: 
-- Module Name: rtl_top - struct
-- Project Name: 
-- Target Devices: Artix 7
-- Tool Versions: Vivado 2020
-- Description: 
--   Top level for Satan Hollow on Basys 3 board
-- Dependencies: 
--   hdl_satans_hollow_rev_0_2_2019_11_22
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--   see rtl_dar/satans_hollow_de10_lite.vhd
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity rtl_top is
    port (
        vgaRed : out std_logic_vector (3 downto 0);
        vgaGreen : out std_logic_vector (3 downto 0);
        vgaBlue : out std_logic_vector (3 downto 0);
        vgaHsync : out std_logic;
        vgaVsync : out std_logic;

        sw : in std_logic_vector (15 downto 0);

        JA : in std_logic_vector(4 downto 0);

        ps2_clk : in std_logic;
        ps2_dat : in std_logic;

        O_PMODAMP2_AIN : out std_logic;
        O_PMODAMP2_GAIN : out std_logic;
        O_PMODAMP2_SHUTD : out std_logic;

        clk : in std_logic);
end rtl_top;

architecture struct of rtl_top is

    signal clock_40 : std_logic;
    signal clock_kbd : std_logic;
    signal reset : std_logic;

    signal clock_div : std_logic_vector(3 downto 0);

    signal r : std_logic_vector(2 downto 0);
    signal g : std_logic_vector(2 downto 0);
    signal b : std_logic_vector(2 downto 0);
    signal hsync : std_logic;
    signal vsync : std_logic;
    signal csync : std_logic;
    signal blankn : std_logic;
    signal tv15Khz_mode : std_logic;

    signal audio_l : std_logic_vector(15 downto 0);
    signal audio_r : std_logic_vector(15 downto 0);
    signal pwm_accumulator_l : std_logic_vector(17 downto 0);
    signal pwm_accumulator_r : std_logic_vector(17 downto 0);

--    alias ps2_clk : std_logic is JB(2);
--    alias ps2_dat : std_logic is JB(0);

    signal kbd_intr : std_logic;
    signal kbd_scancode : std_logic_vector(7 downto 0);
    signal joy_BBBBFRLDU : std_logic_vector(8 downto 0);
    signal fn_pulse : std_logic_vector(7 downto 0);
    signal fn_toggle : std_logic_vector(7 downto 0);

    signal dbg_cpu_addr : std_logic_vector(15 downto 0);

    alias vga_r : std_logic_vector is vgaRed;
    alias vga_g : std_logic_vector is vgaGreen;
    alias vga_b : std_logic_vector is vgaBlue;
    alias vga_hs : std_logic is vgaHsync;
    alias vga_vs : std_logic is vgaVsync;

    component clk_wiz_0
        port (-- Clock in ports
            -- Clock out ports
            clk_out1 : out std_logic;
            -- Status and control signals
            locked : out std_logic;
            clk_in1 : in std_logic
        );
    end component;

    signal coin_in : std_logic;
    signal start_1 : std_logic;

begin

--    coin_in <= not JA(4) and not JA(3); -- coin => fn_pulse(0), -- F1
--    start_1 <= not JA(4) and not JA(1); -- start1 => fn_pulse(1), -- F2

--    joy_BBBBFRLDU(3) <= not JA(0); -- right1
--    joy_BBBBFRLDU(2) <= not JA(1); -- left1
--    joy_BBBBFRLDU(0) <= not JA(3); -- up1 
--    joy_BBBBFRLDU(1) <= not JA(2); -- down1
--    joy_BBBBFRLDU(4) <= not JA(4); -- fire1

    reset <= '0'; -- not reset_n;

    tv15Khz_mode <= '0'; -- not fn_toggle(7); -- F8

    -- Clock 40MHz for kick core and sound_board
    clocks : clk_wiz_0
    port map(
        clk_in1 => clk,
        clk_out1 => clock_40,
        locked => open --pll_locked
    );

    -- Satans hollow
    satans_hollow : entity work.satans_hollow
        port map(
            clock_40 => clock_40,
            reset => reset,

            tv15Khz_mode => tv15Khz_mode,
            video_r => r,
            video_g => g,
            video_b => b,
            video_csync => csync,
            video_blankn => blankn,
            video_hs => hsync,
            video_vs => vsync,

            separate_audio => '0', -- fn_toggle(4), -- F5
            audio_out_l => audio_l,
            audio_out_r => audio_r,

--            coin1 => coin_in,
            coin1 => fn_pulse(0), -- F1
            coin2 => '0',
--            start1 => start_1,
            start1 => fn_pulse(1), -- F2
            start2 => fn_pulse(2), -- F3

            left => joy_BBBBFRLDU(2), -- left
            right => joy_BBBBFRLDU(3), -- right
            fire1 => joy_BBBBFRLDU(4), -- space
            fire2 => joy_BBBBFRLDU(0), -- up

            left_c => joy_BBBBFRLDU(2), -- left
            right_c => joy_BBBBFRLDU(3), -- right
            fire1_c => joy_BBBBFRLDU(4), -- space
            fire2_c => joy_BBBBFRLDU(0), -- up

            coin_meters => '0',
            cocktail => '0', -- fn_toggle(6), -- F7 -- KO atm

            service => fn_toggle(4), -- F5 -- (allow machine settings access)

            dbg_cpu_addr => dbg_cpu_addr
        );

    -- adapt video to 4bits/color only and blank
    vga_r <= r & '0' when blankn = '1' else "0000";
    vga_g <= g & '0' when blankn = '1' else "0000";
    vga_b <= b & '0' when blankn = '1' else "0000";

    vga_hs <= hsync;
    vga_vs <= vsync;

    -- get scancode from keyboard
    process (reset, clock_40)
    begin
        if reset = '1' then
            clock_div <= (others => '0');
            clock_kbd  <= '0';
        else
            if rising_edge(clock_40) then
                if clock_div = "1001" then
                    clock_div <= (others => '0');
                    clock_kbd  <= not clock_kbd;
                else
                    clock_div <= clock_div + '1';
                end if;
            end if;
        end if;
    end process;

    keyboard : entity work.io_ps2_keyboard
    port map (
        clk       => clock_kbd, -- synchrounous clock with core
        kbd_clk   => ps2_clk,
        kbd_dat   => ps2_dat,
        interrupt => kbd_intr,
        scancode  => kbd_scancode
    );

    -- translate scancode to joystick
    joystick : entity work.kbd_joystick
    port map (
        clk           => clock_kbd, -- synchrounous clock with core
        kbdint        => kbd_intr,
        kbdscancode   => std_logic_vector(kbd_scancode), 
        joy_BBBBFRLDU => joy_BBBBFRLDU,
        fn_pulse      => fn_pulse,
        fn_toggle     => fn_toggle
    );

    -- pwm sound output
    process (clock_40) -- use same clock as kick_sound_board
    begin
        if rising_edge(clock_40) then

            if clock_div = "0000" then
                pwm_accumulator_l <= ('0' & pwm_accumulator_l(16 downto 0)) + ('0' & audio_l & '0');
                pwm_accumulator_r <= ('0' & pwm_accumulator_r(16 downto 0)) + ('0' & audio_r & '0');
            end if;

        end if;
    end process;

    --pwm_audio_out_l <= pwm_accumulator_l(17);
    --pwm_audio_out_r <= pwm_accumulator_r(17); 

    -- active-low shutdown pin
    O_PMODAMP2_SHUTD <= sw(14);
    -- gain pin is driven high there is a 6 dB gain, low is a 12 dB gain 
    O_PMODAMP2_GAIN <= sw(15);

    O_PMODAMP2_AIN <= pwm_accumulator_l(17);

end struct;
