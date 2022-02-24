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

module conv_group (
	input                                       clk             ,
	input                                       rst_n           ,

	input           [`DATA_ACT_WIDTH-1 :0]      act_data_1      ,
	input           [`DATA_ACT_WIDTH-1 :0]      act_data_2      ,
	input           [`DATA_ACT_WIDTH-1 :0]      act_data_3      ,
	input           [`DATA_ACT_WIDTH-1 :0]      act_data_4      ,
	input                                       act_valid       ,

	input                                       mode_1_1        ,

	input                                       partial_rstn    ,

	input           [`DATA_WEIGHT_WIDTH*4-1 :0] weight_data     ,//用位宽转换fifo
	input           [2:0]                       weight_valid    ,
	input                                       weight_switch   ,

	output          [`DATA_INTER_WIDTH-1 :0]    conv_data_1     ,
	output          [`DATA_INTER_WIDTH-1 :0]    conv_data_2     ,
	output          [`DATA_INTER_WIDTH-1 :0]    conv_data_3     ,
	output                                      conv_valid
);

	wire [`DATA_WEIGHT_WIDTH-1 :0] weight_data_1, weight_data_2, weight_data_3, weight_data_4 ;
	wire [`DATA_INTER_WIDTH-1  :0] inter_data_1_1, inter_data_1_2, inter_data_1_3, inter_data_2_1,
		inter_data_2_2, inter_data_2_3, inter_data_3_1, inter_data_3_2,
		inter_data_3_3, inter_data_4_1, inter_data_4_2, inter_data_4_3;
	assign {weight_data_4, weight_data_3, weight_data_2, weight_data_1} = weight_data;

	reg rst_n_reg ;

	always @(posedge clk ) rst_n_reg <= rst_n ;

	conv_line  conv_33_1 (
		.clk                     ( clk             ),
		.rst_n                   ( rst_n_reg       ),

		.act_data                ( act_data_1      ),
		.act_valid               ( act_valid       ),
		.mode_1_1                ( mode_1_1        ),

		.weight_data             ( weight_data_1   ),
		.weight_valid            ( weight_valid    ),
		.weight_switch           ( weight_switch   ),

		.inter_data_1            ( inter_data_1_1  ),
		.inter_data_2            ( inter_data_1_2  ),
		.inter_data_3            ( inter_data_1_3  ),
		.inter_valid             ( inter_valid     )
	);

	conv_line  conv_33_2 (
		.clk                     ( clk             ),
		.rst_n                   ( rst_n_reg       ),

		.act_data                ( act_data_2      ),
		.act_valid               ( act_valid       ),
		.mode_1_1                ( mode_1_1        ),

		.weight_data             ( weight_data_2   ),
		.weight_valid            ( weight_valid    ),
		.weight_switch           ( weight_switch   ),

		.inter_data_1            ( inter_data_2_1  ),
		.inter_data_2            ( inter_data_2_2  ),
		.inter_data_3            ( inter_data_2_3  ),
		.inter_valid             (      )
	);

	conv_line  conv_33_3 (
		.clk                     ( clk             ),
		.rst_n                   ( rst_n_reg       ),

		.act_data                ( act_data_3      ),
		.act_valid               ( act_valid       ),
		.mode_1_1                ( mode_1_1        ),

		.weight_data             ( weight_data_3   ),
		.weight_valid            ( weight_valid    ),
		.weight_switch           ( weight_switch   ),

		.inter_data_1            ( inter_data_3_1  ),
		.inter_data_2            ( inter_data_3_2  ),
		.inter_data_3            ( inter_data_3_3  ),
		.inter_valid             (      )
	);

	conv_line  conv_33_4 (
		.clk                     ( clk             ),
		.rst_n                   ( rst_n_reg       ),

		.act_data                ( act_data_4      ),
		.act_valid               ( act_valid       ),
		.mode_1_1                ( mode_1_1        ),

		.weight_data             ( weight_data_4   ),
		.weight_valid            ( weight_valid    ),
		.weight_switch           ( weight_switch   ),

		.inter_data_1            ( inter_data_4_1    ),
		.inter_data_2            ( inter_data_4_2    ),
		.inter_data_3            ( inter_data_4_3    ),
		.inter_valid             (      )
	);

	conv_group_sum conv_group_sum_1 (
		.clk                     ( clk             ),

		.inter_data_1            ( inter_data_1_1  ),
		.inter_data_2            ( inter_data_2_1  ),
		.inter_data_3            ( inter_data_3_1  ),
		.inter_data_4            ( inter_data_4_1  ),

		.out_data                ( conv_data_1     )
	);

	conv_group_sum conv_group_sum_2 (
		.clk                     ( clk             ),
		.inter_data_1            ( inter_data_1_2  ),
		.inter_data_2            ( inter_data_2_2  ),
		.inter_data_3            ( inter_data_3_2  ),
		.inter_data_4            ( inter_data_4_2  ),

		.out_data                ( conv_data_2     )
	);

	conv_group_sum conv_group_sum_3 (
		.clk                     ( clk             ),

		.inter_data_1            ( inter_data_1_3  ),
		.inter_data_2            ( inter_data_2_3  ),
		.inter_data_3            ( inter_data_3_3  ),
		.inter_data_4            ( inter_data_4_3  ),

		.out_data                ( conv_data_3     )
	);

	data_delay #(
		.DATA_WIDTH ( 1 ),
		.LATENCY    ( 2 ))
	u_data_delay (
		.clk                    ( clk             ),
		.rst_n                  ( rst_n_reg       ),
		.i_data                 ( inter_valid     ),
		.o_data_dly             ( conv_valid      )
	);

endmodule
