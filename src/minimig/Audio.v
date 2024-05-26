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
// This is the audio part of Paula
//
// 27-12-2005	- started coding
// 28-12-2005	- done lots of work
// 29-12-2005	- done lots of work
// 01-01-2006	- we are having OK sound in dma mode now
// 02-01-2006	- fixed last state
// 03-01-2006	- added dmas to avoid interference with copper cycles
// 04-01-2006	- experimented with DAC
// 06-01-2006	- experimented some more with DAC and decided to leave it as it is for now
// 07-01-2006	- cleaned up code
// 21-02-2006	- improved audio state machine
// 22-02-2006	- fixed dma interrupt timing, Turrican-3 theme now plays correct!
//
// -- JB --
// 2008-10-12	- code clean-up
// 2008-12-20	- changed DMA slot allocation
// 2009-03-08	- horbeam removed
//				- strhor signal added (cures problems with freezing of some games)
//				- corrupted Agony title song
// 2009-03-17	- audio FSM rewritten to comply more exactly with HRM state diagram, Agony still has problems
// 2009-03-26	- audio dma requests are latched and cleared at the start of every scan line, seemd to cure Agony problem
//				- Forgotten Worlds freezes at game intro screen due to missed audio irq
// 2009-05-24	- clean-up & renaming
// 2009-11-14	- modified audio state machine to be more cycle-exact with its real counterpart
//				- sigma-delta modulator is clocked at 28 MHz
// 2010-06-15	- updated description

// Paula requests data from Agnus using DMAL line (high active state)
// DMAL time slot allocation (relative to first refresh slot referenced as $00):
// $03,$05,$07 - all these slots are active when disk dma is inactive or write operation is in progress
// $04 - at least 3 words to read / at least 1 word  to write (transfer in $08)
// $06 - at least 2 words to read / at least 2 words to write (transfer in $0A)
// $08 - at least 1 word  to read / at least 3 words to write (transfer in $0C)
// $09 - audio channel #0 location pointer reload request (active with data request) 
// $0A - audio channle #0 dma data request (data transfered in slot $0E)
// $0B - audio channel #1 location pointer reload request (active with data request) 
// $0C - audio channle #1 dma data request (data transfered in slot $10)
// $0D - audio channel #2 location pointer reload request (active with data request) 
// $0E - audio channle #2 dma data request (data transfered in slot $12)
// $0F - audio channel #3 location pointer reload request (active with data request) 
// $10 - audio channle #3 dma data request (data transfered in slot $14)
// minimum sampling period for audio channels in CCKs (no length reload)
// #0 : 121 (120) 
// #1 : 122 (121)
// #2 : 123 (122)
// #3 : 124 (123)

// SB:
// 2011-01-18 - fixed sound output, no more high pitch noise at game Gods

// TobiFlex(TF):
// 2012-02-12 - change sigma/delta module

// AMR:
// 2012-08-17 - remove multiplexing in front of sigma/delta module.

module audio
(
	input 	clk,		    		//bus clock
	input	clk28m,
	input 	cck,		    		//colour clock enable
	input 	reset,			   		//reset 
	input	strhor,					//horizontal strobe
	input 	[8:1] reg_address_in,	//register address input
	input	[15:0] data_in,			//bus data in
	input	[3:0] dmaena,			//audio dma register input
	output	[3:0] audint,			//audio interrupt request
	input	[3:0] audpen,			//audio interrupt pending
	output	reg [3:0] dmal,			//dma request 
	output	reg [3:0] dmas,			//dma special 
        output  [14:0] left,
        output  [14:0] right
);

//register names and addresses
parameter	AUD0BASE = 9'h0a0;
parameter	AUD1BASE = 9'h0b0;
parameter	AUD2BASE = 9'h0c0;
parameter	AUD3BASE = 9'h0d0;

//local signals
wire	[3:0] aen;			//address enable 0-3
wire	[3:0] dmareq;		//dma request 0-3
wire	[3:0] dmaspc;		//dma restart 0-3
wire	[7:0] sample0;		//channel 0 audio sample
wire	[7:0] sample1;		//channel 1 audio sample
wire	[7:0] sample2;		//channel 2 audio sample
wire	[7:0] sample3;		//channel 3 audio sample
wire	[6:0] vol0;			//channel 0 volume
wire	[6:0] vol1;			//channel 1 volume
wire	[6:0] vol2;			//channel 2 volume
wire	[6:0] vol3;			//channel 3 volume

//--------------------------------------------------------------------------------------

//address decoder
assign aen[0] = (reg_address_in[8:4]==AUD0BASE[8:4]) ? 1'b1 : 1'b0;
assign aen[1] = (reg_address_in[8:4]==AUD1BASE[8:4]) ? 1'b1 : 1'b0;
assign aen[2] = (reg_address_in[8:4]==AUD2BASE[8:4]) ? 1'b1 : 1'b0;
assign aen[3] = (reg_address_in[8:4]==AUD3BASE[8:4]) ? 1'b1 : 1'b0;

//--------------------------------------------------------------------------------------

//DMA slot allocation is managed by Agnus 
//#0 : 0E
//#1 : 10
//#2 : 12
//#3 : 14

always @(posedge clk)
	if (strhor)
	begin
		dmal <= (dmareq);
		dmas <= (dmaspc);
	end
		
//--------------------------------------------------------------------------------------

//instantiate audio channel 0
audiochannel ach0
(
	.clk(clk),
	.reset(reset),
	.cck(cck),
	.aen(aen[0]),
	.dmaena(dmaena[0]),
	.reg_address_in(reg_address_in[3:1]),
	.data(data_in),
	.volume(vol0),
	.sample(sample0),
	.intreq(audint[0]),
	.intpen(audpen[0]),
	.dmareq(dmareq[0]),
	.dmas(dmaspc[0]),
	.strhor(strhor)
);

//instantiate audio channel 1
audiochannel ach1
(
	.clk(clk),
	.reset(reset),
	.cck(cck),
	.aen(aen[1]),
	.dmaena(dmaena[1]),
	.reg_address_in(reg_address_in[3:1]),
	.data(data_in),
	.volume(vol1),
	.sample(sample1),
	.intreq(audint[1]),
	.intpen(audpen[1]),
	.dmareq(dmareq[1]),
	.dmas(dmaspc[1]),
	.strhor(strhor)
);

//instantiate audio channel 2
audiochannel ach2
(
	.clk(clk),
	.reset(reset),
	.cck(cck),
	.aen(aen[2]),
	.dmaena(dmaena[2]),
	.reg_address_in(reg_address_in[3:1]),
	.data(data_in),
	.volume(vol2),
	.sample(sample2),
	.intreq(audint[2]),
	.intpen(audpen[2]),
	.dmareq(dmareq[2]),
	.dmas(dmaspc[2]),
	.strhor(strhor)	
);

//instantiate audio channel 3
audiochannel ach3
(
	.clk(clk),
	.reset(reset),
	.cck(cck),
	.aen(aen[3]),
	.dmaena(dmaena[3]),
	.reg_address_in(reg_address_in[3:1]),
	.data(data_in),
	.volume(vol3),
	.sample(sample3),
	.intreq(audint[3]),
	.intpen(audpen[3]),
	.dmareq(dmareq[3]),
	.dmas(dmaspc[3]),
	.strhor(strhor)
);

//instantiate volume control
volume_mixer dac0 
(
	.clk({clk28m}),
	.sample0(sample0),
	.sample1(sample1),
	.sample2(sample2),
	.sample3(sample3),
	.vol0(vol0),
	.vol1(vol1),
	.vol2(vol2),
	.vol3(vol3),
	.strhor(strhor),
	.left(left),
	.right(right)
);

//--------------------------------------------------------------------------------------

endmodule


module third_order_sigma_delta_dac
(
input rst,
input clk,
input [15:0] pcm_in,
output reg dac_out
);

// ======================================
// ============== Stage #1 ==============
// ======================================
wire [23:0] w_data_in_p0;
wire [23:0] w_data_err_p0;
wire [23:0] w_data_int_p0;
reg [23:0] r_data_fwd_p1;
wire [23:0] w_data_qt_p2;
wire [23:0] w_data_fb3_p1;
wire [23:0] w_data_int_p1;
reg [23:0] r_data_fwd_p2;
wire [23:0] w_data_fb1_p1;
wire [23:0] w_data_fb2_p1;
wire [23:0] w_data_lpf_p1;
reg [23:0] r_data_lpf_p2;

// PCM input extended to 20 bits
assign w_data_in_p0 = { {4{pcm_in[15]}}, pcm_in, 4'b0000 };

// Error between the input and the quantizer output
assign w_data_err_p0 = w_data_in_p0 - w_data_qt_p2;

// First integrator adder
assign w_data_int_p0 = { {3{w_data_err_p0[23]}}, w_data_err_p0[22:2] } // Divide by 4
+ r_data_fwd_p1;

// First integrator forward delay
always @(posedge rst or posedge clk)
if (rst)
r_data_fwd_p1 <= 24'd0;
else
r_data_fwd_p1 <= w_data_int_p0;

// ======================================
// ============== Stage #2 ==============
// ======================================

// Feedback from the quantizer output
assign w_data_fb1_p1 = { {3{r_data_fwd_p1[23]}}, r_data_fwd_p1[22:2] } // Divide by 4
- { {3{w_data_qt_p2[23]}}, w_data_qt_p2[22:2] }; // Divide by 4

// Feedback from the third stage
assign w_data_fb2_p1 = w_data_fb1_p1
- { {14{r_data_fwd_p2[23]}}, r_data_fwd_p2[22:13] }; // Divide by 8192

// Low pass filter
assign w_data_lpf_p1 = w_data_fb2_p1 + r_data_lpf_p2;

// Low pass filter feedback delay
always @(posedge rst or posedge clk)
if (rst)
r_data_lpf_p2 <= 24'd0;
else
r_data_lpf_p2 <= w_data_lpf_p1;

// ======================================
// ============== Stage #3 ==============
// ======================================

// Feedback from the quantizer output
assign w_data_fb3_p1 = { {2{w_data_lpf_p1[23]}}, w_data_lpf_p1[22:1] } // Divide by 2
- { {2{w_data_qt_p2[23]}}, w_data_qt_p2[22:1] }; // Divide by 2

// Second integrator adder
assign w_data_int_p1 = w_data_fb3_p1 + r_data_fwd_p2;

// Second integrator forward delay
always @(posedge rst or posedge clk)
if (rst)
r_data_fwd_p2 <= 24'd0;
else
r_data_fwd_p2 <= w_data_int_p1;

// =====================================
// ========== 1-bit quantizer ==========
// =====================================

assign w_data_qt_p2 = (r_data_fwd_p2[23]) ? 24'hF00000 : 24'h100000;

always @(posedge rst or posedge clk)
if (rst)
dac_out <= 1'b0;
else
dac_out <= ~r_data_fwd_p2[23];

endmodule


//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------

// audio data processing
// stereo volume control
// channel 1&2 --> left
// channel 0&3 --> right
module volume_mixer
(
	input clk,					//bus clock
	input	[7:0] sample0,		//sample 0 input
	input	[7:0] sample1,		//sample 1 input
	input	[7:0] sample2,		//sample 2 input
	input	[7:0] sample3,		//sample 3 input
	input	[6:0] vol0,			//volume 0 input
	input	[6:0] vol1,			//volume 1 input
	input	[6:0] vol2,			//volume 2 input
	input	[6:0] vol3,			//volume 3 input
	input	strhor,
	output	[14:0] left,			//left dac output
	output	[14:0] right			//right dac output
);

//local signals
wire	[7:0] leftsmux;			//left mux sample
wire	[7:0] rightsmux;		//right mux sample
wire	[6:0] leftvmux;			//left mux volum
wire	[6:0] rightvmux;		//right mux volume
wire    [13:0] ldata;	                //left DAC data
wire    [13:0] rdata; 	 		//right DAC data
reg	[13:0] ldatatmp;		//left DAC data
reg	[13:0] rdatatmp; 		//right DAC data
reg     [14:0] ldatasum;                //left DAC data
reg     [14:0] rdatasum; 		//right DAC data
reg	lout;
reg	rout;
reg		mxc;					//multiplex control

assign left  = ldatasum;
assign right = rdatasum;
   
//--------------------------------------------------------------------------------------

//multiplexer control
always @(posedge clk)
	begin
		mxc <= ~mxc;
		if (mxc)
		begin
			ldatatmp <= ldata;
			rdatatmp <= rdata;
		end
		else
		begin
			ldatasum <= {ldata[13], ldata} + {ldatatmp[13], ldatatmp};
			rdatasum <= {rdata[13], rdata} + {rdatatmp[13], rdatatmp};
		end
	end

//sample multiplexer
assign leftsmux = mxc ? sample1 : sample2;
assign rightsmux = mxc ? sample0 : sample3;

//volume multiplexer
assign leftvmux = mxc ? vol1 : vol2;
assign rightvmux = mxc ? vol0 : vol3;

//left volume control
//when volume MSB is set, volume is always maximum
svmul sv0
(
	.sample(leftsmux),
	.volume(({	(leftvmux[6] | leftvmux[5]),
				(leftvmux[6] | leftvmux[4]),
				(leftvmux[6] | leftvmux[3]),
				(leftvmux[6] | leftvmux[2]),
				(leftvmux[6] | leftvmux[1]),
				(leftvmux[6] | leftvmux[0]) })),
	.out(ldata)
);

//right volume control
//when volume MSB is set, volume is always maximum
svmul sv1
(
	.sample(rightsmux),
	.volume(({	(rightvmux[6] | rightvmux[5]),
				(rightvmux[6] | rightvmux[4]),
				(rightvmux[6] | rightvmux[3]),
				(rightvmux[6] | rightvmux[2]),
				(rightvmux[6] | rightvmux[1]),
				(rightvmux[6] | rightvmux[0]) })),
	.out(rdata)
	);

endmodule

//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------

//this module multiplies a signed 8 bit sample with an unsigned 6 bit volume setting
//it produces a 14bit signed result
module svmul
(
	input		[7:0] sample,		//signed sample input
	input		[5:0] volume,		//unsigned volume input
	output	[13:0] out			//signed product out
);

wire	[13:0] sesample;   		//sign extended sample
wire	[13:0] sevolume;			//sign extended volume

//sign extend input parameters
assign	sesample[13:0] = {{6{sample[7]}},sample[7:0]};
assign	sevolume[13:0] = ({8'b00000000,volume[5:0]});

//multiply, synthesizer should infer multiplier here - fixed by ASC (boing4000)
assign out[13:0] = ({sesample[13:0] * sevolume[13:0]});

endmodule

//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------

//This module handles a single amiga audio channel. attached modes are not supported
module audiochannel
(
	input 	clk,					//bus clock
	input 	reset,		    		//reset
	input	cck,					//colour clock enable
	input	aen,					//address enable
	input	dmaena,					//dma enable
	input	[3:1] reg_address_in,		//register address input
	input 	[15:0] data, 			//bus data input
	output	[6:0] volume,			//channel volume output
	output	[7:0] sample,			//channel sample output
	output	intreq,					//interrupt request
	input	intpen,					//interrupt pending input
	output	reg dmareq,				//dma request
	output	reg dmas,				//dma special (restart)
	input	strhor					//horizontal strobe
);

//register names and addresses
parameter	AUDLEN = 4'h4;
parameter	AUDPER = 4'h6;
parameter	AUDVOL = 4'h8;
parameter	AUDDAT = 4'ha;


//local signals
reg		[15:0] audlen;			//audio length register
reg		[15:0] audper;			//audio period register
reg		[6:0] audvol;			//audio volume register
reg		[15:0] auddat;			//audio data register

reg		[15:0] datbuf;			//audio data buffer
reg		[2:0] audio_state;		//audio current state
reg		[2:0] audio_next;	 	//audio next state

wire	datwrite;				//data register is written
reg		volcntrld;				//not used

reg		pbufld1;				//load output sample from sample buffer

reg		[15:0] percnt;			//audio period counter
reg		percount;				//decrease period counter
reg		percntrld;				//reload period counter
wire	perfin;					//period counter expired

reg		[15:0] lencnt;			//audio length counter
reg		lencount;				//decrease length counter
reg		lencntrld;				//reload length counter
wire	lenfin;					//length counter expired

reg 	AUDxDAT;				//audio data buffer was written
wire	AUDxON;					//audio DMA channel is enabled
reg		AUDxDR;					//audio DMA request
reg		AUDxIR;					//audio interrupt request
wire	AUDxIP;					//audio interrupt is pending

reg		intreq2_set;
reg		intreq2_clr;
reg		intreq2;				//buffered interrupt request

reg		dmasen;					//pointer register reloading request
reg		penhi;					//enable high byte of sample buffer

reg	silence;	// AMR: disable audio if repeat length is 1

//--------------------------------------------------------------------------------------
 
//length register bus write
always @(posedge clk)
	if (reset)
		audlen[15:0] <= 16'h00_00;
	else if (aen && (reg_address_in[3:1]==AUDLEN[3:1]))
		audlen[15:0] <= (data[15:0]);

//period register bus write
always @(posedge clk)
	if (reset)
		audper[15:0] <= 16'h00_00;
	else if (aen && (reg_address_in[3:1]==AUDPER[3:1]))
		audper[15:0] <= (data[15:0]);

//volume register bus write
always @(posedge clk)
	if (reset)
		audvol[6:0] <= 7'b000_0000;
	else if (aen && (reg_address_in[3:1]==AUDVOL[3:1]))
		audvol[6:0] <= (data[6:0]);

//data register strobe
assign datwrite = (aen && (reg_address_in[3:1]==AUDDAT[3:1])) ? 1:0;

//data register bus write
always @(posedge clk)
	if (reset)
		auddat[15:0] <= 16'h00_00;
	else if (datwrite)
		auddat[15:0] <= (data[15:0]);

always @(posedge clk)
	if (datwrite)
		AUDxDAT <= 1;
	else if (cck)
		AUDxDAT <= 0;
	
//--------------------------------------------------------------------------------------

assign	AUDxON = (dmaena);	//dma enable

assign	AUDxIP = (intpen);	//audio interrupt pending

assign intreq = (AUDxIR);		//audio interrupt request

//--------------------------------------------------------------------------------------

//period counter 
always @(posedge clk)
	if (percntrld && cck)//load period counter from audio period register
		percnt[15:0] <= (audper[15:0]);
	else if (percount && cck)//period counter count down
		percnt[15:0] <= (percnt[15:0] - 1);

assign perfin = (percnt[15:0]==1 && cck) ? 1 : 0;

//length counter
always @(posedge clk)
	if (lencntrld && cck)//load length counter from audio length register
	begin
		lencnt[15:0] <= (audlen[15:0]);
		silence<=1'b0;
		if(audlen==1 || audlen==0)
			silence<=1'b1;
	end
	else if (lencount && cck)//length counter count down
		lencnt[15:0] <= (lencnt[15:0] - 1);

assign lenfin = (lencnt[15:0]==1 && cck) ? 1 : 0;

//--------------------------------------------------------------------------------------

//audio buffer
always @(posedge clk)
	if (reset)
		datbuf[15:0] <= 16'h00_00;
	else if (pbufld1 && cck)
		datbuf[15:0] <= (auddat[15:0]);

//assign sample[7:0] = (penhi) ? (datbuf[15:8]) : datbuf[7:0];
assign sample[7:0] = silence ? 8'b0 : ((penhi) ? (datbuf[15:8]) : datbuf[7:0]);

//volume output
//assign volume[6:0] = (silence) ? (6'b0) : (audvol[6:0]);
assign volume[6:0] = audvol[6:0];

//--------------------------------------------------------------------------------------

//dma request logic
always @(posedge clk)
begin
	if (reset)
	begin
		dmareq <= 0;
		dmas <= 0;
	end
	else if (AUDxDR && cck)
	begin
		dmareq <= 1;
		dmas <= (dmasen | lenfin);
	end
	else if (strhor) //dma request are cleared when transfered to Agnus
	begin
		dmareq <= 0;
		dmas <= 0;
	end
end

//buffered interrupt request
always @(posedge clk)
	if (cck)
		if (intreq2_set)
			intreq2 <= 1;
		else if (intreq2_clr)
			intreq2 <= 0;

//audio states
parameter AUDIO_STATE_0 = 3'b000;
parameter AUDIO_STATE_1 = 3'b001;
parameter AUDIO_STATE_2 = 3'b011;
parameter AUDIO_STATE_3 = 3'b010;
parameter AUDIO_STATE_4 = 3'b110;

//audio channel state machine
always @(posedge clk)
begin
	if (reset)
		audio_state <= (AUDIO_STATE_0);
	else if (cck)
		audio_state <= (audio_next);
end

//transition function
always @(audio_state or AUDxON or AUDxDAT or AUDxIP or lenfin or perfin or intreq2)
begin
	case (audio_state)
	
		AUDIO_STATE_0: //audio FSM idle state
		begin
			intreq2_clr = 1;
			intreq2_set = 0;
			lencount = 0;
			penhi = 0;
			percount = 0;
			percntrld = 1;
						
			if (AUDxON) //start of DMA driven audio playback
			begin
				audio_next = AUDIO_STATE_1;
				AUDxDR = 1;
				AUDxIR = 0;
				dmasen = 1;
				lencntrld = 1;
				pbufld1 = 0;
				volcntrld = 0;	
			end
			else if (AUDxDAT && !AUDxON && !AUDxIP)	//CPU driven audio playback
			begin
				audio_next = AUDIO_STATE_3;
				AUDxDR = 0;				
				AUDxIR = 1;
				dmasen = 0;
				lencntrld = 0;
				pbufld1 = 1;
				volcntrld = 1;
			end
			else
			begin
				audio_next = AUDIO_STATE_0;
				AUDxDR = 0;				
				AUDxIR = 0;
				dmasen = 0;
				lencntrld = 0;
				pbufld1 = 0;
				volcntrld = 0;	
			end
		end

		AUDIO_STATE_1: //audio DMA has been enabled
		begin
			dmasen = 0;
			intreq2_clr = 1;
			intreq2_set = 0;
			lencntrld = 0;
			penhi = 0;
			percount = 0;
			
			if (AUDxON && AUDxDAT) //requested data has arrived
			begin
				audio_next = AUDIO_STATE_2;
				AUDxDR = 1;
				AUDxIR = 1;
				lencount = ~lenfin;
				pbufld1 = 0;	//first data received, discard it since first data access is used to reload pointer		
				percntrld = 0; 				
				volcntrld = 0;
			end
			else if (!AUDxON) //audio DMA has been switched off so go to IDLE state
			begin
				audio_next = AUDIO_STATE_0;
				AUDxDR = 0;
				AUDxIR = 0;
				lencount = 0;
				pbufld1 = 0;
				percntrld = 0; 
				volcntrld = 0;
			end
			else
			begin
				audio_next = AUDIO_STATE_1;
				AUDxDR = 0;
				AUDxIR = 0;
				lencount = 0;
				pbufld1 = 0;				
				percntrld = 0;
				volcntrld = 0;
			end
		end

		AUDIO_STATE_2: //audio DMA has been enabled
		begin
			dmasen = 0;
			intreq2_clr = 1;
			intreq2_set = 0;
			lencntrld = 0;
			penhi = 0;
			percount = 0;
			
			if (AUDxON && AUDxDAT) //requested data has arrived
			begin
				audio_next = AUDIO_STATE_3;
				AUDxDR = 1;
				AUDxIR = 0;
				lencount = ~lenfin;
				pbufld1 = 1;	//new data has been just received so put it in the output buffer		
				percntrld = 1; 				
				volcntrld = 1;
			end
			else if (!AUDxON) //audio DMA has been switched off so go to IDLE state
			begin
				audio_next = AUDIO_STATE_0;
				AUDxDR = 0;
				AUDxIR = 0;
				lencount = 0;
				pbufld1 = 0;
				percntrld = 0; 
				volcntrld = 0;
			end
			else
			begin
				audio_next = AUDIO_STATE_2;
				AUDxDR = 0;
				AUDxIR = 0;
				lencount = 0;
				pbufld1 = 0;				
				percntrld = 0;
				volcntrld = 0;
			end
		end

		AUDIO_STATE_3: //first sample is being output
		begin
			AUDxDR = 0;
			AUDxIR = 0;
			dmasen = 0;
			intreq2_clr = 0;
			intreq2_set = lenfin & AUDxON & AUDxDAT;
			lencount = ~lenfin & AUDxON & AUDxDAT;
			lencntrld = lenfin & AUDxON & AUDxDAT;
			pbufld1 = 0;
			penhi = 1;
			volcntrld = 0;
		
			if (perfin) //if period counter expired output other sample from buffer
			begin
				audio_next = AUDIO_STATE_4;
				percount = 0;
				percntrld = 1;
			end
			else
			begin
				audio_next = AUDIO_STATE_3;
				percount = 1;
				percntrld = 0;
			end
		end

		AUDIO_STATE_4: //second sample is being output
		begin
			dmasen = 0;
			intreq2_set = lenfin & AUDxON & AUDxDAT;
			lencount = ~lenfin & AUDxON & AUDxDAT;
			lencntrld = lenfin & AUDxON & AUDxDAT;
			penhi = 0;
			volcntrld = 0;
			
			if (perfin && (AUDxON || !AUDxIP)) //period counter expired and audio DMA active
			begin
				audio_next = AUDIO_STATE_3;
				AUDxDR = AUDxON;
				AUDxIR = (intreq2 & AUDxON) | ~AUDxON;
				intreq2_clr = intreq2;
				pbufld1 = 1;
				percount = 0;
				percntrld = 1;
			end
			else if (perfin && !AUDxON && AUDxIP) //period counter expired and audio DMA inactive
			begin
				audio_next = AUDIO_STATE_0;
				AUDxDR = 0;
				AUDxIR = 0;
				intreq2_clr = 0;
				pbufld1 = 0;
				percount = 0;
				percntrld = 0;
			end
			else
			begin
				audio_next = AUDIO_STATE_4;
				AUDxDR = 0;
				AUDxIR = 0;
				intreq2_clr = 0;
				pbufld1 = 0;
				percount = 1;
				percntrld = 0;
			end
		end
		
		default:
		begin
			audio_next = AUDIO_STATE_0;
			AUDxDR = 0;
			AUDxIR = 0;
			dmasen = 0;
			intreq2_clr = 0;
			intreq2_set = 0;
			lencntrld = 0;
			lencount = 0;
			pbufld1 = 0;
			penhi = 0;
			percount = 0;
			percntrld = 0;
			volcntrld = 0;	
		end		
		
	endcase
end

//--------------------------------------------------------------------------------------

endmodule
