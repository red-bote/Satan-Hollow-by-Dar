#!/bin/bash
# Converted from make_satans_hollow_proms.bat
# 11/2024 Red~Bote (Glenn Neidermeier)

#
#rem midssio_82s123.12d CRC e1281ee9
#
#rem sh-pro.00 CRC 95e2b800
#rem sh-pro.01 CRC b99f6ff8
#rem sh-pro.02 CRC 1202c7b2
#rem sh-pro.03 CRC 0a64afb9
#rem sh-pro.04 CRC 22fa9175
#rem sh-pro.05 CRC 1716e2bb
#
#rem sh-snd.01 CRC 55a297cc
#rem sh-snd.02 CRC 46fc31f6
#rem sh-snd.03 CRC b1f4a6a8
#
#rem sh-bg.00  CRC 3e2b333c
#rem sh-bg.01  CRC d1d70cc4
#
#rem sh-fg.00  CRC 33f4554e
#rem sh-fg.01  CRC ba1a38b4
#rem sh-fg.02  CRC 6b57f6da
#rem sh-fg.03  CRC 37ea9d07

cat sh-pro.00  sh-pro.01  sh-pro.02  sh-pro.03  sh-pro.04  sh-pro.05 > satans_hollow_cpu.bin
./make_vhdl_prom satans_hollow_cpu.bin satans_hollow_cpu.vhd

cat sh-snd.01  sh-snd.02 sh-snd.03 > satans_hollow_sound_cpu.bin
./make_vhdl_prom satans_hollow_sound_cpu.bin satans_hollow_sound_cpu.vhd

./make_vhdl_prom sh-bg.00 satans_hollow_bg_bits_1.vhd
./make_vhdl_prom sh-bg.01 satans_hollow_bg_bits_2.vhd 


cat sh-fg.00  sh-fg.01  sh-fg.02  sh-fg.03 > satans_hollow_sp_bits.bin

./make_vhdl_prom satans_hollow_sp_bits.bin satans_hollow_sp_bits.vhd

./make_vhdl_prom 82s123.12d midssio_82s123.vhd

rm satans_hollow_cpu.bin
rm satans_hollow_sound_cpu.bin
rm satans_hollow_sp_bits.bin
