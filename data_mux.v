`include "DEFINE.vh"

module act_mux (
	input           clk,
	input           rst_n,

	input           s_config_valid,
	output  reg     s_config_ready = 0 ,
	input [31:0]    s_config_data,

	input           s_data_valid,
	output          s_data_ready,
	input [63:0]    s_data,

	//out
	output           [`DATA_ACT_WIDTH-1 :0]      act_data_1      ,
	output           [`DATA_ACT_WIDTH-1 :0]      act_data_2      ,
	output           [`DATA_ACT_WIDTH-1 :0]      act_data_3      ,
	output           [`DATA_ACT_WIDTH-1 :0]      act_data_4      ,
	output                                       act_valid       ,
	input                                        act_ready       ,

	output           [9:0]                       act_dcnt        ,

	output           [3:0]                       status_dmux
);

	reg [11:0] pix=0, line=0, img_h = 0, img_w = 0 ;
	reg [15:0] /*ch_num=0 ,ch_left=0, */cycle_len = 0, cycle_offset = 0;
	reg [`DATA_ACT_WIDTH-1:0] fifo_din_1,fifo_din_2,fifo_din_3,fifo_din_4;
	reg [`DATA_ACT_WIDTH-1:0] fifo_din_5,fifo_din_6,fifo_din_7,fifo_din_8;
	wire[`DATA_ACT_WIDTH-1:0] fifo_dout[7:0];
	wire[9 :0] data_dcnt_1, data_dcnt_5;
	reg [31:0] total_dout_cnt;

	reg switch_wr=0, switch_rd=0, fifo_we_ping, fifo_we_pong, r_data_ready = 0;

	localparam IDLE         = 1;
	localparam DATACYCLE    = 2;

	reg [2:0]   c_state, n_state;
	reg [2:0]   config_cnt;
	reg [31:0]  total_len;

	assign status_dmux = c_state;

	always @(posedge clk) begin
		if (~rst_n) c_state <= IDLE ;
		else c_state <= n_state ;
	end

	always @ (*) begin
		case(c_state)
			IDLE: begin
				n_state = (config_cnt==2) ? DATACYCLE:IDLE ;
			end

			DATACYCLE : begin
				n_state = ((act_valid & act_ready)&(total_dout_cnt + 1 == total_len)) ? IDLE: DATACYCLE;
			end

			default: n_state = IDLE ;
		endcase
	end

	always @(posedge clk) begin
		case (n_state)
			IDLE: begin
				cycle_len      <= 16'd8;
				cycle_offset   <= 16'd0;
				fifo_we_ping   <= 1'b0;
				fifo_we_pong   <= 1'b0;
				total_dout_cnt <= 'd0;

				if (s_config_ready & s_config_valid) begin
					config_cnt <= config_cnt + 1'b1 ;
					case (config_cnt)
						0: {img_h,img_w} <= s_config_data ;
						1: begin
							s_config_ready <= 1'b0 ;
							total_len  <= s_config_data ;
						end
					endcase
				end
				else begin
					config_cnt<='d0;
					s_config_ready <= 1'b1 ;
				end

			end

			DATACYCLE:begin
				r_data_ready <= 1'b1 ;
				config_cnt   <= 'd0  ;

				if (switch_wr == `PING) begin
					fifo_we_ping <= s_data_valid & s_data_ready;
					fifo_we_pong <= 0;
					fifo_din_1 <= s_data[48+`DATA_ACT_WIDTH-1 : 48];
					fifo_din_2 <= s_data[32+`DATA_ACT_WIDTH-1 : 32];
					fifo_din_3 <= s_data[16+`DATA_ACT_WIDTH-1 : 16];
					fifo_din_4 <= s_data[0 +`DATA_ACT_WIDTH-1 : 0];
					cycle_offset   <= 4;
				end
				else if (switch_wr == `PONG) begin
					fifo_we_ping <= 0;
					fifo_we_pong <= s_data_valid & s_data_ready;
					fifo_din_5 <= s_data[48+`DATA_ACT_WIDTH-1 : 48];
					fifo_din_6 <= s_data[32+`DATA_ACT_WIDTH-1 : 32];
					fifo_din_7 <= s_data[16+`DATA_ACT_WIDTH-1 : 16];
					fifo_din_8 <= s_data[0 +`DATA_ACT_WIDTH-1 : 0];
					cycle_offset   <= 0;
				end

				if(act_valid & act_ready)begin
					if (total_dout_cnt + 1 < total_len) begin
						total_dout_cnt <= total_dout_cnt + 'd1 ;
					end
					else begin
						total_dout_cnt <= 'd0;
					end
				end
			end

		endcase
	end

	always @ (posedge clk) begin
		if (~rst_n) switch_wr <= `PING;
		else if (s_data_valid & s_data_ready) begin
			pix <= (cycle_len-cycle_offset <= 4) ?
				pix==img_w-1 ? 0 : pix + 1'b1
				: pix;
			switch_wr <= ~switch_wr;
		end
	end

	wire fifo_rd_ping, fifo_rd_pong;
	wire fifo_prog_full_ping, fifo_prog_full_pong;
	wire fifo_valid_1, fifo_valid_5;

	assign s_data_ready = (~fifo_prog_full_ping) & (~fifo_prog_full_pong) & r_data_ready;
	assign fifo_rd_ping = act_ready & (~switch_rd) ;
	assign fifo_rd_pong = act_ready & switch_rd;

	assign act_valid    = switch_rd ? fifo_valid_5 : fifo_valid_1;
	assign act_data_1   = switch_rd ? fifo_dout[4] : fifo_dout[0];
	assign act_data_2   = switch_rd ? fifo_dout[5] : fifo_dout[1];
	assign act_data_3   = switch_rd ? fifo_dout[6] : fifo_dout[2];
	assign act_data_4   = switch_rd ? fifo_dout[7] : fifo_dout[3];
	assign act_dcnt     = switch_rd ? data_dcnt_5  : data_dcnt_1 ;

	reg [11:0] dout_cnt ;

	always @(posedge clk) begin
		if(s_config_ready & s_config_valid) dout_cnt <= 12'd0 ;
		else if (act_ready & act_valid)begin
			if (dout_cnt == img_w-1) dout_cnt <= 12'd0 ;
			else dout_cnt <= dout_cnt + 1'b1 ;
		end
	end

	always @(posedge clk) begin
		if(s_config_ready & s_config_valid) switch_rd <= 1'd0 ;
		else if ((act_ready & act_valid)&(dout_cnt == img_w-1)) switch_rd <= ~switch_rd;
	end

	fifo_w8_d512_fwft fifo_1 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_1),                  // input wire [11 : 0] din
		.wr_en(fifo_we_ping),              // input wire wr_en
		.rd_en(fifo_rd_ping),              // input wire rd_en
		.dout(fifo_dout[0]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.valid(fifo_valid_1),            // output wire valid
		.data_count(data_dcnt_1),          // output wire [9 : 0] data_count
		.prog_full(fifo_prog_full_ping)
	);

	fifo_w8_d512_fwft fifo_2 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_2),                  // input wire [11 : 0] din
		.wr_en(fifo_we_ping),              // input wire wr_en
		.rd_en(fifo_rd_ping),              // input wire rd_en
		.dout(fifo_dout[1]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.data_count(),          // output wire [9 : 0] data_count
		.prog_full()
	);

	fifo_w8_d512_fwft fifo_3 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_3),                  // input wire [11 : 0] din
		.wr_en(fifo_we_ping),              // input wire wr_en
		.rd_en(fifo_rd_ping),              // input wire rd_en
		.dout(fifo_dout[2]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.data_count(),          // output wire [9 : 0] data_count
		.prog_full()
	);

	fifo_w8_d512_fwft fifo_4 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_4),                  // input wire [11 : 0] din
		.wr_en(fifo_we_ping),              // input wire wr_en
		.rd_en(fifo_rd_ping),              // input wire rd_en
		.dout(fifo_dout[3]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.data_count(),          // output wire [9 : 0] data_count
		.prog_full()
	);

	fifo_w8_d512_fwft fifo_5 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_5),                  // input wire [11 : 0] din
		.wr_en(fifo_we_pong),              // input wire wr_en
		.rd_en(fifo_rd_pong),              // input wire rd_en
		.dout(fifo_dout[4]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.valid(fifo_valid_5),            // output wire valid
		.data_count(data_dcnt_5),          // output wire [9 : 0] data_count
		.prog_full(fifo_prog_full_pong)
	);

	fifo_w8_d512_fwft fifo_6 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_6),                  // input wire [11 : 0] din
		.wr_en(fifo_we_pong),              // input wire wr_en
		.rd_en(fifo_rd_pong),              // input wire rd_en
		.dout(fifo_dout[5]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.data_count(),          // output wire [9 : 0] data_count
		.prog_full()
	);

	fifo_w8_d512_fwft fifo_7 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_7),                  // input wire [11 : 0] din
		.wr_en(fifo_we_pong),              // input wire wr_en
		.rd_en(fifo_rd_pong),              // input wire rd_en
		.dout(fifo_dout[6]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.data_count(),          // output wire [9 : 0] data_count
		.prog_full()
	);

	fifo_w8_d512_fwft fifo_8 (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire rst
		.din(fifo_din_8),                  // input wire [11 : 0] din
		.wr_en(fifo_we_pong),              // input wire wr_en
		.rd_en(fifo_rd_pong),              // input wire rd_en
		.dout(fifo_dout[7]),                // output wire [11 : 0] dout
		.full(),                // output wire full
		.empty(),              // output wire empty
		.data_count(),          // output wire [9 : 0] data_count
		.prog_full()
	);

endmodule
