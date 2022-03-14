//
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
// ADD a group of m_act interface
//////////////////////////////////////////////////////////////////////////////////
`include "DEFINE.vh"
`include "SIM_CTRL.vh"
// act repeat config num should be configed

module ACT_Manager (

	input clk,
	input rst_n,

	//config
	input               s_axis_dmconfig_tvalid,
	output reg          s_axis_dmconfig_tready,
	input [31:0]        s_axis_dmconfig_tdata ,

	//act in
	input               s_axis_act_tvalid,
	output              s_axis_act_tready,
	input [127:0]       s_axis_act_tdata,
	input               s_axis_act_tlast,
	input [15:0]        s_axis_act_tkeep,

	//m_axis_s2mm
	output [127:0]      m_axis_s2mm_tdata,
	output reg [15:0]   m_axis_s2mm_tkeep =16'hffff,
	output reg          m_axis_s2mm_tlast = 'd0,
	input               m_axis_s2mm_tready,
	output              m_axis_s2mm_tvalid,

	//s_axis_mm2s
	input       [127:0] s_axis_mm2s_tdata,
	input       [15:0]  s_axis_mm2s_tkeep,
	input               s_axis_mm2s_tlast,
	output              s_axis_mm2s_tready,
	input               s_axis_mm2s_tvalid,

	//m_axis_s2mm_cmd
	input               m_axis_s2mm_cmd_tready,
	output  reg         m_axis_s2mm_cmd_tvalid,
	output  reg [71:0]  m_axis_s2mm_cmd_tdata ,

	//m_axis_mm2s_cmd
	input               m_axis_mm2s_cmd_tready,
	output  reg         m_axis_mm2s_cmd_tvalid,
	output  reg [71:0]  m_axis_mm2s_cmd_tdata ,

	//s_axis_mm2s_sts
	output  reg         s_axis_mm2s_sts_tready = 1,
	input               s_axis_mm2s_sts_tvalid,
	input  [7 :0]       s_axis_mm2s_sts_tdata ,
	input               s_axis_mm2s_sts_tlast ,
	input               s_axis_mm2s_sts_tkeep ,

	//s_axis_s2mm_sts
	output  reg         s_axis_s2mm_sts_tready = 1,
	input               s_axis_s2mm_sts_tvalid,
	input  [7 :0]       s_axis_s2mm_sts_tdata ,
	input               s_axis_s2mm_sts_tlast ,
	input               s_axis_s2mm_sts_tkeep ,

	//act out
	output              m_axis_act_tvalid,
	input               m_axis_act_tready,
	output [63:0]       m_axis_act_tdata,

	output [3:0]        status_act_manager

);

	reg [31:0] debug_cnt = 0 ;

	always @ (posedge clk) begin
		if (m_axis_act_tvalid & m_axis_act_tready) debug_cnt <= debug_cnt + 1 ;
	end

	reg [7:0]   act_tile_num        ;// = 'd4;
	reg [7:0]   act_tile_line_num   ;// = 56/4;
	reg [15:0]  act_line_len        ;// = 56*256/4;
	reg [15:0]  raddr_per_line      ;// = 56*256/4;
	reg [23:0]  raddr_tile_offset   ;//56*56*256*4/4;//4byte per data,4group

	reg [11:0]  act_repeat_num      ;// Dynamic
	reg [11:0]  out_full_repeat_num ;
	reg         workmode;
	reg         act_source;
	reg         init_weight;

	reg [3:0]   w_rsvd ='d0 ;
	reg [3:0]   w_tag  ='d0 ;
	reg         w_drr  ='d0 ;
	reg         w_eof  ='d0 ;
	reg [5:0]   w_dsa  ='d0 ;
	reg         w_type ='d1 ;
	reg [31:0]  w_btt       ;//  ='d3211264 ;//256*56*56*4
	reg [31:0]  w_addr      ;// ='h8000_0000 ;

	reg [3:0]   r_rsvd ='d0 ;
	reg [3:0]   r_tag  ='d0 ;
	reg         r_drr  ='d0 ;
	reg         r_eof  ='d1 ;
	reg [5:0]   r_dsa  ='d0 ;
	reg         r_type ='d1 ;
	reg [22:0]  r_btt       ;//  ='d3211264/4 ;//256*56*56*4 here I have changed
	reg [31:0]  r_addr      ;//='h8000_0000 ;

	wire[71:0] w_cmd, r_cmd, w_cmd_overflow;
	assign w_cmd = {w_rsvd,w_tag,w_addr,w_drr,w_eof,w_dsa,w_type,w_btt[22:0]};
	assign w_cmd_overflow = {w_rsvd,w_tag,w_addr,w_drr,w_eof,w_dsa,w_type,{1'b1,22'b0}};
	assign r_cmd = {r_rsvd,r_tag,r_addr,r_drr,r_eof,r_dsa,r_type,r_btt};

	reg s_axis_act_tready_ctrl;

	assign s_axis_act_tready = s_axis_act_tready_ctrl & m_axis_s2mm_tready;
	assign m_axis_s2mm_tvalid = s_axis_act_tready_ctrl & s_axis_act_tvalid;
	assign m_axis_s2mm_tdata  = s_axis_act_tdata;

	reg s_axis_mm2s_tready_ctrl = 0;

	reg [3:0] config_cnt = 'd0 ;
	reg sub_flag;

	wire  act_we;
	wire [127:0] act_dout;
	reg act_ram_valid_pre1,act_ram_valid_pre2,act_ram_valid;

	reg [31:0] wdata_cnt  ;
	reg [31:0] rdata_cnt  ;
	reg [31:0] pakage_len ;
	reg [7 :0] cycle_cnt  ;
	reg [11:0] dout_repeat_cnt;
	reg [16:0] raddr_offset = 0;
	reg [7 :0] line_cnt;
	reg [7 :0] full_repeat_cnt;

	wire act_out_prog_full ;
	assign s_axis_mm2s_tready = s_axis_mm2s_tready_ctrl;

	reg [3:0] cs;
	reg [3:0] ns;

	assign status_act_manager = cs ;

/************************************ Activation block ram. ***************************************/
	wire[15:0] act_waddr;
	reg [15:0] act_raddr;

	assign act_we   = s_axis_mm2s_tvalid & s_axis_mm2s_tready;
	assign act_waddr = rdata_cnt[15:0];

	act_blkram act_blkram (
		.clka(clk),
		.clkb(clk),
		.rstb(~rst_n),
		.wea(act_we),
		.addra(act_waddr),
		.addrb(act_raddr),
		.dina(s_axis_mm2s_tdata),
		.doutb(act_dout)
	);

/**************************************************************************************************/

	localparam IDLE             = 0;
	localparam W_config         = 1;
	localparam W_data           = 2;
	localparam R_config         = 3;
	localparam R_data           = 4;
	localparam R_dout_repeat    = 5;
	localparam R_data_cycle     = 6;
	localparam END              = 7;
	localparam FULL_REPEAT      = 8;


	always @ (posedge clk) begin
		if (~rst_n) cs <= IDLE ;
		else cs <= ns;
	end


	//! fsm_extract
	always @ (*) begin
		if (~rst_n) ns = IDLE ;
		else begin
			case (cs)
				IDLE: if(config_cnt == 8 & ~init_weight)begin
					if (act_source == `DDR) ns = R_config;
					else ns = W_config;
				end
				else ns = IDLE ;

				W_config: begin
					if (m_axis_s2mm_cmd_tvalid & m_axis_s2mm_cmd_tready) ns = W_data ;
					else ns = W_config ;
				end

				W_data: begin
					if ((wdata_cnt == pakage_len) & s_axis_s2mm_sts_tvalid & s_axis_s2mm_sts_tready)
						ns = R_config ;
					else if ((wdata_cnt[17:0]=='h3ffff) & (s_axis_act_tready & s_axis_act_tvalid)) begin
						ns = W_config ;
					end
					else ns = W_data ;
				end

				R_config: begin
					if (m_axis_mm2s_cmd_tvalid & m_axis_mm2s_cmd_tready) ns = R_data ;
					else ns = R_config ;
				end

				R_data: begin
					if (rdata_cnt * act_tile_num == pakage_len) ns = R_dout_repeat ;
					else ns = R_data ;
				end

				R_dout_repeat: begin
					if (line_cnt == act_tile_line_num)begin
						case(workmode)
							0:begin
								ns = R_data_cycle ;//
							end

							1:begin
								ns = FULL_REPEAT ;//
							end

						endcase
					end
					else ns = R_dout_repeat ;
				end

				R_data_cycle: begin
					if (cycle_cnt == act_tile_num) ns = END ;//here should change to config len
					else ns = R_config ;
				end

				FULL_REPEAT: begin
					if (full_repeat_cnt < out_full_repeat_num) ns = R_dout_repeat;
					else ns = END;
				end

				END: ns = IDLE ;
				
				default: ns = IDLE ;
			endcase
		end
	end


	always @(posedge clk ) begin
		case (ns)
			IDLE: begin
				m_axis_s2mm_cmd_tvalid  <= 'd0;
				m_axis_mm2s_cmd_tvalid  <= 'd0;
				s_axis_act_tready_ctrl  <= 'd0;
				cycle_cnt               <= 'd0;
				s_axis_mm2s_tready_ctrl <= 'd0;
				wdata_cnt               <= 'd0 ;
				full_repeat_cnt         <= 'd0;
				sub_flag                <= 'd0;

				if (s_axis_dmconfig_tvalid & s_axis_dmconfig_tready) begin
					config_cnt <= config_cnt + 1'b1 ;
				end

				case (config_cnt)
					0: {act_line_len, act_tile_line_num, act_tile_num} <= s_axis_dmconfig_tdata ;
					1: w_btt  <= s_axis_dmconfig_tdata ;
					2: w_addr <= s_axis_dmconfig_tdata ;
					3: r_btt  <= s_axis_dmconfig_tdata[22:0] ;
					4: r_addr <= s_axis_dmconfig_tdata ;
					5: begin
						raddr_per_line <= s_axis_dmconfig_tdata[15:0] ;
						out_full_repeat_num <= s_axis_dmconfig_tdata[23:16] ;
						workmode   <= s_axis_dmconfig_tdata[24];
						act_source <= s_axis_dmconfig_tdata[25];
            init_weight <= s_axis_dmconfig_tdata[26];
					end
					6: raddr_tile_offset <= s_axis_dmconfig_tdata[23:0] ;
					7: act_repeat_num <= s_axis_dmconfig_tdata;
				endcase

				if (config_cnt >= 7) s_axis_dmconfig_tready  <= 'd0;
				else s_axis_dmconfig_tready  <= 'd1;

				if (config_cnt == 8 & init_weight) config_cnt <= 0;

				//TEMP
				pakage_len <= w_btt >> 4 ;

			end

			W_config: begin
				m_axis_s2mm_cmd_tvalid  <= 'd1 ;
				m_axis_mm2s_cmd_tvalid  <= 'd0 ;
				m_axis_mm2s_cmd_tdata   <= 'd0 ;
				s_axis_mm2s_tready_ctrl <= 'd0 ;
				s_axis_act_tready_ctrl  <= 'd0 ;
				rdata_cnt               <= 'd0 ;
				s_axis_dmconfig_tready  <= 'd0 ;

				if (s_axis_act_tready & s_axis_act_tvalid) wdata_cnt <= wdata_cnt + 1'b1 ;

				if((w_btt > {1'b1,22'd0}) & (~sub_flag)) begin
					m_axis_s2mm_cmd_tdata   <=  w_cmd_overflow;
					w_addr                  <=  w_addr + {1'b1,22'd0};
					w_btt                   <=  w_btt - {1'b1,22'd0};
					sub_flag                <=  1;
				end
				else m_axis_s2mm_cmd_tdata   <=  w_cmd;

			end

			W_data: begin
				m_axis_s2mm_cmd_tvalid <= 'd0;
				m_axis_s2mm_cmd_tdata  <= 'd0;
				sub_flag               <= 'd0;

				s_axis_act_tready_ctrl <= 'd1 ;
				if (s_axis_act_tready & s_axis_act_tvalid) wdata_cnt <= wdata_cnt + 1'b1 ;
			end

			R_config: begin
				m_axis_mm2s_cmd_tvalid <= 'd1;
				m_axis_mm2s_cmd_tdata  <= r_cmd;
				s_axis_act_tready_ctrl <= 'd0 ;
				wdata_cnt    <= 'd0 ;
				dout_repeat_cnt <= 'd0;
				line_cnt     <= 'd0;
				act_ram_valid_pre1 <= 0;
				act_raddr<= $signed (-1) ;
				raddr_offset <= 'd0 ;
			end

			R_data: begin
				m_axis_mm2s_cmd_tvalid <= 'd0;
				s_axis_mm2s_tready_ctrl<= 'd1;
				if (s_axis_mm2s_tvalid & s_axis_mm2s_tready) rdata_cnt <= rdata_cnt + 1'b1 ;
				act_ram_valid_pre1 <= 0;
			end

			R_dout_repeat : begin
				s_axis_mm2s_tready_ctrl<= 'd0;
				rdata_cnt              <= 'd0 ;

				if (~act_out_prog_full) begin
					if (act_raddr + 1 == act_line_len + raddr_offset) begin
						if (dout_repeat_cnt + 1 == act_repeat_num) begin
							act_raddr <= raddr_offset + raddr_per_line ;
							raddr_offset <= raddr_offset + raddr_per_line ;
							dout_repeat_cnt <= 'd0;

							line_cnt <= line_cnt + 1 ;

							if (line_cnt + 1 == act_tile_line_num) act_ram_valid_pre1 <= 0;
							else act_ram_valid_pre1 <= 1;
						end
						else begin
							act_raddr <= raddr_offset;
							dout_repeat_cnt <= dout_repeat_cnt + 1;
							act_ram_valid_pre1 <= 1;
						end
					end

					else begin
						act_raddr <= act_raddr + 1 ;
						act_ram_valid_pre1 <= 1;
					end
				end
				else act_ram_valid_pre1 <= 0;

			end

			R_data_cycle: begin
				s_axis_mm2s_tready_ctrl <= 'd0;
				rdata_cnt               <= 'd0 ;
				cycle_cnt               <= cycle_cnt + 1'b1 ;

				r_addr                  <= r_addr + raddr_tile_offset;
				act_raddr               <= $signed (-1) ;
			end

			END: begin
				s_axis_mm2s_tready_ctrl <= 'd0;
				rdata_cnt               <= 'd0 ;
				config_cnt              <= 'd0 ;
			end

			FULL_REPEAT: begin
				s_axis_act_tready_ctrl <= 'd0 ;
				rdata_cnt    <= 'd0 ;
				dout_repeat_cnt <= 'd0;
				cycle_cnt    <= 'd0;
				line_cnt     <= 'd0;
				act_ram_valid_pre1 <= 0;
				act_raddr<= $signed (-1) ;
				raddr_offset <= 'd0 ;
				full_repeat_cnt <= full_repeat_cnt + 1'b1 ;
			end

		endcase
	end


	always @ (posedge clk) begin
		act_ram_valid_pre2 <= act_ram_valid_pre1 ; 
		act_ram_valid <= act_ram_valid_pre2 ; 
	end

	wire [63:0] fifo_dout;
	wire [15:0] act_out1, act_out2, act_out3, act_out4;

	fifo_i128_o64 fifo_act_out (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire srst
		.din(act_dout),    // input wire [127 : 0] din
		.wr_en(act_ram_valid),              // input wire wr_en
		.rd_en(m_axis_act_tready),  // input wire rd_en
		.dout(fifo_dout),                // output wire [63 : 0] dout
		.valid(m_axis_act_tvalid),
		.full(),                // output wire full
		.empty(),              // output wire empty
		.prog_full(act_out_prog_full),      // output wire prog_full
		.wr_rst_busy(),  // output wire wr_rst_busy
		.rd_rst_busy()  // output wire rd_rst_busy
	);

	//assign act_out4 = {{6{fifo_dout[11]}},fifo_dout[11: 0]};
	//assign act_out3 = {{6{fifo_dout[27]}},fifo_dout[27:16]};
	//assign act_out2 = {{6{fifo_dout[43]}},fifo_dout[43:32]};
	//assign act_out1 = {{6{fifo_dout[59]}},fifo_dout[59:48]};
	assign act_out4 = {{12{fifo_dout[`DATA_ACT_WIDTH-1 ]}},fifo_dout[`DATA_ACT_WIDTH-1 : 0]};
	assign act_out3 = {{12{fifo_dout[`DATA_ACT_WIDTH+15]}},fifo_dout[`DATA_ACT_WIDTH+15:16]};
	assign act_out2 = {{12{fifo_dout[`DATA_ACT_WIDTH+31]}},fifo_dout[`DATA_ACT_WIDTH+31:32]};
	assign act_out1 = {{12{fifo_dout[`DATA_ACT_WIDTH+47]}},fifo_dout[`DATA_ACT_WIDTH+47:48]};

	assign m_axis_act_tdata = {act_out1, act_out2, act_out3, act_out4};

endmodule
