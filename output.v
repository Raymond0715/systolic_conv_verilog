module Output2PS (
	// data_input
	input [127 :0]       s_axis_output2ps_tdata,
	input                s_axis_output2ps_tvalid,
	output               s_axis_output2ps_tready,

	// data_output
	input                m_axis_output2ps_tready,
	output     [127:0]   m_axis_output2ps_tdata,
	output               m_axis_output2ps_tvalid,
	output reg           m_axis_output2ps_tlast = 'd0,
	output reg [15:0]    m_axis_output2ps_tkeep = 16'hffff
);

	assign m_axis_output2ps_tvalid = s_axis_output2ps_tvalid;
	assign s_axis_output2ps_tready = m_axis_output2ps_tready;
	assign m_axis_output2ps_tdata = s_axis_output2ps_tdata;

endmodule
