/**brief
 * shift code: `lx` means left shift x bits and `rx` means right shift x bits.
 * 	 - 000 -> l3
 * 	 - 001 -> l2
 * 	 - 010 -> l1
 * 	 - 011 -> 0
 * 	 - 100 -> r1
 * 	 - 101 -> r2
 * 	 - 110 -> r3
 * 	 - 111 -> r4
 * ATTENTION! Try to define parameter as macro. Not finish.
 */ 

`include "DEFINE.vh"
`timescale 1 ns / 1 ps 

module shift(
	input       [`DATA_WEIGHT_WIDTH - 1:0]       w,
	input       [`DATA_ACT_WIDTH - 1:0]          x,
	output      [`DATA_INTER_WIDTH - 1:0]        out
);

wire        [`DATA_WEIGHT_WIDTH - 2:0]  shift_bits;
wire signed [`DATA_ACT_WIDTH:0]         x_signed;
wire        [`DATA_ACT_WIDTH:0]         r_x_signed;
wire        [`DATA_ACT_WIDTH:0]         x_inter;
wire                                    sign_w;
wire        [`DATA_INTER_WIDTH - 1:0]   out_pre;

assign shift_bits = w[2:0];

assign x_signed = $signed(x);

assign r_x_signed = ($signed(9'd0) - $signed(x_signed));

assign x_inter = sign_w ? r_x_signed : x_signed; 

assign sign_w = w[2'd3];

assign out_pre = {{x_inter}, {7'd0}};

assign out = $signed(out_pre) >>> shift_bits;

endmodule
