//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2021/06/20 00:25:45
// Design Name:
// Module Name: 1D_convolution
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "DEFINE.vh"

module convolution (
	input                                       clk             ,
	input                                       rst_n           ,

	input           [`DATA_ACT_WIDTH-1 :0]      act_data        ,
	input                                       act_valid       ,
	input                                       mode_1_1        ,

	input           [`DATA_WEIGHT_WIDTH-1 :0]   weight_data     ,
	input                                       weight_valid    ,
	input                                       weight_switch   ,

	output  reg     [`DATA_INTER_WIDTH-1 :0]    inter_data      ,
	output                                      inter_valid
);


	reg rst_reg ;

	always @(posedge clk) begin
		rst_reg <= rst_n ;
	end

	reg [`DATA_WEIGHT_WIDTH-1 :0]  w1, w2, w3, w1_temp, w2_temp, w3_temp ;

	always @(posedge clk) begin
		if (~rst_reg) begin
			w3_temp <= 'd0 ;
			w2_temp <= 'd0 ;
			w1_temp <= 'd0 ;
		end
		else if (weight_valid) begin
			w3_temp <= weight_data ;
			w2_temp <= w3_temp ;
			w1_temp <= w2_temp ;
		end
	end

	always @(posedge clk) begin
		if (~rst_reg) begin
			w3 <= 'd0 ;
			w2 <= 'd0 ;
			w1 <= 'd0 ;
		end
		else if (mode_1_1) begin
			w1 <= weight_data ;
		end
		else if (weight_switch) begin
			w3 <= w3_temp ;
			w2 <= w2_temp ;
			w1 <= w1_temp ;
		end
	end


	reg     [`DATA_ACT_WIDTH-1 :  0]    i               ;
	reg     [`DATA_INTER_WIDTH-1 :0]    temp1, temp2, temp3    ;
	wire    [`DATA_INTER_WIDTH-1 :0]    w1i, w2i, w3i   ;

	always @(posedge clk) begin
		if (~rst_reg) begin
			i <= 'd0 ;
		end
		else begin
			i <= act_data ;
		end
	end

	always @(posedge clk) begin
		if (~rst_reg) begin
			temp1 <= 'd0 ;
			temp2 <= 'd0 ;
			temp3 <= 'd0 ;
			inter_data <= 'd0 ;
		end
		else if (mode_1_1) begin
			inter_data <= w1i;
		end
		else begin
			temp1 <= w1i ;
			temp2 <= temp1 +  w2i;
			temp3 <= w2i;

			if (inter_valid) inter_data <= temp2 +  w3i;
			else inter_data <= temp3 +  w3i;
		end
	end

	//mult_12_24_fix mult_fix_1 (
		//.CLK(clk),  // input wire clk
		//.A(w1),      // input wire [11 : 0] A
		//.B(i),      // input wire [11 : 0] B
		//.P(w1i)      // output wire [23 : 0] P
	//);

	//mult_12_24_fix mult_fix_2 (
		//.CLK(clk),  // input wire clk
		//.A(w2),      // input wire [11 : 0] A
		//.B(i),      // input wire [11 : 0] B
		//.P(w2i)      // output wire [23 : 0] P
	//);

	//mult_12_24_fix mult_fix_3 (
		//.CLK(clk),  // input wire clk
		//.A(w3),      // input wire [11 : 0] A
		//.B(i),      // input wire [11 : 0] B
		//.P(w3i)      // output wire [23 : 0] P
	//);

	shift shift_1(
		.w(w1),
		.x(i),
		.out(w1i)
	);

	shift shift_2(
		.w(w2),
		.x(i),
		.out(w2i)
	);

	shift shift_3(
		.w(w3),
		.x(i),
		.out(w3i)
	);

	wire inter_valid_1_1, inter_valid_3_3;
	
	data_delay #(
		.DATA_WIDTH ( 1 ),
		.LATENCY    ( `CONV_OP_LANTANCY + 2 ))
	u_data_delay1 (
		.clk                     ( clk                          ),
		.rst_n                   ( rst_n                        ),
		.i_data                  ( act_valid                    ),
		.o_data_dly              ( inter_valid_1_1              )
	);

	data_delay #(
		.DATA_WIDTH ( 1 ),
		.LATENCY    ( 1 ))
	u_data_delay2 (
		.clk                     ( clk                          ),
		.rst_n                   ( rst_n                        ),
		.i_data                  ( inter_valid_1_1              ),
		.o_data_dly              ( inter_valid_3_3              )
	);

	assign inter_valid = mode_1_1 ? inter_valid_1_1 : inter_valid_3_3;


endmodule
