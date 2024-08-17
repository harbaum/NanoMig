// colortable ram

module denise_colortable_ram_mf (
        input	[3:0]  byteena_a,
	input	  clock,
	input	[31:0]  data,
	input	  enable,
	input	[7:0]  rdaddress,
	input	[7:0]  wraddress,
	input	  wren,
	output	reg [31:0]  q
);

reg [7:0] ram0[255:0];
reg [7:0] ram1[255:0];
reg [7:0] ram2[255:0];
reg [7:0] ram3[255:0];
   
always @(posedge clock) begin
   if(enable) begin
      if(wren) begin
	 if(byteena_a[0]) ram0[wraddress] <= data[ 7: 0];
	 if(byteena_a[1]) ram1[wraddress] <= data[15: 8];
	 if(byteena_a[2]) ram2[wraddress] <= data[23:16];
	 if(byteena_a[3]) ram3[wraddress] <= data[31:24];
      end else
	q <= { ram3[rdaddress], ram2[rdaddress], ram1[rdaddress], ram0[rdaddress] }; 
   end   
end
   
endmodule
