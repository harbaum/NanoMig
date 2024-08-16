// timer D
//----------------------------------------------------------------------------------
//----------------------------------------------------------------------------------


module cia_timerd
(
  input   clk,            // clock
  input clk7_en,
  input  wr,            // write enable
  input   reset,           // reset
  input   tlo,          // timer low byte select
  input   tme,          // timer mid byte select
  input  thi,           // timer high byte select
  input  tcr,          // timer control register
  input   [7:0] data_in,      // bus data in
  output   reg [7:0] data_out,    // bus data out
  input  count,            // count enable
  output  irq            // intterupt out
);

  reg    latch_ena;        // timer d output latch enable
  reg   count_ena;        // timer d count enable
  reg    crb7;          // bit 7 of control register B
  reg    [23:0] tod;        // timer d
  reg    [23:0] alarm;      // alarm
  reg    [23:0] tod_latch;    // timer d latch
  reg    count_del;        // delayed count signal for interrupt requesting

// timer D output latch control
always @(posedge clk)
  if (clk7_en) begin
    if (reset)
      latch_ena <= 1'd1;
    else if (!wr)
    begin
      if (thi && !crb7) // if MSB read and ALARM is not selected, hold data for subsequent reads
        latch_ena <= 1'd0;
      else if (tlo) // if LSB read, update data every clock
        latch_ena <= 1'd1;
    end
  end

always @(posedge clk)
  if (clk7_en) begin
    if (latch_ena)
      tod_latch[23:0] <= tod[23:0];
  end

// timer D and crb7 read
always @(*)
  if (!wr)
  begin
    if (thi) // high byte of timer D
      data_out[7:0] = tod_latch[23:16];
    else if (tme) // medium byte of timer D (latched)
      data_out[7:0] = tod_latch[15:8];
    else if (tlo) // low byte of timer D (latched)
      data_out[7:0] = tod_latch[7:0];
    else if (tcr) // bit 7 of crb
      data_out[7:0] = {crb7,7'b000_0000};
    else
      data_out[7:0] = 8'd0;
  end
  else
    data_out[7:0] = 8'd0;

// timer D count enable control
always @(posedge clk)
  if (clk7_en) begin
    if (reset)
      count_ena <= 1'd1;
    else if (wr && !crb7) // crb7==0 enables writing to TOD counter
    begin
      if (thi/* || tme*/) // stop counting
        count_ena <= 1'd0;
      else if (tlo) // write to LSB starts counting again
        count_ena <= 1'd1;
    end
  end

// timer D counter
always @(posedge clk)
  if (clk7_en) begin
    if (reset) // synchronous reset
    begin
      tod[23:0] <= 24'd0;
    end
    else if (wr && !crb7) // crb7==0 enables writing to TOD counter
    begin
      if (tlo)
        tod[7:0] <= data_in[7:0];
      if (tme)
        tod[15:8] <= data_in[7:0];
      if (thi)
        tod[23:16] <= data_in[7:0];
    end
    else if (count_ena && count)
      tod[23:0] <= tod[23:0] + 24'd1;
  end

// alarm write
always @(posedge clk)
  if (clk7_en) begin
    if (reset) // synchronous reset
    begin
      alarm[7:0] <= 8'b1111_1111;
      alarm[15:8] <= 8'b1111_1111;
      alarm[23:16] <= 8'b1111_1111;
    end
    else if (wr && crb7) // crb7==1 enables writing to ALARM
    begin
      if (tlo)
        alarm[7:0] <= data_in[7:0];
      if (tme)
        alarm[15:8] <= data_in[7:0];
      if (thi)
        alarm[23:16] <= data_in[7:0];
    end
  end

// crb7 write
always @(posedge clk)
  if (clk7_en) begin
    if (reset)
      crb7 <= 1'd0;
    else if (wr && tcr)
      crb7 <= data_in[7];
  end

// delayed count enable signal
always @(posedge clk)
  if (clk7_en) begin
    count_del <= count & count_ena;
  end

// alarm interrupt request
assign irq = (tod[23:0]==alarm[23:0] && count_del) ? 1'b1 : 1'b0;


endmodule

