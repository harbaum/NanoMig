// Copyright 2006, 2007 Dennis van Weeren
// 
// This file is part of Minimig
// 
// Minimig is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
// 
// Minimig is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http:// www.gnu.org/licenses/>.
// 
// 
// 
// This is the top module for the Minimig rev1.0 board
// 
// 19-03-2005 	-started coding
// 10-04-2005	-added cia's 
// 				-verified timers a/b and I/O ports
// 11-04-2005	-adapted top to cleaned up address decoder
// 				-connected cia's to .clk(~qclk) and .tick(e) for testing
// 13-04-2005	-_foe and _loe are now made with clocks driving FF's
// 				-sram_bridge now also gets .clk(clk)
// 18-04-2005	-added second synchronisation latch for mreset
// 19-04-2005	-bootrom is now 2Kbyte large
// 05-05-2005	-made preparations for dma (bus multiplexers between agnus and cpu)
// 15-05-2005	-added denise
// 				-connected vertb (vertical blank intterupt) to int3 input of paula
// 18-05-2005	-removed interlaced top input pin
// 28-06-2005	-done some experimentation to solve logic loop in Agnus
// 17-07-2005	-connected second ram bank to hold kickstart rom
// 				-added ovl (kickstart overlay) and boot (bootrom overlay) signals
// 				-wired cia in/out ports more correctly
// 				-wired vsync/hsync to cia's
// 18-07-2005	-experimented to get kickstart running
// 20-07-2005	-still experimenting..
// 07-08-2005	-Jahoeee!! kickstart doesn't guru anymore but 'clicks' the floppy drive !
// 				-the guru's were caused by spurious writes to ram which is fixed now in the sram controller
// 				-unfortunately still no insert workbench screen but that may be caused by the missing blitter
// 04-09-2005	-added blitter finished interrupt
// 11-09-2005	-added 2meg addressing for Agnus
// 13-09-2005	-added 4bit (per color) video output
// 16-10-2005	-added user IO module
// 23-10-2005	-added dmal signal wire
// 08-11-2005	-fixed typo in instantiation of Paula
// 21-11-2005	-added some signals to handle floppy
// 22-11-2005	-adapted to new add-on develop board
// 				-added joystick 1 port
// 10-12-2005	-done some experimentation to find floppy bug
// 21-12-2005	-reworked code to use new style gary module
// 27-12-2005	-added dskindx interrupt
// 03-01-2006	-added dmas to avoid interference with copper cycles
// 11-01-2006	-added Amber
// 15-01-2006	-added syscontrol module to handle automatic boot sequence
// 22-01-2006	-removed _csync port from agnus
// 23-01-2006	-added fastblit input
// 24-01-2006	-cia's now count positive _hsync/_vsync transitions
// 14-02-2006	-code clean up
// 				-added fastchip input
// 19-02-2006	-improved indx disk interrupt timing
// 				-cia timers now connect to sol/sof
// 12-11-2006	-started porting code to Minimig rev1.0 board
// 17-11-2006	-added address decoding for Minimig rev1.0 ram
// 22-11-2006	-added keyboard reset
// 27-11-2006	-code adapted to new synchronous bootrom
// 03-12-2006	-added dimming powerled
// 11-12-2006	-updated code to new ciaa
// 27-12-2006	-updated code to new ciab
// 24-06-2007	-moved cpu/sram/clock and syscontrol to this file to reduce number of source files
// 
// TODO: 		-fixs bug and implement things I forgot.....

// JB:
// 2008-07-17
// 	- scan doubler with vertical and horizontal interpolation
// 	- transparent osd window
// 	- selected osd line highlight
// 	- osd control by joystick (up and down pressed simultaneously invoke menu) 
// 	- memory configuration from osd (512KB chip, 1MB chip, 512KB chip/512KB slow, 1MB chip/512KB slow)
// 	- video interpolation filter configuration from osd (vertical and horizontal)
// 	- user reset accessible from osd
// 	- user reset to bootloader (kickstart reloading)
// 	- new bootloader (text messages during kickstart loading)
// 	- ECS blittter
// 	- PAL/NTSC selection
// 	- modified display dma engine (better compatibility)
// 	- modified sprite dma engine (better compatibility)
// 	- modified copper timing (better compatibility) 
// 	- modified floppy interface (better read and write support)
// 	- Action Replay III module for debugging (takes 512KB memory bank)
// 
// Thanks to:
// Dennis for his great Minimig
// Loriano for impressive enclosure 
// Darrin and Oscar for their ideas, support and help
// Toni for his indispensable help and logic analyzer (and WinUAE :-)
// 
// 2008-09-22 	- code clean-up
// 2008-09-23	- added c1 and c3 clock anable signals
// 				- adapted sram bridge to use only clk28m clock
// 2008-09-24	- added support for floppy _sel[3:1] signals
// 2008-11-14	- ram interface synchronous with clk28m, 70ns access cycle
// 2009-04-21	- code clean up
// 
// Thanks to Loriano, Darrin, Richard, Edwin, Sascha, Peter and others for their help, support, ideas, testing, bug reports and feature requests.
// 
// 2009-05-17	- hires OSD
// 2009-05-23	- more cycle exact CPU bus timing during CIA access
// 2009-05-24	- clean-up & renaming
// 2009-05-29	- changed blitter timing to be more cycle exact
// 2009-06-09	- fixed disk index pulses to 5 Hz (300 RPM)
// 2009-06-10	- fixed non-interlaced frames to be long
// 2009-06-11	- fixed serial port divider
// 2009-06-12	- CIA's SDR register returns written value
// 2009-07-01	- enabling of ddfstrt/ddfstop ECS extension bits is configurable
// 2009-08-11	- support for second hardfile
// 2009-08-16	- Action Replay problem fixed (thanks Sascha)
// 2009-12-15	- improved blitter data flow
// 2009-12-16	- improved bitplane dma timing
// 				- Denise id is selectable
// 2010-05-30	- htotal changed
// 2010-07-27	- fixed isue with external reset
// 2010-07-28	- added vsync for the MCU
// 2010-08-05	- added cache for the CPU
// 2010-08-15	- added joystick emulation
//
// SB:
// 2010-12-22	- better drive step sound at 31KHz mode
// 2011-03-06	- changed autofire function to handless mode
// 2011-03-08	- added dip and fat agnus DIWSTRT handling (fix RoboCop2)
// 2011-04-02	- added functional ciaa port b (parallel) register to let Unreal game work and some trainer store data
// 2011-04-04	- added pwm controlled power-led at "off" state and active Turbo mode (thanks Herzi for the idea)
// 2011-04-10	- added readable VPOSW and VHPOSW register (fix for RSI slideshow)
// 11-04-2011	- autofire function toggle able via capslock / led status

module Minimig1
(
	// m68k pins
	input [23:1]  cpu_address, // m68k address bus
	output [15:0] cpu_data, // m68k data bus
	input [15:0]  cpu_wrdata, // m68k data bus
	output [2:0]  n_cpu_ipl, // m68k interrupt request
	input 	      n_cpu_as, // m68k address strobe
	input 	      n_cpu_uds, // m68k upper data strobe
	input 	      n_cpu_lds, // m68k lower data strobe
	input 	      cpu_r_w, // m68k read / write
	output 	      n_cpu_dtack, // m68k data acknowledge
 
	// sram pins
	output [15:0] ram_data, // sram data bus
	output [18:1] ram_address_out, // sram address bus
        output [7:0]  bank,		// memory bank select
	output 	      n_ram_bhe, // sram upper byte select
	output 	      n_ram_ble, // sram lower byte select
	output 	      n_ram_we, // sram write enable
	output 	      n_ram_oe, // sram output enable

	// system	pins
	input 	      clk, // system clock (7.09379 MHz)
	input 	      clk28m, // 28.37516 MHz clock

	// rs232 pins
	input 	      rxd, // rs232 receive
	output 	      txd, // rs232 send
	input 	      cts, // rs232 clear to send
	output 	      rts, // rs232 request to send

	// I/O
	input [5:0]   n_joy1, // joystick 1 [fire2,fire,right,left,down,up] (default mouse port)
	input [5:0]   n_joy2, // joystick 2 [fire2,fire,right,left,down,up] (default joystick port)
	input 	      n_15khz, // scandoubler disable
	output 	      pwrled, // power led

        input 	      keystrobe, // keyboard interface
        input [7:0]   keydat,
        output 	      keyack,
        input [5:0]   mouse,

        // Interface MiSTeryNano sd card interface. This very simple connection allows the core
        // to request sectors from within a OSD selected image file
	input [3:0]   sdc_img_mounted,
	input [31:0]  sdc_img_size,
        output [3:0]  sdc_rd,
        output [31:0] sdc_sector,
        input 	      sdc_busy,
        input 	      sdc_done,
	input 	      sdc_byte_in_strobe,
	input [8:0]   sdc_byte_in_addr,
	input [7:0]   sdc_byte_in_data,

	// video
	output 	      n_hsync, // horizontal sync
	output 	      n_vsync, // vertical sync
	output [3:0]  red, // red
	output [3:0]  green, // green
	output [3:0]  blue, // blue
	// audio
	output [14:0] aud_l, // left DAC data
	output [14:0] aud_r, // right DAC data
	// user i/o
	output 	      floppyled,
	// unused pins
	input [15:0]  ramdata_in, //sram data bus in
	input 	      cpurst,
	input [4:0]   n_joy3, // joystick 3 [fire2,fire,right,left,down,up] (joystick port)
	input [4:0]   n_joy4			// joystick 4 [fire2,fire,right,left,down,up] (joystick port)
);

//--------------------------------------------------------------------------------------

	parameter NTSC = 1'b0;			// Agnus type (PAL/NTSC)

//--------------------------------------------------------------------------------------

// local signals for data bus
wire		[15:0] cpu_data_in;		// cpu data bus in
wire		[15:0] cpu_data_out;	// cpu data bus out
wire		[15:0] ram_data_in;		// ram data bus in
wire		[15:0] ram_data_out;	// ram data bus out
wire		[15:0] custom_data_in;	// custom chips data bus in
wire		[15:0] custom_data_out;	// custom chips data bus out
wire		[15:0] agnus_data_out;	// agnus data out
wire		[15:0] paula_data_out;	// paula data bus out
wire		[15:0] denise_data_out;	// denise data bus out
wire		[15:0] user_data_out;	// user IO data out
wire		[15:0] gary_data_out;	// data out from memory bus multiplexer
wire		[15:0] gayle_data_out;	// Gayle data out
wire		[15:0] cia_data_out;	// cia A+B data bus out

// local signals for address bus
wire		[23:1] cpu_address_out;	// cpu address out
wire		[20:1] dma_address_out;	// agnus address out
// wire		[18:1] ram_address_out;	// ram address out

// local signals for control bus
wire		ram_rd;					// ram read enable
wire		ram_hwr;				// ram high byte write enable 
wire		ram_lwr;				// ram low byte write enable 
wire		cpu_rd; 				// cpu read enable
wire		cpu_hwr;				// cpu high byte write enable
wire		cpu_lwr;				// cpu low byte write enable
wire		cck;					// colour clock (chipset dma slots indication)

// register address bus
wire		[8:1] reg_address; 		// main register address bus

// rest of local signals
wire		aflock;
wire		c1,c3;				// clock enable signals
wire		[9:0] eclk;			// E clock enable
wire		dbr;				// data bus request, Agnus tells CPU that she is using the bus
wire		dbwe;				// data bus write enable, Agnus tells the RAM it's writing data
wire		dbs;				// data bus slow down, used for slowing down CPU access to chip, slow and custor register address space
wire		xbs;				// cross bridge access (memory and custom registers)
wire		ovl;				// kickstart overlay enable
wire		_led;				// power led
wire		[3:0] sel_chip;			// chip ram select
wire		[2:0] sel_slow;			// slow ram select
wire		sel_kick;			// rom select
wire		sel_cia;			// CIA address space
wire		sel_reg;			// chip register select
wire		sel_cia_a;			// cia A select
wire		sel_cia_b;			// cia B select
wire		int2;				// intterrupt 2
wire		int3;				// intterrupt 3 
wire		int6;				// intterrupt 6
wire		kb_lmb;
wire		kb_rmb;
wire		[5:0] kb_joy2;
wire		_fire0;				// joystick 1 fire signal to cia A
wire		_fire1;				// joystick 2 fire signal to cia A
wire		[3:0] audio_dmal;		// audio dma data transfer request from Paula to Agnus
wire		[3:0] audio_dmas;		// audio dma location pointer restart from Paula to Agnus
wire		disk_dmal;			// disk dma data transfer request from Paula to Agnus
wire		disk_dmas;			// disk dma special request from Paula to Agnus
wire		index;				// disk index interrupt

// local video signals
wire		blank;				// blanking signal
wire		sol;				// start of video line
wire		sof;				// start of video frame
wire		vbl_int;			// vertical blanking interrupt
wire		strhor_denise;			// horizontal strobe for Denise
wire		strhor_paula;			// horizontal strobe for Paula
wire		[3:0]red_i;			// denise red (internal)
wire		[3:0]green_i;			// denise green (internal)
wire		[3:0]blue_i;			// denise blue (internal)
wire		_hsync_i;			// horizontal sync (internal)
wire		_vsync_i;			// vertical sync (internal)
wire		_csync_i;			// composite sync (internal)
wire		[8:1] htotal;			// video line length (140ns units)

// local floppy signals (CIA<-->Paula)
wire		_step;				// step heads of disk
wire		direc;				// step heads direction
wire		_sel0;				// disk0 select 	
wire		_sel1;				// disk1 select 	
wire		_sel2;				// disk2 select 	
wire		_sel3;				// disk3 select 	
wire		side;				// upper/lower disk head
wire		_motor;				// disk motor control
wire		_track0;			// track zero detect
wire		_change;			// disk has been removed from drive
wire		_ready;				// disk is ready
wire		_wprot;				// disk is write-protected

//--------------------------------------------------------------------------------------

wire	bls;			// blitter slowdown - required for sharing bus cycles between Blitter and CPU

wire	ovr;			// overide chip memmory decoding

wire	[1:0] lr_filter = 2'b00;// lowres interpolation filter mode: bit 0 - horizontal, bit 1 - vertical
wire	[1:0] hr_filter = 2'b00;// hires interpolation filter mode: bit 0 - horizontal, bit 1 - vertical
wire	[1:0] scanline;		// scanline effect configuration
wire	hires;			// hires signal from Denise for interpolation filter enable in Amber
wire	[3:0] memory_config;	// memory configuration
wire	[3:0] floppy_config;	// floppy drives configuration (drive number and speed)
wire	[3:0] chipset_config;	// chipset features selection

// gayle stuff
wire	sel_ide;		// select IDE drive registers
wire	sel_gayle;		// select GAYLE control registers
wire	gayle_irq;		// interrupt request
wire	gayle_nrdy;		// HDD fifo is not ready for reading

wire	disk_led;		// floppy disk activity LED

reg	ntsc = NTSC;		// PAL/NTSC video mode selection

//--------------------------------------------------------------------------------------


//--------------------------------------------------------------------------------------
assign floppyled = disk_led;
assign pwrled = !_led;

// NTSC/PAL switching is controlled by OSD menu, change requires reset to take effect
always @(posedge clk)
	if (cpurst)
		ntsc <= (chipset_config[1]);

// vertical sync for the MCU
reg vsync_del = 1'b0; 	// delayed vsync signal for edge detection
reg	vsync_t = 1'b0;		// toggled vsync output

always @(posedge clk)
	vsync_del <= (_vsync_i);
	
always @(posedge clk)
	if (~_vsync_i && vsync_del)
		vsync_t <= (~vsync_t);

// Disabled Action Replay
assign ovr=1'b0;

//--------------------------------------------------------------------------------------

// instantiate agnus
Agnus AGNUS1
(
	.clk(clk),
	.clk28m(clk28m),
	.cck(cck),
	.reset(cpurst),
	.aen(sel_reg),
	.rd(cpu_rd),
	.hwr(cpu_hwr),
	.lwr(cpu_lwr),
	.data_in(custom_data_in),
	.data_out(agnus_data_out),
	.address_in(cpu_address_out[8:1]),
	.address_out(dma_address_out),
	.reg_address_out(reg_address),
	.dbr(dbr),
	.dbwe(dbwe),
	._hsync(_hsync_i),
	._vsync(_vsync_i),
	._csync(_csync_i),
	.blank(blank),
	.sol(sol),
	.sof(sof),
	.vbl_int(vbl_int),
	.strhor_denise(strhor_denise),
	.strhor_paula(strhor_paula),
	.htotal(htotal),
	.int3(int3),
	.audio_dmal(audio_dmal),
	.audio_dmas(audio_dmas),
	.disk_dmal(disk_dmal),
	.disk_dmas(disk_dmas),
	.bls(bls),
	.ntsc(ntsc),
	.a1k(chipset_config[2]),
	.ecs(chipset_config[3]),
	.floppy_speed(floppy_config[0])
);

// instantiate paula
Paula PAULA1
(
	.clk(clk),
	.clk28m(clk28m),
	.cck(cck),
	.reset(cpurst),
	.reg_address_in(reg_address),
	.data_in(custom_data_in),
	.data_out(paula_data_out),
	.txd(txd),
	.rxd(rxd),
	.ntsc(ntsc),
	.sof(sof),
	.strhor(strhor_paula),
	.vblint(vbl_int),
	.int2(int2|gayle_irq),
	.int3(int3),
	.int6(int6),
	._ipl(n_cpu_ipl),
	.audio_dmal(audio_dmal),
	.audio_dmas(audio_dmas),
	.disk_dmal(disk_dmal),
	.disk_dmas(disk_dmas),
	._step(_step),
	.direc(direc),
	._sel({_sel3,_sel2,_sel1,_sel0}),
	.side(side),
	._motor(_motor),
	._track0(_track0),
	._change(_change),
	._ready(_ready),
	._wprot(_wprot),
	.index(index),
	.disk_led(disk_led),
	.left(aud_l),
	.right(aud_r),

        // sd card interface for floppy disk emulation
        .sdc_image_mounted(sdc_img_mounted),
        .sdc_image_size(sdc_img_size),           // length of image file
        .sdc_rd(sdc_rd),
        .sdc_sector(sdc_sector),
        .sdc_busy(sdc_busy),
        .sdc_done(sdc_done),
	.sdc_byte_in_strobe(sdc_byte_in_strobe),
	.sdc_byte_in_addr(sdc_byte_in_addr),
	.sdc_byte_in_data(sdc_byte_in_data),
 
	.floppy_drives(floppy_config[3:2])
);

assign chipset_config = 4'b1000;   // ecs, a500 (!a1k), pal, unused    
// assign memory_config = 4'b0101;    // 1MB chip & 512k slow ram   
assign memory_config = 4'b0011;    // 2MB chip
assign floppy_config = 4'b0100;    // two floppy drives, unused, speed 0
   
assign scanline = 1'b0;

// ----------------------- simple replacement for user_io hw registers --------------------
parameter JOY0DAT = 9'h00a;
parameter JOY1DAT = 9'h00c;
parameter POTINP  = 9'h016;
parameter POTGO   = 9'h034;
   
// mouse input gives quadrature signals
reg [7:0] mouse_x;
reg [7:0] mouse_y;

reg [3:0] mouse_D;   // move events through two registers to
reg [3:0] mouse_D2;  // bring into local clock domain

wire [1:0] mouse_en = {
	    mouse_D[0] ^ mouse_D2[0] ^ mouse_D[1] ^ mouse_D2[1],
	    mouse_D[2] ^ mouse_D2[2] ^ mouse_D[3] ^ mouse_D2[3]	    
};
   
wire [1:0] mouse_dir = {
	    mouse_D[0] ^ mouse_D2[1],
	    mouse_D[2] ^ mouse_D2[3]	    
};   
  
always @(posedge clk) begin
   if(cpurst) begin
      mouse_x <= 8'd0;
      mouse_y <= 8'd0;
   end else begin   
      mouse_D <= mouse;   
      mouse_D2 <= mouse_D;   

      if(mouse_en[0]) begin
	 if(mouse_dir[0]) mouse_x <= mouse_x + 1'd1;
	 else             mouse_x <= mouse_x - 1'd1;
      end
      
      if(mouse_en[1]) begin
	 if(mouse_dir[1]) mouse_y <= mouse_y + 1'd1;
	 else             mouse_y <= mouse_y - 1'd1;
      end
   end
end

wire [7:0] js_x = { 6'b000000, !n_joy2[0], n_joy2[2]^n_joy2[0] };
wire [7:0] js_y = { 6'b000000, !n_joy2[1], n_joy2[3]^n_joy2[1] };

reg [15:0] potreg;
   
// POTGO register
always @(posedge clk)
  if(cpurst)
    potreg <= 0;
  else if (reg_address[8:1]==POTGO[8:1])
    potreg <= custom_data_in;
   
assign user_data_out =
    (reg_address[8:1]==JOY0DAT[8:1])?{mouse_y,mouse_x}:
    (reg_address[8:1]==JOY1DAT[8:1])?{js_y,js_x}:
    (reg_address[8:1]==POTINP[8:1])?
       {1'b0,n_joy2[5]&potreg[14],1'b0,potreg[12]&1'b1,1'b0,potreg[10]&!mouse[5]&n_joy1[5],1'b0,potreg[8],8'b00000000}:
    16'h00_00;
   
// assign fire outputs to cia A
assign _fire1 = n_joy2[4];
assign _fire0 = n_joy1[4] & !mouse[4];

// instantiate Denise
Denise DENISE1
(		
	.clk28m(clk28m),
	.clk(clk),
	.c1(c1),
	.c3(c3),
	.cck(cck),
	.reset(cpurst),
	.strhor(strhor_denise),
	.reg_address_in(reg_address),
	.data_in(custom_data_in),
	.data_out(denise_data_out),
	.blank(blank),
	.red(red_i),
	.green(green_i),
	.blue(blue_i),
	.ecs(chipset_config[3]),
	.a1k(chipset_config[2]),
	.hires(hires)
);

// instantiate Amber
Amber AMBER1
(		
	.clk28m(clk28m),
	.dblscan(n_15khz),
	.lr_filter(lr_filter),
	.hr_filter(hr_filter),
	.scanline(scanline),
	.htotal(htotal),
	.hires(hires),
	.red_in(red_i),
	.blue_in(blue_i),
	.green_in(green_i),
	._hsync_in(_hsync_i),
	._vsync_in(_vsync_i),
	._csync_in(_csync_i),
	.red_out(red),
	.blue_out(blue),
	.green_out(green),
	._hsync_out(n_hsync),
	._vsync_out(n_vsync)
);

// instantiate cia A
ciaa CIAA1
(
	.clk(clk),
	.aen(sel_cia_a),
	.rd(cpu_rd),
	.wr(cpu_lwr|cpu_hwr),
	.reset(cpurst),
	.rs(cpu_address_out[11:8]),
	.data_in(cpu_data_out[7:0]),
	.data_out(cia_data_out[7:0]),
	.tick(_vsync_i),
	.eclk({eclk[8]}),
	.irq({int2}),
	.porta_in({_fire1,_fire0,_ready,_track0,_wprot,_change}),
	.porta_out({_led,ovl}),
        .keystrobe(keystrobe),
        .keydat(keydat),
        .keyack(keyack),
	.disk_led(disk_led),
	._joy3(n_joy3),
	._joy4(n_joy4)

);

// instantiate cia B
ciab CIAB1 
(
	.clk(clk),
	.aen(sel_cia_b),
	.rd(cpu_rd),
	.wr(cpu_hwr|cpu_lwr),
	.reset(cpurst),
	.rs(cpu_address_out[11:8]),
	.data_in(cpu_data_out[15:8]),
	.data_out(cia_data_out[15:8]),
	.tick(_hsync_i),
	.eclk({eclk[8]}),
	.irq({int6}),
	.flag(index),
	.porta_in({1'b0,cts,1'b0}),
	.porta_out({dtr,rts}),
	.portb_out({_motor,_sel3,_sel2,_sel1,_sel0,side,direc,_step}),
	._joy3(n_joy3),
	._joy4(n_joy4)
);

// instantiate cpu bridge
m68k_bridge CPU1 
(
	.clk28m(clk28m),
	.c1(c1),
	.c3(c3),
	.cck(cck),
	.clk(clk),
	.eclk(eclk),
	.vpa(sel_cia),
	.dbr(dbr),
	.dbs(dbs),
	.xbs(xbs),
	.nrdy(gayle_nrdy),
	.bls(bls),
	._as(n_cpu_as),
	._lds(n_cpu_lds),
	._uds(n_cpu_uds),
	.r_w(cpu_r_w),
	._dtack(n_cpu_dtack),
	.rd(cpu_rd),
	.hwr(cpu_hwr),
	.lwr(cpu_lwr),
	.address(cpu_address),
	.address_out(cpu_address_out),
	.data(cpu_data),
	.wrdata(cpu_wrdata),
	.data_out(cpu_data_out),
	.data_in(cpu_data_in)
);

// instantiate RAM banks mapper
bank_mapper BMAP1
(
	.chip0((~ovr|~cpu_rd|dbr) & sel_chip[0]),
	.chip1(sel_chip[1]),
	.chip2(sel_chip[2]),
	.chip3(sel_chip[3]),	
	.slow0(sel_slow[0]),
	.slow1(sel_slow[1]),
	.slow2(sel_slow[2]),
	.kick(sel_kick),
	.ecs(chipset_config[3]),
	.memory_config(memory_config),
	.bank(bank)
);

// -- remains of sram_bridge
assign ram_data = ram_data_in;
wire ram_enable = (bank[7:0]==8'b00000000) ? 1'b0 : 1'b1;
assign n_ram_we = (!ram_hwr && !ram_lwr) | !ram_enable;
assign n_ram_oe = !ram_rd | !ram_enable; 
assign n_ram_bhe = !ram_hwr | !ram_enable;
assign n_ram_ble = !ram_lwr | !ram_enable;

// data_out multiplexer
assign ram_data_out = !n_ram_oe ? ramdata_in : 16'b0000000000000000;

// instantiate gary
gary GARY1 
(
	.cpu_address_in(cpu_address_out),
	.dma_address_in(dma_address_out),
	.ram_address_out(ram_address_out),
	.cpu_data_out(cpu_data_out),
	.cpu_data_in(gary_data_out),
	.custom_data_out(custom_data_out),
	.custom_data_in(custom_data_in),
	.ram_data_out(ram_data_out),
	.ram_data_in(ram_data_in),
	.cpu_rd(cpu_rd),
	.cpu_hwr(cpu_hwr),
	.cpu_lwr(cpu_lwr),
	.ovl(ovl),
	.dbr(dbr),
	.dbwe(dbwe),
	.dbs(dbs),
	.xbs(xbs),
	.memory_config(memory_config),
	.hdc_ena(1'b0), // Gayle decoding enable	
	.ram_rd(ram_rd),
	.ram_hwr(ram_hwr),
	.ram_lwr(ram_lwr),
	.ecs(chipset_config[3]),
	.sel_chip(sel_chip),
	.sel_slow(sel_slow),
	.sel_kick(sel_kick),
	.sel_cia(sel_cia),
	.sel_reg(sel_reg),
	.sel_cia_a(sel_cia_a),
	.sel_cia_b(sel_cia_b),
	.sel_ide(sel_ide),
	.sel_rtc(),
	.sel_gayle(sel_gayle)
);

gayle GAYLE1
(
	.clk(clk),
	.reset(cpurst),
	.address_in(cpu_address_out),
	.data_in(cpu_data_out),
	.data_out(gayle_data_out),
	.rd(cpu_rd),
	.hwr(cpu_hwr),
	.lwr(cpu_lwr),
	.sel_ide(sel_ide),
	.sel_gayle(sel_gayle),
	.irq(gayle_irq),
	.nrdy(gayle_nrdy),
 
	.hdd_ena(2'b00),
	.hdd_cmd_req(),
	.hdd_dat_req(),
	.hdd_data_in(),
	.hdd_addr(3'd0),
	.hdd_data_out(16'h0000),
	.hdd_wr(1'b0),
	.hdd_status_wr(1'b0),
	.hdd_data_wr(1'b0),
	.hdd_data_rd(1'b0)
	
);

// instantiate clock generator
clock_generator CLOCK1
(	
	.clk28m(clk28m),	// 28.37516 MHz clock output
	.c1(c1),		// clock enable signal
	.c3(c3),		// clock enable signal
	.cck(cck),		// colour clock enable
	.clk(clk),		// 7.09379  MHz clock output
	.eclk(eclk)		// ECLK enable (1/10th of CLK)
);


//-------------------------------------------------------------------------------------

// data multiplexer
assign cpu_data_in[15:0] = (gary_data_out[15:0]
			 | cia_data_out[15:0]
			 | gayle_data_out[15:0]);

assign custom_data_out[15:0] = (agnus_data_out[15:0]
			 | paula_data_out[15:0]
			 | denise_data_out[15:0]
			 | user_data_out[15:0]);

//--------------------------------------------------------------------------------------

endmodule

//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------

// This module maps physical 512KB blocks of every memory chip to different memory ranges in Amiga
module bank_mapper
(
	input	chip0,				// chip ram select: 1st 512 KB block
	input	chip1,				// chip ram select: 2nd 512 KB block
	input	chip2,				// chip ram select: 3rd 512 KB block
	input	chip3,				// chip ram select: 4th 512 KB block
	input	slow0,				// slow ram select: 1st 512 KB block 
	input	slow1,				// slow ram select: 2nd 512 KB block 
	input	slow2,				// slow ram select: 3rd 512 KB block 
	input	kick,				// Kickstart ROM address range select
	input	ecs,				// ECS chipset enable
	input	[3:0] memory_config,// memory configuration
	output	reg [7:0] bank		// bank select
);

		
always @(memory_config or chip0 or chip1 or chip2 or chip3 or slow0 or slow1 or slow2 or kick or ecs)
begin
	case (memory_config)
		4'b0000 : bank = {  1'b0,  1'b0,  1'b0,  1'b0,     kick,  1'b0,  1'b0, chip0 | chip1 | chip2 | chip3 }; // 0.5M CHIP
		4'b0001 : bank = {  1'b0,  1'b0,  1'b0,  1'b0,     kick,  1'b0, chip1 | chip3, chip0 | chip2 }; // 1.0M CHIP
		4'b0010 : bank = {  1'b0,  1'b0,  1'b0,  1'b0,     kick, chip2, chip1, chip0 }; // 1.5M CHIP
		4'b0011 : bank = {  1'b0,  1'b0, chip3,  1'b0,     kick, chip2, chip1, chip0 }; // 2.0M CHIP
		4'b0100 : bank = {  1'b0,  1'b0,  1'b0,  1'b0,     kick, slow0,  1'b0, chip0 | (chip1 & !ecs) | chip2 | (chip3 & !ecs) }; // 0.5M CHIP + 0.5MB SLOW
		4'b0101 : bank = {  1'b0,  1'b0,  1'b0,  1'b0,     kick, slow0, chip1 | chip3, chip0 | chip2 }; // 1.0M CHIP + 0.5MB SLOW
		4'b0110 : bank = {  1'b0,  1'b0,  1'b0, slow0,     kick, chip2, chip1, chip0 }; // 1.5M CHIP + 0.5MB SLOW
		4'b0111 : bank = {  1'b0,  1'b0, chip3, slow0,     kick, chip2, chip1, chip0 }; // 2.0M CHIP + 0.5MB SLOW
		4'b1000 : bank = {  1'b0,  1'b0,  1'b0,  1'b0,     kick, slow0, slow1, chip0 | chip1 | chip2 | chip3 }; // 0.5M CHIP + 1.0MB SLOW
		4'b1001 : bank = {  1'b0,  1'b0, slow1,  1'b0,     kick, slow0, chip1 | chip3, chip0 | chip2 }; // 1.0M CHIP + 1.0MB SLOW
		4'b1010 : bank = {  1'b0,  1'b0, slow1, slow0,     kick, chip2, chip1, chip0 }; // 1.5M CHIP + 1.0MB SLOW
		4'b1011 : bank = { slow1,  1'b0, chip3, slow0,     kick, chip2, chip1, chip0 }; // 2.0M CHIP + 1.0MB SLOW
		4'b1100 : bank = {  1'b0,  1'b0,  1'b0, slow2,     kick, slow0, slow1, chip0 | chip1 | chip2 | chip3 }; // 0.5M CHIP + 1.5MB SLOW
		4'b1101 : bank = {  1'b0,  1'b0, slow1, slow2,     kick, slow0, chip1 | chip3, chip0 | chip2 }; // 1.0M CHIP + 1.5MB SLOW
		4'b1110 : bank = {  1'b0, slow2, slow1, slow0,     kick, chip2, chip1, chip0 }; // 1.5M CHIP + 1.5MB SLOW
		4'b1111 : bank = { slow1, slow2, chip3, slow0,     kick, chip2, chip1, chip0 }; // 2.0M CHIP + 1.5MB SLOW
	endcase
end

endmodule

//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------

// This module interfaces Minimig's synchronous bus to the 68SEC000 CPU
// 
// cycle exact CIA interface:
// ECLK low for 6 cycles and high for 4
// data latched with falling edge of ECLK
// VPA sampled 3 CLKs before rising edge of ECLK
// VMA asserted one clock later if VPA recognized
// DTACK sampled one clock before ECLK falling edge
// 
//             ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___
// CLK     ___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___
//         ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___
// CPU_CLK    \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/
//         ___ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______
//         ___X___0___X___1___X___2___X___3___X___4___X___5___X___6___X___7___X___8___X___9___X___0___
//         ___                                                 _______________________________
// ECLK       \_______________________________________________/                               \_______
//                                    |       |_VMA_asserted                          
//                                    |_VPA_sampled                   _______________           ______
//                                                                            \\\\\\\\_________/       DTACK asserted (7MHz)
//                                                                                    |__DTACK_sampled (7MHz) 
//                                                                    _____________________     ______
//                                                                                         \___/       DTACK asserted (28MHz)
//                                                                                          |__DTACK_sampled (28MHz)
// 
// NOTE: in 28MHz mode this timing model is not (yet?) supported, CPU talks to CIAs with no waitstates
// 

module m68k_bridge
(
	input	clk28m,					// 28 MHz system clock
	input	c1,						// clock enable signal
	input	c3,						// clock enable signal
	input	clk,					// bus clock
	input	[9:0] eclk,				// ECLK enable signal
	input	vpa,					// valid peripheral address (CIAs)
	input	dbr, 					// data bus request, Gary keeps CPU off the bus (custom chips transfer data)
	input	dbs,					// data bus slowdown (access to chip ram or custom registers)
	input	xbs,					// cross bridge access (active dbr holds off CPU access)
	input	nrdy,					// target device is not ready
	output	bls,					// blitter slowdown, tells the blitter that CPU wants the bus
	input	cck,					// colour clock enable, active when dma can access the memory bus
	input	_as,					// m68k adress strobe
	input	_lds,					// m68k lower data strobe d0-d7
	input	_uds,					// m68k upper data strobe d8-d15
	input	r_w,					// m68k read / write
	output	_dtack,					// m68k data acknowledge to cpu
	output	rd,						// bus read 
	output	hwr,					// bus high write
	output	lwr,					// bus low write
	input	[23:1] address,			// external cpu address bus
	output	[23:1] address_out,	    // internal cpu address bus output
	output	[15:0] data,			// external cpu data bus
	input	[15:0] wrdata,
	output	[15:0] data_out,	// internal data bus output
	input	[15:0] data_in			// internal data bus input
);

localparam VCC = 1'b1;
localparam GND = 1'b0;

/*
68000 bus timing diagram

          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
        7 . 0 . 1 . 2 . 3 . 4 . 5 . 6 . 7 . 0 . 1 . 2 . 3 . 4 . 5 . 6 . 7 . 0 . 1
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
           ___     ___     ___     ___     ___     ___     ___     ___     ___
CLK    ___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
       _____________________________________________                         _____		  
R/W                 \_ _ _ _ _ _ _ _ _ _ _ _/       \_______________________/     
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
       _________ _______________________________ _______________________________ _		  
ADDR   _________X_______________________________X_______________________________X_
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
       _____________                     ___________                     _________
/AS                 \___________________/           \___________________/         
          .....   .   .   .       .   .   .....   .   .   .   .       .   .....
       _____________        READ         ___________________    WRITE    _________
/DS                 \___________________/                   \___________/         
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
       _____________________     ___________________________     _________________
/DTACK                      \___/                           \___/                 
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
                                     ___
DIN    -----------------------------<___>-----------------------------------------
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
                                                         ___________________
DOUT   -------------------------------------------------<___________________>-----
          .....   .   .   .   .   .   .   .....   .   .   .   .   .   .   .....
*/

wire	doe;					// data buffer output enable
reg		[15:0] ldata_in;		// latched data_in
wire	enable;					// enable
reg		lr_w,l_as,l_dtack;  	// synchronised inputs
reg		l_uds,l_lds;

reg		lvpa;					// latched valid peripheral address (CIAs)
reg		vma;					// valid memory address (synchronised VPA with ECLK)
reg		_ta;					// transfer acknowledge

// latched valid peripheral address
always @(posedge clk)
	lvpa <= vpa;

// vma output
always @(posedge clk)
	if (eclk[9])
		vma <= 0;
	else if (eclk[3] && lvpa)
		vma <= 1;

// latched CPU bus control signals
always @(posedge clk)
	{lr_w,l_as,l_dtack} <= ({r_w,_as,_dtack});

always @(posedge clk28m)
	{l_uds,l_lds} <= ({_uds,_lds});


// data transfer acknowledge in normal mode
reg _ta_n;
//always @(posedge clk28m or posedge _as)
always @(negedge clk or posedge _as)
	if (_as)
		_ta_n <= VCC;
	else if (!l_as && cck && ((!vpa && !(dbr && dbs)) || (vpa && vma && eclk[8])) && !nrdy)
		_ta_n <= GND;	

		
// actual _dtack generation (from 7MHz synchronous bus access and cache hit access)
//assign _dtack = (_ta_n & _ta_t & ~cache_hit);
assign _dtack = (_ta_n );

// synchronous control signals
assign enable = ~l_as & ~l_dtack & ~cck;
   
assign rd = (enable & lr_w);
// in turbo mode l_uds and l_lds may be delayed by 35 ns
assign hwr = (enable & ~lr_w & ~l_uds);
assign lwr = (enable & ~lr_w & ~l_lds);
// blitter slow down signalling, asserted whenever CPU is missing bus access to chip ram, slow ram and custom registers 
assign bls = (dbs & ~l_as & l_dtack);

// generate data buffer output enable
assign doe = (r_w & ~_as);

// ----------------------------------------------------------------------------------------------------------------------------------------------------- //

// data_out multiplexer and latch 	
//always @(data)
//	data_out <= wrdata;
assign data_out = wrdata;
//always @(clk or data_in)
//	if (!clk)
//		ldata_in <= data_in;
always @(posedge clk)
  ldata_in <= data_in;
  
// ----------------------------------------------------------------------------------------------------------------------------------------------------- //

// CPU data bus tristate buffers and output data multiplexer
//assign data[15:0] = doe ? cache_hit ? cache_out : ldata_in[15:0] : 16'bz;
assign data[15:0] = ldata_in;

assign	address_out[23:1] = address[23:1];

endmodule
