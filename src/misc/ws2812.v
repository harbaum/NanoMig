module ws2812 (
	input 	     clk,    // input clock source
    input [23:0] color,  // requested color
	output reg   data    // output to the interface of WS2812
);

parameter WS2812_NUM 	= 0             ; // LED number of WS2812 (starts from 0)
parameter WS2812_WIDTH 	= 24            ; // WS2812 data bit width
parameter CLK_FRE 	= 28_375_160    ; // CLK frequency (mHZ)

parameter DELAY_1_HIGH 	= (CLK_FRE / 1_000_000 * 0.85 )  - 1; //≈850ns±150ns     1 high level time
parameter DELAY_1_LOW 	= (CLK_FRE / 1_000_000 * 0.40 )  - 1; //≈400ns±150ns 	 1 low level time
parameter DELAY_0_HIGH 	= (CLK_FRE / 1_000_000 * 0.40 )  - 1; //≈400ns±150ns 	 0 high level time
parameter DELAY_0_LOW 	= (CLK_FRE / 1_000_000 * 0.85 )  - 1; //≈850ns±150ns     0 low level time
parameter DELAY_RESET 	= (CLK_FRE / 10 ) - 1; //0.1s reset time ＞50us

parameter IDLE 	 		= 0; //state machine statement
parameter DATA_SEND  		= 1;
parameter BIT_SEND_HIGH   	= 2;
parameter BIT_SEND_LOW   	= 3;

parameter INIT_DATA = 24'b1111; // initial pattern

reg [ 1:0] state       = 0; // synthesis preserve  - main state machine control
reg [ 8:0] bit_send    = 0; // number of bits sent - increase for larger led strips/matrix
reg [ 8:0] data_send   = 0; // number of data sent - increase for larger led strips/matrix
reg [31:0] clk_count   = 0; // delay control
reg [23:0] WS2812_data = 0; // WS2812 color data

always@(posedge clk)
	case (state)
		IDLE:begin
			data <= 0;
			if (clk_count < DELAY_RESET) begin
				clk_count <= clk_count + 1;
            end
			else begin
				clk_count <= 0;
                if (WS2812_data != color) begin
                    WS2812_data <= color;
                    state <= DATA_SEND;
                end
			end
		end

		DATA_SEND:
			if (data_send > WS2812_NUM && bit_send == WS2812_WIDTH)begin 
                clk_count <= 0;
				data_send <= 0;
				bit_send  <= 0;
				state <= IDLE;
			end 
			else if (bit_send < WS2812_WIDTH) begin
				state    <= BIT_SEND_HIGH;
			end
			else begin
				data_send <= data_send + 9'd1;
				bit_send  <= 0;
				state    <= BIT_SEND_HIGH;
			end
			
		BIT_SEND_HIGH:begin
			data <= 1;

			if (WS2812_data[bit_send]) 
				if (clk_count < DELAY_1_HIGH)
					clk_count <= clk_count + 1;
				else begin
					clk_count <= 0;
					state    <= BIT_SEND_LOW;
				end
			else 
				if (clk_count < DELAY_0_HIGH)
					clk_count <= clk_count + 1;
				else begin
					clk_count <= 0;
					state    <= BIT_SEND_LOW;
				end
		end

		BIT_SEND_LOW:begin
			data <= 0;

			if (WS2812_data[bit_send]) 
				if (clk_count < DELAY_1_LOW) 
					clk_count <= clk_count + 1;
				else begin
					clk_count <= 0;

					bit_send <= bit_send + 9'd1;
					state    <= DATA_SEND;
				end
			else 
				if (clk_count < DELAY_0_LOW) 
					clk_count <= clk_count + 1;
				else begin
					clk_count <= 0;
					
					bit_send <= bit_send + 9'd1;
					state    <= DATA_SEND;
				end
		end
	endcase
endmodule
