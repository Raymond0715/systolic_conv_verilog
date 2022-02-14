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

module conv_line (
    input                                       clk             ,
    input                                       rst_n           ,

    input           [`DATA_ACT_WIDTH-1 :0]      act_data        ,
    input                                       act_valid       ,
    input                                       mode_1_1        ,

    input           [`DATA_WEIGHT_WIDTH-1 :0]   weight_data     ,
    input           [2:0]                       weight_valid    ,   //一次拉高3CLK，依次输入权重123
    input                                       weight_switch   ,   //权重切换信号，一次拉高1CLK，拉高时切换新权重    


    output          [`DATA_INTER_WIDTH-1 :0]    inter_data_1    ,
    output          [`DATA_INTER_WIDTH-1 :0]    inter_data_2    ,
    output          [`DATA_INTER_WIDTH-1 :0]    inter_data_3    ,
    output                                      inter_valid
);

    // wire                                        inter_valid     ;
    // wire            [`DATA_INTER_WIDTH-1 :0]    inter_data_1, inter_data_2, inter_data_3;

    wire [`DATA_INTER_WIDTH-1 :0]    inter_data_1_pre, inter_data_3_pre;

    assign inter_data_1 = mode_1_1? 'd0 : inter_data_1_pre;
    assign inter_data_3 = mode_1_1? 'd0 : inter_data_3_pre;


    convolution  convolution1 (
        .clk                     ( clk            ),
        .rst_n                   ( rst_n          ),
        .act_data                ( act_data       ),
        .act_valid               ( act_valid      ),
        .mode_1_1                ( 1'b0           ),

        .weight_switch           ( weight_switch  ),
        .weight_data             ( weight_data    ),
        .weight_valid            ( weight_valid[2]),

        .inter_data              ( inter_data_1_pre   ),
        .inter_valid             (     ) 
    );

    convolution  convolution2 (
        .clk                     ( clk            ),
        .rst_n                   ( rst_n          ),
        .act_data                ( act_data       ),
        .act_valid               ( act_valid      ),
        .mode_1_1                ( mode_1_1       ),

        .weight_switch           ( weight_switch  ),
        .weight_data             ( weight_data    ),
        .weight_valid            ( weight_valid[1]),

        .inter_data              ( inter_data_2   ),
        .inter_valid             ( inter_valid    ) 
    );

    convolution  convolution3 (
        .clk                     ( clk            ),
        .rst_n                   ( rst_n          ),
        .act_data                ( act_data       ),
        .act_valid               ( act_valid      ),
        .mode_1_1                ( 1'b0           ),

        .weight_switch           ( weight_switch  ),
        .weight_data             ( weight_data    ),
        .weight_valid            ( weight_valid[0]),
        
        .inter_data              ( inter_data_3_pre),
        .inter_valid             (     ) 
    );

    // partial_sum  partial_sum (
    //     .clk                     ( clk            ),
    //     .rst_n                   ( rst_n          ),
    //     .inter_data_1            ( inter_data_1   ),
    //     .inter_data_2            ( inter_data_2   ),
    //     .inter_data_3            ( inter_data_3   ),
    //     .inter_valid             ( inter_valid    ),

    //     .sum_data                ( sum_data       ),
    //     .sum_valid               ( sum_valid      ) 
    // );

    //   ila_0 ila_128_8k_2 (
    //       .clk(clk), // input wire clk


    //       .probe0({ weight_valid,weight_switch,weight_data_1
    //                 act_valid,act_data,
    //                 inter_data_1,inter_data_2,inter_data_3,inter_valid,
    //                 sum_valid,sum_data }) // input wire [127:0] probe0
    //     );

endmodule