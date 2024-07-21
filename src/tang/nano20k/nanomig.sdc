//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.10 
//Created Time: 2024-07-21 13:27:16
create_clock -name clk_sdram -period 14 -waveform {0 7.043} [get_nets {clk_71m}]
create_clock -name clk_7m -period 142 -waveform {0 71} [get_nets {clk_cnt[1]}]
create_clock -name clk_hdmi -period 7 -waveform {0 3} [get_nets {clk_pixel_x5}] -add
create_clock -name clk_spi -period 14 -waveform {0 7} [get_ports {mspi_clk}] -add
create_clock -name clk_osc -period 37 -waveform {0 18} [get_ports {clk}] -add
