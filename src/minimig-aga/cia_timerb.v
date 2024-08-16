module cia_timerb
(
  input   clk,            // clock
  input clk7_en,
  input  wr,            // write enable
  input   reset,           // reset
  input   tlo,          // timer low byte select
  input  thi,           // timer high byte select
  input  tcr,          // timer control register
  input   [7:0] data_in,      // bus data in
  output   [7:0] data_out,      // bus data out
  input  eclk,            // count enable
  input  tmra_ovf,        // timer A underflow
  output  irq            // intterupt out
);

reg    [15:0] tmr;        // timer
reg    [7:0] tmlh;        // timer latch high byte
reg    [7:0] tmll;        // timer latch low byte
reg    [6:0] tmcr;        // timer control register
reg    forceload;        // force load strobe
wire  oneshot;        // oneshot mode
wire  start;          // timer start (enable)
reg    thi_load;         // load tmr after writing thi in one-shot mode
wire  reload;          // reload timer counter
wire  zero;          // timer counter is zero
wire  underflow;        // timer is going to underflow
wire  count;          // count enable signal

// Timer B count signal source
assign count = tmcr[6] ? tmra_ovf : eclk;

// writing timer control register
always @(posedge clk)
  if (clk7_en) begin
    if (reset)  // synchronous reset
      tmcr[6:0] <= 7'd0;
    else if (tcr && wr)  // load control register, bit 4(strobe) is always 0
      tmcr[6:0] <= {data_in[6:5],1'b0,data_in[3:0]};
    else if (thi_load && oneshot)  // start timer if thi is written in one-shot mode
      tmcr[0] <= 1'd1;
    else if (underflow && oneshot) // stop timer in one-shot mode
      tmcr[0] <= 1'd0;
  end

always @(posedge clk)
  if (clk7_en) begin
    forceload <= tcr & wr & data_in[4];  // force load strobe
  end

assign oneshot = tmcr[3];          // oneshot alias
assign start = tmcr[0];          // start alias

// timer B latches for high and low byte
always @(posedge clk)
  if (clk7_en) begin
    if (reset)
      tmll[7:0] <= 8'b1111_1111;
    else if (tlo && wr)
      tmll[7:0] <= data_in[7:0];
  end

always @(posedge clk)
  if (clk7_en) begin
    if (reset)
      tmlh[7:0] <= 8'b1111_1111;
    else if (thi && wr)
      tmlh[7:0] <= data_in[7:0];
  end

// thi is written in one-shot mode so tmr must be reloaded
always @(posedge clk)
  if (clk7_en) begin
    thi_load <= thi & wr & (~start | oneshot);
  end

// timer counter reload signal
assign reload = thi_load | forceload | underflow;

// timer counter
always @(posedge clk)
  if (clk7_en) begin
    if (reset)
      tmr[15:0] <= 16'hFF_FF;
    else if (reload)
      tmr[15:0] <= {tmlh[7:0],tmll[7:0]};
    else if (start && count)
      tmr[15:0] <= tmr[15:0] - 16'd1;
  end

// timer counter equals zero
assign zero = ~|tmr;

// timer counter is going to underflow
assign underflow = zero & start & count;

// timer underflow interrupt request
assign irq = underflow;

// data output
assign data_out[7:0] = ({8{~wr&tlo}} & tmr[7:0])
          | ({8{~wr&thi}} & tmr[15:8])
          | ({8{~wr&tcr}} & {1'b0,tmcr[6:0]});


endmodule

