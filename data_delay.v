`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Nanjing University
// Engineer: Zhiyuan Xiao
// 
// Create Date: 2020/09/10 14:04:24
// Design Name: data_delay.v
// Module Name: data_delay
// Project Name: usb_ldpc_ecc
// Target Devices: Virtex UltraScale xcuv440-flga2892-2-e
// Tool Versions: vivado 2017.4
// Description: Data delayed output and related control
// 
// Revision:0.01
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module data_delay #(
	parameter DATA_WIDTH	= 0	,
	parameter LATENCY 		= 0
)(
	input 							clk			,
	input 							rst_n		,
	
	input 		[DATA_WIDTH-1:0]	i_data		,
	output 		[DATA_WIDTH-1:0] 	o_data_dly
);

generate 
	if (LATENCY == 0) begin
		assign o_data_dly = (~rst_n)? 0 : i_data;
	end else if (LATENCY == 1) begin
		reg [DATA_WIDTH-1:0] r_data_buffer;
		always @(posedge clk or negedge rst_n) begin
			if(~rst_n)				r_data_buffer <= 0;
			else 					r_data_buffer <= i_data;
		end
		assign o_data_dly = r_data_buffer;
	end else begin
		reg [LATENCY*DATA_WIDTH-1:0] r_data_buffer;
		always @(posedge clk or negedge rst_n) begin
			if(~rst_n)				r_data_buffer <= 0;
			else 					r_data_buffer <= {r_data_buffer[(LATENCY-1)*DATA_WIDTH-1:0],i_data};
		end
		assign o_data_dly = r_data_buffer[LATENCY*DATA_WIDTH-1:(LATENCY-1)*DATA_WIDTH];
	end
endgenerate 

endmodule
