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

module conv_group_sum (
	input                                       clk             ,

	input           [`DATA_INTER_WIDTH-1 :0]    inter_data_1    ,
	input           [`DATA_INTER_WIDTH-1 :0]    inter_data_2    ,
	input           [`DATA_INTER_WIDTH-1 :0]    inter_data_3    ,
	input           [`DATA_INTER_WIDTH-1 :0]    inter_data_4    ,

	output    reg   [`DATA_INTER_WIDTH-1 :0]    out_data    
);

	reg [`DATA_INTER_WIDTH-1 :0] temp1,temp2;

	always @ (posedge clk) begin
		temp1 <= inter_data_1 + inter_data_2 ;
		temp2 <= inter_data_3 + inter_data_4 ;

		out_data <= temp1 + temp2 ;
	end

endmodule
