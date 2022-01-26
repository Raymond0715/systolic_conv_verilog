//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/09/05 20:56:40
// Design Name: 
// Module Name: Top_PL
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
//////////////////////////////////////////////////////////////////////////////////

`include "SIM_CTRL.vh"
`include "DEFINE.vh"

module Weight_Bias_Seperate (
    input clk,
    input rst_n,

    //config
    input               s_axis_wbconfig_tvalid,
    output reg          s_axis_wbconfig_tready,
    input [31:0]        s_axis_wbconfig_tdata ,
    
    //weight in
    input               s_axis_weight_tvalid,
    output              s_axis_weight_tready,
    input [127:0]       s_axis_weight_tdata,
    
    //weight_out
    output              m_axis_weight_tvalid,
    output [127:0]      m_axis_weight_tdata ,
    input               m_axis_weight_tready,

    //bias_out
    output              m_axis_bias_tvalid,
    output [127:0]      m_axis_bias_tdata ,
    input               m_axis_bias_tready,

    output [3:0]        status_wbs
    
);

    reg out_switch ; //0:bias 1:weight

    assign m_axis_weight_tvalid = s_axis_weight_tvalid & s_axis_weight_tready & out_switch    ;
    assign m_axis_bias_tvalid   = s_axis_weight_tvalid & s_axis_weight_tready & (~out_switch) ;
    assign s_axis_weight_tready = out_switch ? m_axis_weight_tready : m_axis_bias_tready;
    assign m_axis_bias_tdata    = out_switch ? 0 : s_axis_weight_tdata ;
    assign m_axis_weight_tdata  = out_switch ? s_axis_weight_tdata : 0 ;

    reg [30:0] bias_len   ; //bus128
    reg [31:0] weight_len ; //bus128
    reg [31:0] data_cnt   ;
    reg        source     ;


    localparam IDLE   = 0 ;
    localparam BIAS   = 1 ;
    localparam WEIGHT = 2 ;

    reg [1:0] cs, ns ;
    reg [1:0] config_cnt;

    assign status_wbs = cs;

    always @ (posedge clk) begin
        if (~rst_n) begin
            cs <= IDLE ;
        end
        else begin
            cs <= ns ;
        end
    end

    always @ (*) begin
        if (~rst_n) begin
            ns = IDLE ;
        end
        else begin
            case (cs)
                IDLE : if((config_cnt >= 2) & (source == `PS)) ns = BIAS;
                else ns = IDLE ;

                BIAS : begin
                    if ((data_cnt + 1 == bias_len) & s_axis_weight_tvalid & s_axis_weight_tready) ns = WEIGHT ;
                    else ns = BIAS ;
                end

                WEIGHT : begin
                    if ((data_cnt + 1 == bias_len + weight_len) & s_axis_weight_tvalid & s_axis_weight_tready) ns = IDLE ;
                    else ns = WEIGHT ;
                end

                default: ns = IDLE ;
            endcase
        end
    end

    always @ (posedge clk) begin
        if (~rst_n) begin
            data_cnt   <= 'd0 ;
            config_cnt <= 'd0 ;
        end
        else begin
            case (ns)
                IDLE : begin
                    out_switch <= 0 ;

                    if (s_axis_wbconfig_tvalid & s_axis_wbconfig_tready) begin
                        config_cnt <= config_cnt + 1'b1 ;
                    end
                    else if (config_cnt == 2) begin
                        config_cnt <= 'd0 ;
                    end

                    case (config_cnt)
                        0: begin
                            bias_len <= s_axis_wbconfig_tdata[30:0] >>2 ;
                            source <= s_axis_wbconfig_tdata[31] ;
                        end
                        1: begin
                            weight_len <= s_axis_wbconfig_tdata >>3 ;
                        end 
                    endcase

                    if (config_cnt >= 1) s_axis_wbconfig_tready  <= 'd0;
                    else s_axis_wbconfig_tready  <= 'd1;
                end

                BIAS : begin
                    out_switch <= 0 ;
                    config_cnt <= 'd0 ;
                    if (s_axis_weight_tvalid & s_axis_weight_tready) data_cnt <= data_cnt + 1 ;
                end

                WEIGHT : begin
                    out_switch <= 1 ;
                    if (s_axis_weight_tvalid & s_axis_weight_tready) data_cnt <= data_cnt + 1 ;
                end
            endcase
        end
    end

endmodule