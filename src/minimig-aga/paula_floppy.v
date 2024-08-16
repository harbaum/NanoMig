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
// This is the floppy disk controller (part of Paula)
//
// 23-10-2005	-started coding
// 24-10-2005	-done lots of work
// 13-11-2005	-modified fifo to use block ram
//				-done lots of work
// 14-11-2005	-done more work
// 19-11-2005	-added wordsync logic
// 20-11-2005	-finished core floppy disk interface
//				-added disk interrupts
//				-added floppy control signal emulation
// 21-11-2005	-cleaned up code a bit
// 27-11-2005	-den and sden are now active low (_den and _sden)
//				-fixed bug in parallel/serial converter
//				-fixed more bugs
// 02-12-2005	-removed dma abort function
// 04-12-2005	-fixed bug in fifo empty signalling
// 09-12-2005	-fixed dsksync handling	
//				-added protection against stepping beyond track limits
// 10-12-2005	-fixed some more bugs
// 11-12-2005	-added dout output enable to allow SPI bus multiplexing
// 12-12-2005	-fixed major bug, due error in statemachine, multiple interrupts were requested
//				 after a DMA transfer, this could lock up the whole machine
// 				-enable line disconnected  --> this module still needs a lot of work
// 27-12-2005	-cleaned up code, this is it for now
// 07-01-2005	-added dmas
// 15-01-2006	-added support for track 80-127 (used for loading kickstart)
// 22-01-2006	-removed support for track 80-127 again
// 06-02-2006	-added user disk control input
// 28-12-2006	-spi data out is now low when not addressed to allow multiplexing with multiple spi devices		
//
// JB:
// 2008-07-17	- modified floppy interface for better read handling and write support
//				- spi interface clocked by SPI clock
// 2008-09-24	- incompatibility found: _READY signal should respond to _SELx even when the motor is off
//				- added logic for four floppy drives
// 2008-10-07	- ide command request implementation
// 2008-10-28	- further hdd implementation
// 2009-04-05	- code clean-up
// 2009-05-24	- clean-up & renaming
// 2009-07-21	- WORDEQUAL in DSKBYTR register is always set now
// 2009-11-14 - changed DSKSYNC reset value (Kick 1.3 doesn't initialize this register after reset)
//        - reduced FIFO size (to save some block rams)
// 2009-12-26 - step enable
// 2010-04-12 - implemented work-around for dsksync interrupt request
// 2010-08-14 - set BYTEREADY of DSKBYTR (required by Kick Off 2 loader)

module paula_floppy
(
	// system bus interface
	input         clk,		    	// bus clock
	input         clk7_en,
	input         clk7n_en,
	input         reset,			   // reset 
	input         ntsc,         	// ntsc mode
	input         sof,          	// start of frame
	input	        enable,			// dma enable
	input   [8:1] reg_address_in,	// register address inputs
	input  [15:0] data_in,			// bus data in
	output [15:0] data_out,			// bus data out
	output        dmal,				// dma request output
	output        dmas,				// dma special output

	//disk control signals from cia and user
	input	        _step,				// step heads of disk
	input	        direc,				// step heads direction
	input   [3:0] _sel,				// disk select 	
	input	        side,				// upper/lower disk head
	input	        _motor,			// disk motor control
	output        _track0,			// track zero detect
	output        _change,			// disk has been removed from drive
	output        _ready,			// disk is ready
	output        _wprot,			// disk is write-protected
	output        index,          // disk index pulse

	//interrupt request and misc. control
	output reg    blckint,			// disk dma has finished interrupt
	output        syncint,			// disk syncword found
	input         wordsync,			// wordsync enable

	//HPS I/O interface
	input         IO_ENA,
	input         IO_STROBE,
	output reg    IO_WAIT,
	input  [15:0] IO_DIN,
	output reg [15:0] IO_DOUT,

	output        fdd_led,			//disk activity LED, active when DMA is on
	input	[1:0]   floppy_drives,	//floppy drive number

	// fifo / track display
	output  [7:0] trackdisp,
	output [13:0] secdisp,
	output        floppy_fwr,
	output        floppy_frd
);

//register names and addresses
parameter DSKBYTR = 9'h01a;
parameter DSKDAT  = 9'h026;		
parameter DSKDATR = 9'h008;
parameter DSKSYNC = 9'h07e;
parameter DSKLEN  = 9'h024;

//local signals
reg  [15:0] dsksync;			//disk sync register
reg  [15:0] dsklen;			//disk dma length, direction and enable 
reg   [6:0] dsktrack[3:0];	//track select
wire  [7:0] track;

reg         dmaon;			//disk dma read/write enabled
wire        lenzero;			//disk length counter is zero
reg         trackwr;			//write track (command to host)
reg         trackrd;			//read track (command to host)

wire        _dsktrack0;		//disk heads are over track 0
wire        dsktrack79;    //disk heads are over track 0

wire [15:0] fifo_in;			//fifo data in
wire [15:0] fifo_out; 		//fifo data out
wire        fifo_wr;			//fifo write enable
reg         fifo_wr_del;	//fifo write enable delayed
wire        fifo_rd;			//fifo read enable
wire        fifo_empty;		//fifo is empty
wire        fifo_full;		//fifo is full
wire [11:0] fifo_cnt;

wire [15:0] dskbytr;			
wire [15:0] dskdatr;

// JB:
wire        fifo_reset;
reg         dmaen;			//dsklen dma enable
reg  [15:0] wr_fifo_status;

reg   [3:0] disk_present;	//disk present status
reg   [3:0] disk_writable;	//disk write access status

wire        _selx;			//active whenever any drive is selected
wire  [1:0] sel;				//selected drive number

reg   [1:0] drives;			//number of currently connected floppy drives (1-4)

reg   [3:0] _disk_change;
reg         _step_del;
reg   [8:0] step_ena_cnt;
wire        step_ena;

// drive motor control
reg  [3:0] _sel_del;       // deleyed drive select signals for edge detection
reg  [3:0] motor_on;       // drive motor on

//decoded commands
reg        cmd_fdd;			//HPS accesses floppy drive buffer

assign     trackdisp = track;
assign     secdisp = dsklen[13:0];

assign     floppy_fwr = fifo_wr;
assign     floppy_frd = fifo_rd;

reg  [1:0] cmd_cnt;

reg stb7;
always @(posedge clk or negedge IO_ENA) begin
	if(~IO_ENA) {IO_WAIT,stb7} <= 0;
	else begin
		if(IO_STROBE) begin
			IO_WAIT <= 1;
		end
		if(clk7_en & IO_WAIT) begin
			if(~stb7) begin
				rx_data <=IO_DIN;
				stb7    <=1;
			end
			if(stb7) begin
				stb7    <=0;
				IO_WAIT <=0;
				IO_DOUT <=tx_data;
			end
		end
	end
end

reg [15:0] rx_data;	//received data from HPS
reg [15:0] tx_data;	//data to be send to HPS

always @(posedge clk or negedge IO_ENA) begin
	if (~IO_ENA) cmd_cnt <= 0;
	else if (clk7_en & stb7 & ~&cmd_cnt) cmd_cnt <= cmd_cnt + 1'd1;
end

//---------------------------------------------------------------------------------------------------------------------

always @(posedge clk) begin
	if (clk7_en) begin
		if (reset | ~IO_ENA)       cmd_fdd <= 0;
		else if (stb7 && !cmd_cnt) cmd_fdd <= (rx_data[15:13]==3'b000 );
	end
end


//transmit data multiplexer
always @(*) begin
	casex ({cmd_cnt, cmd_fdd, trackrd, trackwr})
		
		// fdd request status
		'b00xxx: tx_data = {sel[1:0],drives[1:0],2'b00,trackwr,trackrd&~fifo_cnt[10],track[7:0]};

		// fdd data
		'b01xxx: tx_data = dsksync[15:0];
		'b10x1x: tx_data = {dmaen,dsklen[14:0]};
		'b10x01: tx_data = wr_fifo_status;
		'b1111x: tx_data = {dmaen,dsklen[14:0]};
		'b11101: tx_data = fifo_out;
		
		// no data
		 default: tx_data = 0;
	endcase
end

//floppy disk write fifo status is latched when transmision of the previous word begins 
//it guarantees that when latching the status data into transmit register setup and hold times are met
always @(posedge clk) begin
  if (clk7_en) begin
  	if (stb7)
  		wr_fifo_status <= {dmaen&dsklen[14],3'b000,fifo_cnt[11:0]};
  end
end

//-----------------------------------------------------------------------------------------------//
//active floppy drive number, updated during reset
always @(posedge clk) begin
  if (clk7_en) begin
  	if (reset)
  		drives <= floppy_drives;
  end
end

//-----------------------------------------------------------------------------------------------//
// 300 RPM floppy disk rotation signal
reg [3:0] rpm_pulse_cnt;
always @(posedge clk) begin
  if (clk7_en) begin
    if (sof) begin
      if (rpm_pulse_cnt==11 || !ntsc && rpm_pulse_cnt==9)
        rpm_pulse_cnt <= 0;
      else
        rpm_pulse_cnt <= rpm_pulse_cnt + 4'd1;
    end
  end
end
    
// disk index pulses output
assign index = |(~_sel & motor_on) & ~|rpm_pulse_cnt & sof;
	
//--------------------------------------------------------------------------------------
//data out multiplexer
assign data_out = dskbytr | dskdatr;

//--------------------------------------------------------------------------------------

//active whenever any drive is selected
assign _selx = &_sel[3:0];

// delayed step signal for detection of its rising edge 
always @(posedge clk) begin
  if (clk7_en) begin
    _step_del <= _step;
  end
end

always @(posedge clk) begin
  if (clk7_en) begin
    if (!step_ena)
      step_ena_cnt <= step_ena_cnt + 9'd1;
    else if (_step && !_step_del)
      step_ena_cnt <= 0;
  end
end

assign step_ena = step_ena_cnt[8];

// disk change latch
// set by reset or when the disk is removed form the drive
// reset when the disk is present and step pulse is received for selected drive
always @(posedge clk) begin
  if (clk7_en) begin
    _disk_change <= (_disk_change | ~_sel & {4{_step}} & ~{4{_step_del}} & disk_present) & ~({4{reset}} | ~disk_present);
  end
end
 
//active drive number (priority encoder)
assign sel = !_sel[0] ? 2'd0 : !_sel[1] ? 2'd1 : !_sel[2] ? 2'd2 : !_sel[3] ? 2'd3 : 2'd0;

//delayed drive select signals
always @(posedge clk) begin
  if (clk7_en) begin
    _sel_del <= _sel;
  end
end

//drive motor control
always @(posedge clk) begin
  if (clk7_en) begin
    if (reset)
      motor_on[0] <= 0;
    else if (!_sel[0] && _sel_del[0])
      motor_on[0] <= ~_motor;
  end
end

always @(posedge clk) begin
  if (clk7_en) begin
    if (reset)
      motor_on[1] <= 0;
    else if (!_sel[1] && _sel_del[1])
      motor_on[1] <= ~_motor;
  end
end

always @(posedge clk) begin
  if (clk7_en) begin
    if (reset)
      motor_on[2] <= 0;
    else if (!_sel[2] && _sel_del[2])
      motor_on[2] <= ~_motor;
  end
end

always @(posedge clk) begin
  if (clk7_en) begin
    if (reset)
      motor_on[3] <= 0;
    else if (!_sel[3] && _sel_del[3])
      motor_on[3] <= ~_motor;
  end
end

//_ready,_track0 and _change signals
assign _change = &(_sel | _disk_change);

assign _wprot = &(_sel | disk_writable);

assign  _track0 =&(_selx | _dsktrack0);

//track control
assign track = {dsktrack[sel],~side};

always @(posedge clk) begin
  if (clk7_en) begin
    if (!_selx && _step && !_step_del && step_ena) begin // track increment (direc=0) or decrement (direc=1) at rising edge of _step
      if (!dsktrack79 && !direc)
        dsktrack[sel] <= dsktrack[sel] + 7'd1;
      else if (_dsktrack0 && direc)
        dsktrack[sel] <= dsktrack[sel] - 7'd1;	
    end
  end
end

// _dsktrack0 detect
assign _dsktrack0 = ~(dsktrack[sel]==0);

// dsktrack79 detect
assign dsktrack79 = dsktrack[sel]==82;

// drive _ready signal control
// Amiga DD drive activates _ready whenever _sel is active and motor is off
// or whenever _sel is active, motor is on and there is a disk inserted (not implemented - _ready is active when _sel is active)
assign _ready   = (_sel[3] | ~(drives[1] & drives[0])) 
        & (_sel[2] | ~drives[1]) 
        & (_sel[1] | ~(drives[1] | drives[0])) 
        & (_sel[0]);

//--------------------------------------------------------------------------------------

//disk data byte and status read
assign dskbytr = reg_address_in[8:1]==DSKBYTR[8:1] ? {1'b1,(trackrd|trackwr),dsklen[14],5'b1_0000,8'h00} : 16'h00_00;

//disk sync register
always @(posedge clk) begin
  if (clk7_en) begin
  	if (reset) 
  		dsksync[15:0] <= 16'h4489;
  	else if (reg_address_in[8:1]==DSKSYNC[8:1])
  		dsksync[15:0] <= data_in[15:0];
  end
end

//disk length register
always @(posedge clk) begin
  if (clk7_en) begin
  	if (reset)
  		dsklen[14:0] <= 0;
  	else if (reg_address_in[8:1]==DSKLEN[8:1])
  		dsklen[14:0] <= data_in[14:0];
  	else if (fifo_wr)//decrement length register
  		dsklen[13:0] <= dsklen[13:0] - 14'd1;
  end
end

//disk length register DMAEN
always @(posedge clk) begin
  if (clk7_en) begin
  	if (reset)
  		dsklen[15] <= 0;
  	else if (blckint)
  		dsklen[15] <= 0;
  	else if (reg_address_in[8:1]==DSKLEN[8:1])
  		dsklen[15] <= data_in[15];
  end
end

//dmaen - disk dma enable signal
always @(posedge clk) begin
  if (clk7_en) begin
  	if (reset)
  		dmaen <= 0;
  	else if (blckint)
  		dmaen <= 0;
  	else if (reg_address_in[8:1]==DSKLEN[8:1])
  		dmaen <= data_in[15] & dsklen[15];//start disk dma if second write in a row with dsklen[15] set
  end
end

//dsklen zero detect
assign lenzero = (dsklen[13:0]==0);

//--------------------------------------------------------------------------------------
//disk data read path
wire	busrd;				//bus read
wire	buswr;				//bus write
reg		trackrdok;			//track read enable

//disk buffer bus read address decode
assign busrd = (reg_address_in[8:1]==DSKDATR[8:1]);

//disk buffer bus write address decode
assign buswr = (reg_address_in[8:1]==DSKDAT[8:1]);

//fifo data input multiplexer
assign fifo_in[15:0] = trackrd ? rx_data[15:0] : data_in[15:0];

//data word transfer strobe
wire stbdat = cmd_fdd && stb7 && &cmd_cnt;

//fifo write control
assign fifo_wr = (trackrdok & stbdat & ~lenzero) | (buswr & dmaon);

//delayed version to allow writing of the last word to empty fifo
always @(posedge clk) begin
  if (clk7_en) begin
  	fifo_wr_del <= fifo_wr;
  end
end

//fifo read control
assign fifo_rd = (busrd & dmaon) | (trackwr & stbdat);

//DSKSYNC interrupt
wire sync_match;
assign sync_match = dsksync[15:0]==rx_data[15:0] && stbdat && trackrd;

assign syncint = sync_match | ~dmaen & |(~_sel & motor_on & disk_present) & sof;

//track read enable / wait for syncword logic
always @(posedge clk) begin
  if (clk7_en) begin
  	if (!trackrd)//reset
  		trackrdok <= 0;
  	else//wordsync is enabled, wait with reading untill syncword is found
  		trackrdok <= ~wordsync | sync_match | trackrdok;
  end
end

assign fifo_reset = reset | ~dmaen;
		
//disk fifo / trackbuffer
paula_floppy_fifo db1
(
	.clk(clk),
	.clk7_en(clk7_en),
	.reset(fifo_reset),
	.in(fifo_in),
	.out(fifo_out),
	.rd(fifo_rd & ~fifo_empty),
	.wr(fifo_wr & ~fifo_full),
	.empty(fifo_empty),
	.full(fifo_full),
	.cnt(fifo_cnt)
);


//disk data read output gate
assign dskdatr[15:0] = busrd ? fifo_out[15:0] : 16'h00_00;

//--------------------------------------------------------------------------------------
//dma request logic
assign dmal = dmaon & (~dsklen[14] & ~fifo_empty | dsklen[14] & ~fifo_full);

//dmas is active during writes
assign dmas = dmaon & dsklen[14] & ~fifo_full;

//--------------------------------------------------------------------------------------
//main disk controller
reg		[1:0] dskstate;		//current state of disk
reg		[1:0] nextstate; 	//next state of state

//disk states
parameter DISKDMA_IDLE   = 2'b00;
parameter DISKDMA_ACTIVE = 2'b10;
parameter DISKDMA_INT    = 2'b11;

//disk present and write protect status
always @(posedge clk) begin
  if (clk7_en) begin
  	if(reset)
  		{disk_writable[3:0],disk_present[3:0]} <= 8'b0000_0000;
  	else if (rx_data[15:12]==4'b0001 && stb7 && !cmd_cnt)
  		{disk_writable[3:0],disk_present[3:0]} <= rx_data[7:0];
  end
end

//disk activity LED
assign fdd_led = (dskstate!=DISKDMA_IDLE);
//assign disk_led = |motor_on;

//main disk state machine
always @(posedge clk) begin
  if (clk7_en) begin
  	if (reset)
  		dskstate <= DISKDMA_IDLE;		
  	else
  		dskstate <= nextstate;
  end
end

always @(*) begin
	case(dskstate)
		DISKDMA_IDLE://disk is present in flash drive
		begin
			trackrd = 0;
			trackwr = 0;
			dmaon = 0;
			blckint = 0;
			if (cmd_fdd && stb7 && cmd_cnt==1 && dmaen && !lenzero && enable)//dsklen>0 and dma enabled, do disk dma operation
				nextstate = DISKDMA_ACTIVE; 
			else
				nextstate = DISKDMA_IDLE;			
		end
		DISKDMA_ACTIVE://do disk dma operation
		begin
      trackrd = ~lenzero & ~dsklen[14]; // track read (disk->ram)
      trackwr = dsklen[14]; // track write (ram->disk)
      dmaon = ~lenzero | ~dsklen[14];
			blckint=0;
			if (!dmaen || !enable)
				nextstate = DISKDMA_IDLE;
			else if (lenzero && fifo_empty && !fifo_wr_del)//complete dma cycle done
				nextstate = DISKDMA_INT;
			else
				nextstate = DISKDMA_ACTIVE;			
		end
		DISKDMA_INT://generate disk dma completed (DSKBLK) interrupt
		begin
			trackrd = 0;
			trackwr = 0;
			dmaon = 0;
			blckint = 1;
			nextstate = DISKDMA_IDLE;			
		end
		default://we should never come here
		begin
			trackrd = 1'bx;
			trackwr = 1'bx;
			dmaon = 1'bx;
			blckint = 1'bx;
			nextstate = DISKDMA_IDLE;			
		end
	endcase
end


endmodule

