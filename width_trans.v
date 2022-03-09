`include "SIM_CTRL.vh"

module width_trans (
	input clk,
	input rst_n,

	//act in
	input               s_axis_act_tvalid,
	output              s_axis_act_tready,
	input [31:0]        s_axis_act_tdata,

	//weight in
	input               s_axis_weight_tvalid,
	output              s_axis_weight_tready,
	input [31:0]        s_axis_weight_tdata,

	//act out
	output              m_axis_act_tvalid,
	input               m_axis_act_tready,
	output [127:0]      m_axis_act_tdata,

	//weight_out
	output              m_axis_weight_tvalid,
	output [127:0]      m_axis_weight_tdata ,
	input               m_axis_weight_tready

);


// ACT
	/*************************************** FOR SIM ***************************************/
	`ifdef SIM
		reg R_gen_data = 0 ;

		always @ (posedge clk) begin
			if (rst_n) R_gen_data <= 1 ;
		end

		wire [31:0] act_tdata;

		data_gen  #(
			.Width                (128                            ),
			.CONFIG_LEN           (`IMG_LEN/8                     ),
			.FRAME_NUM            (`FRAME_NUM                     ),
			.Data_Path            (`IMG_DIR                       )
		)
		inst_data_gen (
			.i_sys_clk            (clk                            ),
			.i_sys_rst_n          (rst_n                          ),

			.i_start              (R_gen_data                     ),

			.O_chan_cha1_ph_tdata (m_axis_act_tdata               ),
			.O_chan_ph_tvalid     (m_axis_act_tvalid              ),
			.O_chan_ph_tlast      (                               ),
			.O_chan_ph_tready     (R_gen_data & m_axis_act_tready )
		);

	`else
	/*************************************** FOR REAL ***************************************/
		wire prog_full ;
		assign s_axis_act_tready = ~prog_full;

		//act2DDR
		fifo_w16r128_d4k512 act_expand (
			.clk(clk),                                     // input wire clk
			.srst(~rst_n),                                 // input wire srst
			.din(s_axis_act_tdata[15:0]),                  // input wire [31 : 0] din
			.wr_en(s_axis_act_tvalid & s_axis_act_tready), // input wire wr_en
			.rd_en(m_axis_act_tready),                     // input wire rd_en
			.dout(m_axis_act_tdata),                       // output wire [127 : 0] dout
			.full(),                                       // output wire full
			.empty(),                                      // output wire empty
			.valid(m_axis_act_tvalid),                     // output wire valid
			.prog_full(prog_full),                         // output wire prog_full
			.wr_rst_busy(),                                // output wire wr_rst_busy
			.rd_rst_busy()                                 // output wire rd_rst_busy
		);
	`endif
	/*************************************** END ***************************************/



// WEIGHT
	/*************************************** FOR SIM ***************************************/
	`ifdef SIM
		data_gen  #(
			.Width                (128                  ),
			.CONFIG_LEN           (`WEI_LEN/8           ),
			.FRAME_NUM            (`FRAME_NUM           ),
			.Data_Path            (`WEI_DIR             )
		)
		inst_weight_gen (
			.i_sys_clk            (clk                  ),
			.i_sys_rst_n          (rst_n                ),

			.i_start              (R_gen_data           ),

			.O_chan_cha1_ph_tdata (m_axis_weight_tdata  ),
			.O_chan_ph_tvalid     (m_axis_weight_tvalid ),
			.O_chan_ph_tlast      (                     ),
			.O_chan_ph_tready     (R_gen_data  & m_axis_weight_tready)
		);

	`else
	/*************************************** FOR REAL ***************************************/
		wire weight_progfull ;
		assign s_axis_weight_tready = ~weight_progfull;

		//weight out
		fifo_w32r128_d512_2k weight_expand (
			.clk(clk),                                              // input wire clk
			.srst(~rst_n),                                          // input wire srst
			.din(s_axis_weight_tdata),                              // input wire [31 : 0] din
			.wr_en(s_axis_weight_tvalid & s_axis_weight_tready ),   // input wire wr_en
			.rd_en(m_axis_weight_tvalid & m_axis_weight_tready),    // input wire rd_en
			.dout(m_axis_weight_tdata),                             // output wire [127 : 0] dout
			.full(),                                                // output wire full
			.empty(),                                               // output wire empty
			.valid(m_axis_weight_tvalid),                           // output wire valid
			.prog_full(weight_progfull),                            // output wire prog_full
			.wr_rst_busy(),                                         // output wire wr_rst_busy
			.rd_rst_busy()                                          // output wire rd_rst_busy
		);

	`endif
	/*************************************** END ***************************************/

endmodule
