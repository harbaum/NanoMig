//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.9.03 
//Created Time: 2024-05-24 22:03:19
// create_clock -name clk_7m -period 142.045 -waveform {0 71.022} [get_nets {clk_cnt[1]}]
// create_clock -name clk_28m -period 35.511 -waveform {0 17.755} [get_nets {clk_sys}]
create_clock -name clk_hdmi -period 7 -waveform {0 3} [get_nets {clk_pixel_x5}] -add
create_clock -name clk_osc -period 37 -waveform {0 18} [get_ports {clk}] -add
create_clock -name clk_spi -period 14.085 -waveform {0 7.04} [get_ports {mspi_clk}] -add
