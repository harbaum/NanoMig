// colortable ram

module denise_colortable_ram_mf (
        input [1:0]	  ena_a,
	input		  clock,
	input [11:0]	  data,
	input [7:0]	  rdaddress,
	input [7:0]	  wraddress,
	input		  wren,
	output reg [23:0] q
);

reg [11:0] ram0[255:0];
reg [11:0] ram1[255:0];
   
always @(posedge clock) begin
   if(wren) begin
      if(ena_a[0]) ram0[wraddress] <= data;
      if(ena_a[1]) ram1[wraddress] <= data;
   end

   q <= { ram1[rdaddress], ram0[rdaddress] }; 
end
   
endmodule
