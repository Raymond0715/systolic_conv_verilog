`include "define.vh"

module trunc(
	input  [`DATA_INTER_WIDTH-1:0] din,

	output [`DATA_ACT_WIDTH-1:0]   dout
);

	/**
		* Parameter:
		* 	- p_data: positve data
		* 	- n_data: negative data
		*/

	wire sign;
	wire [`DATA_ACT_WIDTH-2:0] dout_unsign;
	wire [`DATA_ACT_WIDTH-2:0] p_data;
	wire [`DATA_ACT_WIDTH-2:0] n_data;

	assign sign = din[`DATA_INTER_WIDTH-1];

	assign p_data = |din[`DATA_INTER_WIDTH-1:`TRUNC_UP_BIT+1] ?
								 (`POSITIVE_UP_BOUND) : din[`TRUNC_UP_BIT:`TRUNC_DOWN_BIT];
	assign n_data = ~&(din[`DATA_INTER_WIDTH-1:`TRUNC_UP_BIT+1]) ?
								 (`NEGATIVE_DOWN_BOUND) : din[`TRUNC_UP_BIT:`TRUNC_DOWN_BIT];
	assign dout_unsign = sign ? n_data : p_data;

	assign dout = {sign, dout_unsign};

endmodule
