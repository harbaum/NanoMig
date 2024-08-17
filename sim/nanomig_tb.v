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
   input         trigger,	 
   
   // video
   output	 hs_n,
   output	 vs_n,
   output [3:0]	 red,
   output [3:0]	 green,
   output [3:0]	 blue,

   input [3:0]	 sdc_img_mounted,
   input [31:0]	 sdc_img_size,
   output [3:0]	 sdc_rd,
   output [31:0] sdc_sector,
   input	 sdc_busy,
   input	 sdc_done,
   input	 sdc_byte_in_strobe,
   input [8:0]	 sdc_byte_in_addr,
   input [7:0]	 sdc_byte_in_data,

   // external ram/rom interface
   output [15:0] ram_data, // sram data bus
   input [15:0]	 ramdata_in, // sram data bus in
   output [23:1] ram_address, // sram address bus
   output	 _ram_bhe, // sram upper byte select
   output	 _ram_ble, // sram lower byte select
   output	 _ram_we, // sram write enable
   output	 _ram_oe      // sram output enable
   );

nanomig nanomig (
		 // system pins
		 .clk_sys(clk),   // 28.37516 MHz clock
		 .reset(reset),
		 .clk7_en(clk7_en),
		 .clk7n_en(clk7n_en),

		 .pwr_led(pwr_led),
		 .fdd_led(fdd_led),

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
