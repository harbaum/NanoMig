// nanomig simulation top

module nanomig_tb
  (
   input	 clk, // 28mhz
   output	 clk_7m, 
   output	 clk7_en,
   output	 clk7n_en,
   input	 reset,

   // serial output, mainly for diagrom
   output	 uart_tx,

   // signal to e.g. trigger on disk activity
   output	 pwr_led,
   output	 fdd_led,
   input	 trigger, 
   
   input [5:0]    chipset_config,
   
   // video
   output	 hs_n,
   output	 vs_n,
   output [3:0]	 red,
   output [3:0]	 green,
   output [3:0]	 blue,

   input [3:0]	 sdc_img_mounted,
   input [31:0]	 sdc_img_size,

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
`endif // !`ifdef SD_EMU
   
   // external ram/rom interface
   output [15:0] ram_data, // sram data bus
   input [15:0]	 ramdata_in, // sram data bus in
   output [23:1] ram_address, // sram address bus
   output	 _ram_bhe, // sram upper byte select
   output	 _ram_ble, // sram lower byte select
   output	 _ram_we, // sram write enable
   output	 _ram_oe      // sram output enable
   );
   
`ifdef SD_EMU
// for floppy IO the SD card itself may be included into the simulation or not
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
    .clk(clk),                     // clock

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
`endif //  `ifdef SD_EMU
   
nanomig nanomig (
		 // system pins
		 .clk_sys(clk),   // 28.37516 MHz clock
		 .reset(reset),
		 .clk7_en(clk7_en),
		 .clk7n_en(clk7n_en),

		 .pwr_led(pwr_led),
		 .fdd_led(fdd_led),

		 .chipset_config(chipset_config),

		 .hs(hs_n),
		 .vs(vs_n),
		 .r(red),
		 .g(green),
		 .b(blue),

		 .joystick(6'b010101),
		 
		 // sd card interface for floppy disk emulation
		 .sdc_img_mounted    ( sdc_img_mounted     ),
		 .sdc_img_size       ( sdc_img_size        ),  // length of image file		 
		 .sdc_rd(sdc_rd),
		 .sdc_sector(sdc_sector),
		 .sdc_busy(sdc_busy),
		 .sdc_done(sdc_done),
		 .sdc_byte_in_strobe(sdc_byte_in_strobe),
		 .sdc_byte_in_addr(sdc_byte_in_addr),
		 .sdc_byte_in_data(sdc_byte_in_data),
		 
		 .uart_tx(uart_tx),
		 
		 // (s(d))ram interface
		 .ram_data(ram_data),       // sram data bus
		 .ramdata_in(ramdata_in),   // sram data bus in
		 .chip48(48'h0),            // big chip read, needed for AGA only
		 .ram_address(ram_address), // sram address bus
		 ._ram_bhe(_ram_bhe),       // sram upper byte select
		 ._ram_ble(_ram_ble),       // sram lower byte select
		 ._ram_we(_ram_we),         // sram write enable
		 ._ram_oe(_ram_oe)          // sram output enable
		 );
   
endmodule
