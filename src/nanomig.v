// nanomig.v

module nanomig (
   input	 clk_sys,
   input	 reset,

   output	 clk7_en,
   output	 clk7n_en,

   // misc
   output	 pwr_led,
   output	 fdd_led,

   // video
   output	 hs, // horizontal sync
   output	 vs, // vertical sync
   output [3:0]	 r,
   output [3:0]	 g,
   output [3:0]	 b,

   input [7:0]	 memory_config,
   input [5:0]	 chipset_config,
   input [3:0]	 floppy_config,
   input [3:0]	 video_config,
		
   output [14:0] audio_left, // left DAC data
   output [14:0] audio_right, // right DAC data

   // mouse and keyboard
   input [2:0]	 mouse_buttons, // mouse buttons
   input	 kbd_mouse_level,
   input [1:0]	 kbd_mouse_type,
   input [7:0]	 kbd_mouse_data,
   input [7:0]	 joystick,
		 
   // Interface MiSTeryNano sd card interface. This very simple connection allows the core
   // to request sectors from within a OSD selected image file
   input [3:0]	 sdc_img_mounted,
   input [31:0]	 sdc_img_size,
   output [3:0]	 sdc_rd,
   output [31:0] sdc_sector,
   input	 sdc_busy,
   input	 sdc_done,
   input	 sdc_byte_in_strobe,
   input [8:0]	 sdc_byte_in_addr,
   input [7:0]	 sdc_byte_in_data,
		
   // (s)ram interface
   output [15:0] ram_data, // sram data bus
   input [15:0]	 ramdata_in, // sram data bus in
   input [47:0]	 chip48, // big chip read
   output [23:1] ram_address, // sram address bus
   output	 _ram_bhe, // sram upper byte select
   output	 _ram_ble, // sram lower byte select
   output	 _ram_we, // sram write enable
   output	 _ram_oe      // sram output enable
);

reg reset_d;
always @(posedge clk_sys, posedge reset) begin
        reg [7:0] reset_s;
        reg rs;

        if(reset) reset_s <= '1;
        else begin
                reset_s <= reset_s << 1;
                rs <= reset_s[7];
                reset_d <= rs;
        end
end

//// amiga clocks ////
wire       c1;
wire       c3;
wire       cck;
wire [9:0] eclk;
// `define TEST_PHI_GEN
   
`ifdef TEST_PHI_GEN
reg [1:0]   mclkdiv;   
always @(posedge clk_sys) begin
   mclkdiv <= mclkdiv + 2'd1;  
end   
`endif // TEST_PHI_GEN
   
amiga_clk amiga_clk
(
`ifdef TEST_PHI_GEN
        .clk_28   ( mclkdiv[1] ), // input  clock c1 ( 28.687500MHz)
`else
        .clk_28   ( clk_sys    ), // input  clock c1 ( 28.687500MHz)
`endif
        .clk7_en  ( clk7_en    ), // output clock 7 enable (on 28MHz clock domain)
        .clk7n_en ( clk7n_en   ), // 7MHz negedge output clock enable (on 28MHz clock domain)
        .c1       ( c1         ), // clk28m clock domain signal synchronous with clk signal
        .c3       ( c3         ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
        .cck      ( cck        ), // colour clock output (3.54 MHz)
        .eclk     ( eclk       ), // 0.709379 MHz clock enable output (clk domain pulse)
        .reset_n  ( ~reset     )
);

// TODO: cpu_ph1 and cpu_ph2 are derived from a 114Mhz clock in original
// minimig aga. Current setting is taken from simulation:
// cpu_ph1 is valid before clk7_en and cpu_ph2 is after clk7_en
// so order is: cpu_ph1, clk7_en, cpu_ph2, clk7n_en
reg  cpu_ph1, cpu_ph2;
`ifndef TEST_PHI_GEN
always @(posedge clk_sys) begin
   if (~cpu_rst) begin
      cpu_ph1 <= 1'b0;
      cpu_ph2 <= 1'b0;
   end else begin 
//      cpu_ph1 <= !c1 &&  c3;  // on negedge clk_sys
//      cpu_ph2 <=  c1 && !c3;  // -"-
      cpu_ph1 <=   c1 &&  c3;
      cpu_ph2 <=  !c1 && !c3;
   end
end
`else   
reg  cyc;
reg  ram_cs;
always @(posedge clk_sys) begin
	reg [3:0] div;
	reg       c1d;

	div <= div + 1'd1;
	 
	c1d <= c1;
	if (~c1d & c1) div <= 3;
	
	if (~cpu_rst) begin
		cyc <= 0;
		cpu_ph1 <= 0;
		cpu_ph2 <= 0;
	end
	else begin
		cyc <= !div[1:0];
		if (div[1] & ~div[0]) begin
			cpu_ph1 <= 0;
			cpu_ph2 <= 0;
			case (div[3:2])
				0: cpu_ph2 <= 1;
				2: cpu_ph1 <= 1;
			endcase
		end
	end

//	ram_cs <= ~(ram_ready & cyc & cpu_type) & ram_sel;
end
`endif

wire  [1:0] cpu_state;
wire        cpu_nrst_out;
wire  [3:0] cpu_cacr;
wire [31:0] cpu_nmi_addr;

wire	  cpu_rst = !reset;
   
wire  [2:0] chip_ipl;
wire        chip_dtack;
wire        chip_as;
wire        chip_uds;
wire        chip_lds;
wire        chip_rw;
wire [15:0] chip_dout;
wire [15:0] chip_din;
wire [23:1] chip_addr;

wire [28:1] ram_addr;   
wire	    ram_sel;
wire	    ram_lds;
wire	    ram_uds;
wire [15:0] ram_din;
wire [15:0] ram_dout;
//TH wire [15:0] ram_dout  = zram_sel ? ram_dout2  : ram_dout1;
//TH wire        ram_ready = zram_sel ? ram_ready2 : ram_ready1;
//TH wire        zram_sel  = |ram_addr[28:26];
wire        ramshared;

cpu_wrapper cpu_wrapper
(
	.reset        (cpu_rst         ),
	.reset_out    (cpu_nrst_out    ),

	.clk          (clk_sys         ),
	.ph1          (cpu_ph1         ),
	.ph2          (cpu_ph2         ),

	.chip_addr    (chip_addr       ),
	.chip_dout    (chip_dout       ),
	.chip_din     (chip_din        ),
	.chip_as      (chip_as         ),
	.chip_uds     (chip_uds        ),
	.chip_lds     (chip_lds        ),
	.chip_rw      (chip_rw         ),
	.chip_dtack   (chip_dtack      ),
	.chip_ipl     (chip_ipl        ),

	.fastchip_dout   (  ),
	.fastchip_sel    (  ),
	.fastchip_lds    (  ),
	.fastchip_uds    (  ),
	.fastchip_rnw    (  ),
	.fastchip_selack (  ),
	.fastchip_ready  (  ),
	.fastchip_lw     (  ),

	.cpucfg       (cpucfg          ),
	.cachecfg     (cachecfg        ),
	.fastramcfg   (3'd0            ),
	.bootrom      (bootrom         ),

	.ramsel       (ram_sel         ),
	.ramaddr      (ram_addr        ),
	.ramlds       (ram_lds         ),
	.ramuds       (ram_uds         ),
	.ramdout      (ram_dout        ),
	.ramdin       (ram_din         ),
	.ramready     (/*TH ram_ready */      ),
	.ramshared    (ramshared       ),

	//custom CPU signals
	.cpustate     (cpu_state       ),
	.cacr         (cpu_cacr        ),
	.nmi_addr     (cpu_nmi_addr    )
);
   
///////////////////////////////////////////////////////////////////////

// apply blanking to video. May actually not be needed as the HDMI
// encoder does its own blanking. But it's nice for simulation
wire [7:0] red, green, blue;   
wire	   hbl, vbl;
wire [8:0] htotal;   
wire [3:0] r_in = (hbl||vbl)?4'h0:red[7:4];
wire [3:0] g_in = (hbl||vbl)?4'h0:green[7:4];
wire [3:0] b_in = (hbl||vbl)?4'h0:blue[7:4];   

wire [1:0] res;   
wire	   hs_in, vs_in;   

// JOY0 is actually the joystick port and and joy1 is being driven by usb mouse data
// JOY2 and JOY3 
wire [15:0] JOY0 = { 8'h0, joystick };   
wire [15:0] JOY1 = 16'h0000;
wire [15:0] JOY2 = 16'h0000;
wire [15:0] JOY3 = 16'h0000;   
   
minimig minimig
(
	//m68k pins
	.cpu_address  (chip_addr        ), // M68K address bus
	.cpu_data     (chip_dout        ), // M68K data bus
	.cpudata_in   (chip_din         ), // M68K data in
	._cpu_ipl     (chip_ipl         ), // M68K interrupt request
	._cpu_as      (chip_as          ), // M68K address strobe
	._cpu_uds     (chip_uds         ), // M68K upper data strobe
	._cpu_lds     (chip_lds         ), // M68K lower data strobe
	.cpu_r_w      (chip_rw          ), // M68K read / write
	._cpu_dtack   (chip_dtack       ), // M68K data acknowledge
	._cpu_reset   (/*cpu_rst */     ), // M68K reset
	._cpu_reset_in(cpu_nrst_out     ), // M68K reset out
	.nmi_addr     (cpu_nmi_addr     ), // M68K NMI address

        .memory_config (memory_config   ), // ram sizes
        .chipset_config(chipset_config  ), 
        .floppy_config (floppy_config   ), 

	//sram pins
	.ram_data     (ram_data         ), // SRAM data bus
	.ramdata_in   (ramdata_in       ), // SRAM data bus in
	.ram_address  (ram_address      ), // SRAM address bus
	._ram_bhe     (_ram_bhe         ), // SRAM upper byte select
	._ram_ble     (_ram_ble         ), // SRAM lower byte select
	._ram_we      (_ram_we          ), // SRAM write enable
	._ram_oe      (_ram_oe          ), // SRAM output enable
	.chip48       (chip48           ), // big chipram read

	//system  pins
	.rst_ext      (reset_d          ), // reset from ctrl block
	.rst_out      (                 ), // minimig reset status
	.clk          (clk_sys          ), // output clock c1 ( 28.687500MHz)
	.clk7_en      (clk7_en          ), // 7MHz clock enable
	.clk7n_en     (clk7n_en         ), // 7MHz negedge clock enable
	.c1           (c1               ), // clk28m clock domain signal synchronous with clk signal
	.c3           (c3               ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
	.cck          (cck              ), // colour clock output (3.54 MHz)
	.eclk         (eclk             ), // 0.709379 MHz clock enable output (clk domain pulse)

	//rs232 pins
	.rxd          (uart_rx          ), // RS232 receive
	.txd          (uart_tx          ), // RS232 send
	.cts          (uart_cts         ), // RS232 clear to send
	.rts          (uart_rts         ), // RS232 request to send
	.dtr          (uart_dtr         ), // RS232 Data Terminal Ready
	.dsr          (uart_dsr         ), // RS232 Data Set Ready
	.cd           (uart_dsr         ), // RS232 Carrier Detect
	.ri           (1                ), // RS232 Ring Indicator

	//I/O
	._joy1        (~JOY0            ), // joystick 1 [fire4,fire3,fire2,fire,up,down,left,right] (default mouse port)
	._joy2        (~JOY1            ), // joystick 2 [fire4,fire3,fire2,fire,up,down,left,right] (default joystick port)
	._joy3        (~JOY2            ), // joystick 3 [fire4,fire3,fire2,fire,up,down,left,right]
	._joy4        (~JOY3            ), // joystick 4 [fire4,fire3,fire2,fire,up,down,left,right]
	.joya1        (JOYA0            ),
	.joya2        (JOYA1            ),
	.mouse_btn    (mouse_buttons    ), // mouse buttons
	.kbd_mouse_data (kbd_mouse_data ), // mouse direction data, keycodes
	.kbd_mouse_type (kbd_mouse_type ), // type of data
	.kms_level    (kbd_mouse_level  ),
	.pwr_led      (pwr_led          ), // power led
	.fdd_led      (fdd_led          ),
	.hdd_led      (                 ),
	.rtc          (RTC              ),

	//host controller interface (SPI)
	.IO_UIO       (io_uio           ),
	.IO_FPGA      (io_fpga          ),
	.IO_STROBE    (io_strobe        ),
	.IO_WAIT      (io_wait          ),
	.IO_DIN       (io_din           ),
	.IO_DOUT      (fpga_dout        ),

	//video
	._hsync       (hs_in            ), // horizontal sync
	._vsync       (vs_in            ), // vertical sync
	.field1       (field1           ),
	.lace         (lace             ),
	.red          (red              ), // red
	.green        (green            ), // green
	.blue         (blue             ), // blue
	.hblank       (hbl              ),
	.vblank       (vbl              ),
	.ar           (                 ),
	.scanline     (fx               ),
	//.ce_pix     (ce_pix           ),
	.res          (res              ),
        .htotal       (htotal           ),

	//audio
	.ldata        (audio_left       ), // left DAC data
	.rdata        (audio_right      ), // right DAC data
	.ldata_okk    (                 ), // 9bit
	.rdata_okk    (                 ), // 9bit

	.aud_mix      (                 ),

	//user i/o
	.cpucfg       ( ), // CPU config
	.cachecfg     ( ), // Cache config
	.memcfg       ( ), // memory config
	.bootrom      ( ), // bootrom mode. Needed here to tell tg68k to also mirror the 256k Kickstart 

        // sd card interface for floppy disk emulation
        .sdc_img_mounted    ( sdc_img_mounted     ),
        .sdc_img_size       ( sdc_img_size        ),  // length of image file
        .sdc_rd             ( sdc_rd              ),
        .sdc_sector         ( sdc_sector          ),
        .sdc_busy           ( sdc_busy            ),
        .sdc_done           ( sdc_done            ),
	.sdc_byte_in_strobe ( sdc_byte_in_strobe  ),
	.sdc_byte_in_addr   ( sdc_byte_in_addr    ),
	.sdc_byte_in_data   ( sdc_byte_in_data    ),
 
	.ide_fast     (                 ),
	.ide_ext_irq  ( 1'b0            ),
	.ide_ena      (                 ),
	.ide_req      (                 ),
	.ide_address  ( 5'd0            ),
	.ide_write    ( 1'b0            ),
	.ide_writedata( 16'h0000        ),
	.ide_read     ( 1'b0            ),
	.ide_readdata (                 )
);

Amber AMBER
(
	.clk28m(clk_sys),
	.lr_filter(video_config[3:2]),	//interpolation filters settings for low resolution
	.hr_filter(video_config[3:2]),	//interpolation filters settings for high resolution
	.scanline(video_config[1:0]),	//scanline effect enable
	.htotal(htotal[8:1]),		//video line length
	.hires(res[0]),			//display is in hires mode (from bplcon0)
	.dblscan(1'b1),			//enable VGA output (enable scandoubler)
	.red_in(r_in), 			//red componenent video in
	.green_in(g_in),  		//green component video in
	.blue_in(b_in),			//blue component video in
	._hsync_in(hs_in),		//horizontal synchronisation in
	._vsync_in(vs_in),		//vertical synchronisation in
	._csync_in(1'b1),		//composite synchronization in, only used if dblscan==0
	.red_out(r), 		        //red componenent video out
	.green_out(g),  	        //green component video out
	.blue_out(b),		        //blue component video out
	._hsync_out(hs),		//horizontal synchronisation out
	._vsync_out(vs)			//vertical synchronisation out
 );
    
endmodule
