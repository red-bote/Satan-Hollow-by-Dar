# Satan-Hollow-by-Dar

Satan's Hollow (Midway MCR), FPGA core by Dar (<http://darfpga.blogspot.fr>), ported to
Digilent Basys 3 (`xc7a35tcpg236-1`). Upstream:
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/Satans_hollow/>
(`vhdl_satans_hollow_rev_0_2_2019_11_22.zip`, rev 0.2).

## Hardware

- Basys 3; VGA monitor (31 kHz) or 15 kHz TV (sw13, not verified).
- Keyboard on the onboard USB HID port.
- Optional: Atari-compatible joystick on Pmod JXADC (pins 1/2/3/7 =
  right/left/shield/fire, active low, pull-ups in the XDC).
- Optional: [PmodAMP2](https://digilent.com/reference/pmod/pmodamp2/start) on Pmod JA,
  pins 1/2/4 (mono: the core's left channel, both sound sources mixed).

## Build

Requires gcc, unzip, Vivado 2020.2, and
[openFPGALoader](https://github.com/trabucayre/openFPGALoader) (`make load` only).

```
make help        # list all targets
make roms        # shollow.zip from $ROMDIR
make bitstream   # Vivado batch build (runs make roms first if needed)
make load        # program the Basys 3 over USB (SRAM, lost at power-off)
```

Overrides, as make arguments or environment variables:
`VIVADO=<path>/bin/vivado` (default `/tools/Xilinx/Vivado/2020.2/bin/vivado`),
`ROMDIR=<dir>` (default `~/roms`), `ROMZIP=<zip>[,<zip>]`.

ROMs are not included. Do not redistribute roms or anything generated from them.

## IO

Keys follow the MAME defaults.

| Action   | Keyboard     | Basys 3                                       |
|----------|--------------|-----------------------------------------------|
| move     | Left / Right | JXADC pins 2 / 1                              |
| fire     | Left Ctrl    | JXADC pin 7                                   |
| shield   | Left Alt     | JXADC pin 3                                   |
| start 1P | 1            | btnL                                          |
| start 2P | 2            | btnR                                          |
| coin 1   | 5            | btnU                                          |
| coin 2   | 6            | btnD                                          |
| service  | F2 (toggle)  |                                               |
| reset    |              | btnC                                          |
| meters   |              | sw11 (coin meters; down = default)            |
| cocktail |              | sw12 (down = default; "KO atm" in the source) |
| display  |              | sw13 (down 31 kHz, up 15 kHz)                 |
| amp gain |              | sw14 (up gain active)                         |
| audio    |              | sw15 (up disabled)                            |

## Issues Addressed

- No upstream source changes; Basys 3 support is in the wrapper and XDC
  (`contrib/basys3/`).

## License

- Basys 3 port additions: MIT, see `LICENSE` (scope stated there).
- DarFPGA sources: educational use only; do not redistribute synthesized files with roms
  (see `vhdl_satans_hollow_rev_0_2_2019_11_22/README.txt`).
- T80 CPU (`rtl_t80_304/`): BSD-style, Daniel Wallner et al.
- YM2149 sound (`rtl_mikej/`): BSD-style, MikeJ.
