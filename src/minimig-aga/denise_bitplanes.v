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
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//
//
// This is the bitplane part of denise
// It accepts data from the bus and converts it to serial video data (6 bits).
// It supports all ocs modes and also handles the pf1<->pf2 priority handling in
// a seperate module.


module denise_bitplanes
(
  input   clk,             // system bus clock
  input   clk7_en,
  input   reset,
  input   c1,            // 35ns clock enable signals (for synchronization with clk)
  input   c3,
  input   aga,
  input   [8:1] reg_address_in,   // register address
  input   [15:0] data_in,       // bus data in
  input   [48-1:0] chip48,  // big chipram read
  input   hires,             // high resolution mode select
  input   shres,             // super high resolution mode select
  input  [8:0] hpos,        // horizontal position (70ns resolution)
  output   [8:1] bpldata      // bitplane data out
);


//register names and adresses
parameter BPLCON1 = 9'h102;
parameter BPL1DAT = 9'h110;
parameter BPL2DAT = 9'h112;
parameter BPL3DAT = 9'h114;
parameter BPL4DAT = 9'h116;
parameter BPL5DAT = 9'h118;
parameter BPL6DAT = 9'h11a;
parameter BPL7DAT = 9'h11c;
parameter BPL8DAT = 9'h11e;
parameter FMODE   = 9'h1fc;

//local signals
reg   [15:0] bplcon1;    // bplcon1 register
reg   [15:0] fmode;     // fmod reg
reg    [63:0] bpl1dat;    // buffer register for bit plane 2
reg    [63:0] bpl2dat;    // buffer register for bit plane 2
reg    [63:0] bpl3dat;    // buffer register for bit plane 3
reg    [63:0] bpl4dat;    // buffer register for bit plane 4
reg    [63:0] bpl5dat;    // buffer register for bit plane 5
reg    [63:0] bpl6dat;    // buffer register for bit plane 6
reg    [63:0] bpl7dat;    // buffer register for bit plane 5
reg    [63:0] bpl8dat;    // buffer register for bit plane 6
reg    load;        // bpl1dat written => load shif registers

reg    [7:0] extra_delay_f0;  // extra delay when not alligned ddfstart
reg    [7:0] extra_delay_f12;
reg    [7:0] extra_delay_f3;
reg    [7:0] extra_delay_r;
reg    [7:0] pf1h;      // playfield 1 horizontal scroll
reg    [7:0] pf2h;      // playfield 2 horizontal scroll
reg    [7:0] pf1h_del;    // delayed playfield 1 horizontal scroll
reg    [7:0] pf2h_del;    // delayed playfield 2 horizontal scroll

//--------------------------------------------------------------------------------------

// horizontal scroll depends on horizontal position when BPL0DAT in written
// visible display scroll is updated on fetch boundaries
// increasing scroll value during active display inserts blank pixels

always @(hpos)
  case (hpos[3:2])
    2'b00 : extra_delay_f0 = 8'b00_0000_00;
    2'b01 : extra_delay_f0 = 8'b00_1100_00;
    2'b10 : extra_delay_f0 = 8'b00_1000_00;
    2'b11 : extra_delay_f0 = 8'b00_0100_00;
  endcase

always @(hpos)
  case (hpos[4:3])
    2'b00 : extra_delay_f12 = 8'b00_0000_00;
    2'b01 : extra_delay_f12 = 8'b01_1000_00;
    2'b10 : extra_delay_f12 = 8'b01_0000_00;
    2'b11 : extra_delay_f12 = 8'b00_1000_00;
  endcase

always @(hpos)
  case (hpos[5:4])
    2'b00 : extra_delay_f3 = 8'b00_0000_00;
    2'b01 : extra_delay_f3 = 8'b11_0000_00;
    2'b10 : extra_delay_f3 = 8'b10_0000_00;
    2'b11 : extra_delay_f3 = 8'b01_0000_00;
  endcase

always @ (posedge clk) begin
  if (clk7_en) begin
    if (load) extra_delay_r <= #1 (fmode[1:0] == 2'b00) ? extra_delay_f0 : (fmode[1:0] == 2'b11) ? extra_delay_f3 : extra_delay_f12;
  end
end

//playfield 1 effective horizontal scroll
always @(posedge clk)
  if (clk7_en) begin
    if (load)
      pf1h <= {bplcon1[11:10],bplcon1[3:0],bplcon1[9:8]};
  end

always @(posedge clk)
  if (clk7_en) begin
    pf1h_del <= pf1h + extra_delay_r;
  end

//playfield 2 effective horizontal scroll
always @(posedge clk)
  if (clk7_en) begin
    if (load)
      pf2h <= {bplcon1[15:14],bplcon1[7:4],bplcon1[13:12]};
  end

always @(posedge clk)
  if (clk7_en) begin
    pf2h_del <= pf2h + extra_delay_r;
  end

//writing bplcon1 register : horizontal scroll codes for even and odd bitplanes
always @(posedge clk)
  if (clk7_en) begin
    if (reset)
      bplcon1 <= #1 16'h3300;
    if ((reg_address_in[8:1] == BPLCON1[8:1]))
      bplcon1 <= #1 aga ? data_in[15:0] : {2'b00,2'b11,2'b00,2'b11,data_in[7:0]};
  end

// fmode
always @ (posedge clk) begin
  if (clk7_en) begin
    if (reset)
      fmode <= #1 16'h0000;
    else if (aga && (reg_address_in[8:1] == FMODE[8:1]))
      fmode <= #1 data_in;
  end
end

reg [47:0] chip48_fmode=0;
always @ (*) begin
  case (fmode[1:0])
    2'b11   : chip48_fmode[47:0] = chip48[47:0];
    2'b10,
    2'b01   : chip48_fmode[47:0] = {chip48[47:32], 32'h00000000};
    default : chip48_fmode[47:0] = 48'h000000000000;
  endcase
end


//--------------------------------------------------------------------------------------

wire clk7n_en = c1 & c3;

reg [15:0] data16;
always @(posedge clk) if (clk7_en) data16 <= data_in;

//bitplane buffer register for plane 1
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL1DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl1dat <= {data16,chip48_fmode};
	end
end

//bitplane buffer register for plane 2
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL2DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl2dat <= {data16,chip48_fmode};
	end
end

//bitplane buffer register for plane 3
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL3DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl3dat <= {data16,chip48_fmode};
	end
end

//bitplane buffer register for plane 4
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL4DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl4dat <= {data16,chip48_fmode};
	end
end

//bitplane buffer register for plane 5
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL5DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl5dat <= {data16,chip48_fmode};
	end
end

//bitplane buffer register for plane 6
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL6DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl6dat <= {data16,chip48_fmode};
	end
end

//bitplane buffer register for plane 7
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL7DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl7dat <= {data16,chip48_fmode};
	end
end

//bitplane buffer register for plane 8
always @(posedge clk) begin
	reg st;
	if(clk7_en && reg_address_in[8:1] == BPL8DAT[8:1]) st <= 1;
	if(st & clk7n_en) begin
		st <= 0;
		bpl8dat <= {data16,chip48_fmode};
	end
end

//generate load signal when plane 1 is written
always @(posedge clk) if (clk7_en) load <= reg_address_in[8:1] == BPL1DAT[8:1];

//--------------------------------------------------------------------------------------

//instantiate bitplane 1 parallel to serial converters, this plane is loaded directly from bus
denise_bitplane_shifter bplshft1
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl1dat),
  .scroll(pf1h_del),
  .out(bpldata[1])
);

//instantiate bitplane 2 to 6 parallel to serial converters, (loaded from buffer registers)
denise_bitplane_shifter bplshft2
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl2dat),
  .scroll(pf2h_del),
  .out(bpldata[2])
);

denise_bitplane_shifter bplshft3
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl3dat),
  .scroll(pf1h_del),
  .out(bpldata[3])
);

denise_bitplane_shifter bplshft4
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl4dat),
  .scroll(pf2h_del),
  .out(bpldata[4])
);

denise_bitplane_shifter bplshft5
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl5dat),
  .scroll(pf1h_del),
  .out(bpldata[5])
);

denise_bitplane_shifter bplshft6
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl6dat),
  .scroll(pf2h_del),
  .out(bpldata[6])
);

denise_bitplane_shifter bplshft7
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl7dat),
  .scroll(pf1h_del),
  .out(bpldata[7])
);

denise_bitplane_shifter bplshft8
(
  .clk(clk),
  .clk7_en(clk7_en),
  .c1(c1),
  .c3(c3),
  .load(load),
  .hires(hires),
  .shres(shres),
  .fmode(fmode[1:0]),
  .aga(aga),
  .data_in(bpl8dat),
  .scroll(pf2h_del),
  .out(bpldata[8])
);


endmodule

