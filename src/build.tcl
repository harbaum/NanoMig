set_device GW2AR-LV18QN88C8/I7 -name GW2AR-18C

add_file minimig/Minimig1.v
add_file minimig/Agnus.v
add_file minimig/Paula.v
add_file minimig/Denise.v
add_file minimig/Copper.v
add_file minimig/Blitter.v
add_file minimig/CIA8520.v
add_file minimig/Floppy.v
add_file minimig/Amber.v
add_file minimig/Beamcounter.v
add_file minimig/Bitplanes.v
add_file minimig/Gayle.v
add_file minimig/Gary.v
add_file minimig/Sprites.v
add_file minimig/Audio.v
add_file minimig/Clock.v
add_file fx68k/fx68k.sv
add_file fx68k/fx68kAlu.sv
add_file fx68k/uaddrPla.sv
add_file hdmi/audio_clock_regeneration_packet.sv
add_file hdmi/audio_info_frame.sv
add_file hdmi/audio_sample_packet.sv
add_file hdmi/auxiliary_video_information_info_frame.sv
add_file hdmi/hdmi.sv
add_file hdmi/packet_assembler.sv
add_file hdmi/packet_picker.sv
add_file hdmi/serializer.sv
add_file hdmi/source_product_description_info_frame.sv
add_file hdmi/tmds_channel.sv
add_file misc/mcu_spi.v
add_file misc/sysctrl.v
add_file misc/hid.v
add_file misc/osd_u8g2.v
add_file misc/ws2812.v
add_file misc/video_analyzer.v
add_file misc/sd_card.v
add_file misc/sd_rw.v
add_file misc/sdcmd_ctrl.v
add_file tang/nano20k/flash_dspi.v
add_file tang/nano20k/gowin_clkdiv/gowin_clkdiv.v
add_file tang/nano20k/gowin_rpll/pll_142m.v
add_file tang/nano20k/gowin_dpb/sector_dpram.v
add_file tang/nano20k/top.sv
add_file tang/nano20k/sdram.v
add_file tang/nano20k/nanomig.cst
add_file tang/nano20k/nanomig.sdc
add_file fx68k/microrom.mem
add_file fx68k/nanorom.mem
add_file ram_test/ram_test.hex

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name nanomig
set_option -verilog_std sysv2017
set_option -top_module top
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1

run all
