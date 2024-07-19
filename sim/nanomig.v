// nanomig simulation top

// `define INTERNAL_MEM
// `define SD_EMU     // this is defined in the Makefile (or not)

module nanomig
  (
   input	 clk, // 28mhz
   output	 clk_7m, 
   input	 reset,

   // serial output, mainly for diagrom
   output	 uart_tx,

   // signal to e.g. trigger on disk activity
   output	 power_led,
   output	 floppy_led,

   // video
   output	 hs_n,
   output	 vs_n,
   output [3:0]	 red,
   output [3:0]	 green,
   output [3:0]	 blue,

   input [3:0]   sdc_img_mounted,
   input [31:0]  sdc_img_size,
   
`ifdef SD_EMU   
   output	 sdclk,
   output	 sdcmd,
   input	 sdcmd_in,
   output [3:0]	 sddat,
   input [3:0]	 sddat_in,
`else
   output [3:0]	 sdc_rd,
   output [31:0] sdc_sector,
   input	 sdc_busy,
   input	 sdc_done,
   input	 sdc_byte_in_strobe,
   input [8:0]	 sdc_byte_in_addr,
   input [7:0]	 sdc_byte_in_data,
`endif

   input	 trigger,
   
   // external ram/rom interface
   output [18:1] ram_a,
`ifdef INTERNAL_MEM
   output [15:0] ram_din,
`else
   input [15:0]	 ram_din,
`endif
   output [15:0] ram_dout,
   output [7:0]	 ram_bank, // 8 banks of 512k each
   output	 ram_we,
   output [1:0]	 ram_be,
   output	 ram_oe
   );

`ifdef SD_EMU
wire [3:0]	 sdc_rd;
wire [31:0]	 sdc_sector;
wire		 sdc_busy;
wire		 sdc_done;
wire		 sdc_byte_in_strobe;
wire [8:0]	 sdc_byte_in_addr;
wire [7:0]	 sdc_byte_in_data;

sd_rw #(
    .CLK_DIV(3'd0),                // for 28 Mhz clock
    .SIMULATE(1'b1)
) sd_card (
    .rstn(!reset),                 // rstn active-low, 1:working, 0:reset
    .clk(clk_28m),                 // clock

    // SD card signals
    .sdclk(sdclk),
    .sdcmd(sdcmd),
    .sdcmd_in(sdcmd_in),
    .sddat(sddat),
    .sddat_in(sddat_in),

    // user read sector command interface (sync with clk)
    .rstart(sdc_rd), 
    .wstart(4'b0000), 
    .sector(sdc_sector),
    .rbusy(sdc_busy),
    .rdone(sdc_done),
                 
    // sector data output interface (sync with clk)
    .inbyte(),
    .outen(sdc_byte_in_strobe),  // when outen=1, a byte of sector content is read out from outbyte
    .outaddr(sdc_byte_in_addr),  // outaddr from 0 to 511, because the sector size is 512
    .outbyte(sdc_byte_in_data)   // a byte of sector content
);
`endif
  
/* --------------------------- test rom/ram -------------------------- */
`ifdef INTERNAL_MEM
   reg [15:0] 	 rom[0:1023];
   reg [15:0] 	 ram[0:1023];
   
   initial begin
      $readmemh ("../src/ram_test/ram_test.hex", rom, 0);
   end
   
   // memory io stats oen cycle after start of 7mhz rising edge
   reg [15:0] mem_dout;
   always @(posedge clk_28m)
     mem_dout <= 
		 (ram_bank==8)?rom[ram_a[10:1]]:
		 (ram_bank==1)?ram[ram_a[10:1]]:
		 16'h0000;
   
   // ram write happens in the middle of the 7Mhz cycle
   always @(negedge clk_7m)
     if(ram_bank == 1 && !ram_we && ram_a[18:11]==8'h00)
       ram[ram_a[10:1]] <= ram_dout;
   
   // map internal memory to first 2k of kickstart/chipram space
   // address lines 18:1 are valid with each 512k block
   assign ram_din = (!ram_oe && ram_a[18:11]==8'h00)?mem_dout:
		    16'h0000;
`endif
   
   // generate 7 Mhz from 28Mhz
   reg [1:0]  clk_cnt;
   always @(posedge clk)
     clk_cnt <= clk_cnt + 2'd1;
   
   assign     clk_7m = clk_cnt[1];
   wire       clk_28m = clk; 
   
   wire [23:1] cpu_a;
   wire        cpu_as_n, cpu_lds_n, cpu_uds_n;
   wire        cpu_rw, cpu_dtack_n;
   wire [2:0]  ipl_n;
   wire [15:0] cpu_din, cpu_dout;   
   
   // instanciate Minimig
 Minimig1 MINIMIG1 (
    // m68k pins
   .cpu_address(cpu_a),       // m68k address bus
   .cpu_data(cpu_din),        // m68k data bus
   .cpu_wrdata(cpu_dout),     // m68k data bus
   .n_cpu_ipl(ipl_n),         // m68k interrupt request
   .n_cpu_as(cpu_as_n),       // m68k address strobe
   .n_cpu_uds(cpu_uds_n),     // m68k upper data strobe
   .n_cpu_lds(cpu_lds_n),     // m68k lower data strobe
   .cpu_r_w(cpu_rw),          // m68k read / write
   .n_cpu_dtack(cpu_dtack_n), // m68k data acknowledge
   
   // sram pins
   .ram_data(ram_dout),       // sram data bus
   .ram_address_out(ram_a),   // sram address bus
   .ramdata_in(ram_din),      // sram data bus in
   .bank(ram_bank),           // 8 banks of 512k each
   .n_ram_bhe(ram_be[0]),     // sram upper byte select
   .n_ram_ble(ram_be[1]),     // sram lower byte select
   .n_ram_we(ram_we),         // sram write enable
   .n_ram_oe(ram_oe),         // sram output enable

   // system pins
   .clk(clk_7m),      // system clock (7.09379 MHz)
   .clk28m(clk_28m),  // 28.37516 MHz clock

   .chipset_config(3'b100), // ecs, a500 (!a1k), pal
		    
   // rs232 pins
   .rxd(1'b1),     // rs232 receive
   .txd(uart_tx),  // rs232 send
   .cts(1'b1),     // rs232 clear to send
   .rts(),         // rs232 request to send
   
   // I/O
   .n_joy1(6'h3f), // joystick 1 [fire2,fire,right,left,down,up] (default mouse port)
   .n_joy2(6'h3f), // joystick 2 [fire2,fire,right,left,down,up] (default joystick port)
   .n_15khz(1'b1), // scandoubler disable
   .pwrled(power_led),      // power led
   
   // sd card interface for floppy disk emulation
   .sdc_img_mounted(sdc_img_mounted),
   .sdc_img_size(sdc_img_size),
   .sdc_rd(sdc_rd),
   .sdc_sector(sdc_sector),
   .sdc_busy(sdc_busy),
   .sdc_done(sdc_done),
   .sdc_byte_in_strobe(sdc_byte_in_strobe),
   .sdc_byte_in_addr(sdc_byte_in_addr),
   .sdc_byte_in_data(sdc_byte_in_data),
		    
   // video
   .n_hsync(hs_n),     // horizontal sync
   .n_vsync(vs_n),     // vertical sync
   .red(red),          // red
   .green(green),      // green
   .blue(blue),        // blue
   
   // audio
   .aud_l(),       // audio bitstream left
   .aud_r(),       // audio bitstream right
		    
   // user i/o
   .floppy_config({2'd1, 1'b0}),  // enable one floppy
   .floppyled(floppy_led),
   
   // unused pins
   .cpurst(reset),
   .n_joy3(5'h1f),  // joystick 3 [fire2,fire,right,left,down,up] (joystick port)
   .n_joy4(5'h1f)   // joystick 4 [fire2,fire,right,left,down,up] (joystick port)
   );

   video_analyzer video_analyzer(
	 .clk(clk_28m),
	 .hs(hs_n),
	 .vs(vs_n),
	 .pal(),
         .vreset()				 
   );

   reg	phi1, phi2;   
   
   always @(posedge clk_28m) begin
      phi1 <= 0;
      phi2 <= 0;
      // standard
      if(clk_cnt[0] &&  clk_cnt[1]) phi1 <= 1;   
      if(clk_cnt[0] && ~clk_cnt[1]) phi2 <= 1;
      // also works in simulation, doesn't affect blitter issues
//      if(~clk_cnt[0] && ~clk_cnt[1]) phi1 <= 1;   
//      if(~clk_cnt[0] &&  clk_cnt[1]) phi2 <= 1;   
   end

   // connect Minimig1 to fx68k
   fx68k fx68k (
	.clk        ( clk_28m     ),
        .extReset   ( reset       ),
        .pwrUp      ( reset       ),
        .enPhi1     ( phi1        ),
        .enPhi2     ( phi2        ),

        .eRWn       ( cpu_rw      ),
        .ASn        ( cpu_as_n    ),
        .LDSn       ( cpu_lds_n   ),
        .UDSn       ( cpu_uds_n   ),
        .E          (             ),
        .VMAn       (             ),
        .FC0        (             ),
        .FC1        (             ),
        .FC2        (             ),
        .BGn        (             ),
        .oRESETn    (             ),
        .oHALTEDn   (             ),
        .DTACKn     ( cpu_dtack_n ),
        .VPAn       ( 1'b1        ),
        .BERRn      ( 1'b1        ),
`ifndef VERILATOR
        .HALTn      ( 1'b1        ),
`endif
        .BRn        ( 1'b1        ),
        .BGACKn     ( 1'b1        ),
        .IPL0n      ( ipl_n[0]    ),
        .IPL1n      ( ipl_n[1]    ),
        .IPL2n      ( ipl_n[2]    ),
        .iEdb       ( cpu_din     ),
        .oEdb       ( cpu_dout    ),
        .eab        ( cpu_a       )
);

   
endmodule
