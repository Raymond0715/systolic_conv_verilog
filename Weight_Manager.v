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

module Weight_Manager (
	input clk,
	input rst_n,

	//config
	input               s_axis_wmconfig_tvalid,
	output reg          s_axis_wmconfig_tready,
	input [31:0]        s_axis_wmconfig_tdata ,

	//weight in
	input               s_axis_weight_tvalid,
	output              s_axis_weight_tready,
	input [127:0]       s_axis_weight_tdata,
	input               s_axis_weight_tlast,
	input [15:0]        s_axis_weight_tkeep,

	//m_axis_s2mm
	output [127:0]      m_axis_weight_s2mm_tdata,
	output reg [15:0]   m_axis_weight_s2mm_tkeep =16'hffff,
	output reg          m_axis_weight_s2mm_tlast = 'd0,
	input               m_axis_weight_s2mm_tready,
	output              m_axis_weight_s2mm_tvalid,

	//s_axis_mm2s
	input       [127:0] s_axis_weight_mm2s_tdata,
	input       [15:0]  s_axis_weight_mm2s_tkeep,
	input               s_axis_weight_mm2s_tlast,
	output              s_axis_weight_mm2s_tready,
	input               s_axis_weight_mm2s_tvalid,

	//m_axis_s2mm_cmd
	input               m_axis_weight_s2mm_cmd_tready,
	output  reg         m_axis_weight_s2mm_cmd_tvalid,
	output  reg [71:0]  m_axis_weight_s2mm_cmd_tdata ,

	//m_axis_mm2s_cmd
	input               m_axis_weight_mm2s_cmd_tready,
	output  reg         m_axis_weight_mm2s_cmd_tvalid,
	output  reg [71:0]  m_axis_weight_mm2s_cmd_tdata ,

	//s_axis_mm2s_sts
	output  reg         s_axis_weight_mm2s_sts_tready = 1,
	input               s_axis_weight_mm2s_sts_tvalid,
	input  [7 :0]       s_axis_weight_mm2s_sts_tdata ,
	input               s_axis_weight_mm2s_sts_tlast ,
	input               s_axis_weight_mm2s_sts_tkeep ,

	//s_axis_s2mm_sts
	output  reg         s_axis_weight_s2mm_sts_tready = 1,
	input               s_axis_weight_s2mm_sts_tvalid,
	input  [7 :0]       s_axis_weight_s2mm_sts_tdata ,
	input               s_axis_weight_s2mm_sts_tlast ,
	input               s_axis_weight_s2mm_sts_tkeep ,

	//weight_out
	output              m_axis_weight_tvalid,
	output [127:0]      m_axis_weight_tdata ,
	input               m_axis_weight_tready,

	output [3:0]        status_wm

);

	reg         weight_source;

	reg [3:0]   w_rsvd ='d0 ;
	reg [3:0]   w_tag  ='d0 ;
	reg         w_drr  ='d0 ;
	reg         w_eof  ='d0 ;
	reg [5:0]   w_dsa  ='d0 ;
	reg         w_type ='d1 ;
	reg [32:0]  w_btt       ;
	reg [31:0]  w_addr      ;

	reg [3:0]   r_rsvd ='d0 ;
	reg [3:0]   r_tag  ='d0 ;
	reg         r_drr  ='d0 ;
	reg         r_eof  ='d1 ;
	reg [5:0]   r_dsa  ='d0 ;
	reg         r_type ='d1 ;
	reg [31:0]  r_btt       ;
	reg [31:0]  r_addr      ;

	wire[71:0] w_cmd, r_cmd, w_cmd_overflow, r_cmd_overflow ;
	assign w_cmd = {w_rsvd,w_tag,w_addr,w_drr,w_eof,w_dsa,w_type,w_btt[22:0]};
	assign w_cmd_overflow = {w_rsvd,w_tag,w_addr,w_drr,w_eof,w_dsa,w_type,{1'b1,22'b0}};
	assign r_cmd = {r_rsvd,r_tag,r_addr,r_drr,r_eof,r_dsa,r_type,r_btt[22:0]};
	assign r_cmd_overflow = {r_rsvd,r_tag,r_addr,r_drr,r_eof,r_dsa,r_type,{1'b1,22'b0}};


	reg s_axis_weight_mm2s_tready_ctrl;
	reg s_axis_weight_tready_ctrl;

	assign m_axis_weight_s2mm_tvalid = s_axis_weight_tready_ctrl & s_axis_weight_tvalid;
	assign m_axis_weight_s2mm_tdata  = s_axis_weight_tdata;
	assign s_axis_weight_tready = s_axis_weight_tready_ctrl & m_axis_weight_s2mm_tready;

	assign m_axis_weight_tdata = s_axis_weight_mm2s_tdata;
	assign m_axis_weight_tvalid = s_axis_weight_mm2s_tvalid & s_axis_weight_mm2s_tready_ctrl;
	assign s_axis_weight_mm2s_tready = m_axis_weight_tready & s_axis_weight_mm2s_tready_ctrl;


	reg [3:0] config_cnt ;
	reg [24:0] weight_len;
	reg [31:0] pakage_len;
	reg [31:0] wdata_cnt  ;
	reg [31:0] rdata_cnt  ;
	reg wr_sub_flag, rd_sub_flag;


	localparam IDLE             = 0;
	localparam W_config         = 1;
	localparam W_data           = 2;
	localparam R_config         = 3;
	localparam R_data           = 4;
	localparam END              = 7;

	reg [3:0] cs;
	reg [3:0] ns;

	assign status_wm = cs;


	always @ (posedge clk) begin
		if (~rst_n) cs <= IDLE ;
		else cs <= ns;
	end


	//! fsm_extract
	always @ (*) begin
		if (~rst_n) ns = IDLE ;
		else begin
			case (cs)
				IDLE: if(config_cnt == 4)begin if (weight_source == `DDR) ns = R_config;
					else ns = W_config;
				end
				else ns = IDLE ;

				W_config: begin
					if (m_axis_weight_s2mm_cmd_tvalid & m_axis_weight_s2mm_cmd_tready) ns = W_data ;
					else ns = W_config ;
				end

				W_data: begin
					if ((wdata_cnt+1 >= pakage_len) & m_axis_weight_s2mm_tready & m_axis_weight_s2mm_tvalid)
						ns = R_config ;
					else if ((wdata_cnt[17:0]=='h3ffff)
							& (m_axis_weight_s2mm_tready & m_axis_weight_s2mm_tvalid)) begin
						ns = W_config ;
					end
					else ns = W_data ;
				end

				R_config: begin
					if (m_axis_weight_mm2s_cmd_tvalid & m_axis_weight_mm2s_cmd_tready) ns = R_data ;
					else ns = R_config ;
				end

				R_data: begin
					if ((rdata_cnt+1 >= pakage_len) & s_axis_weight_mm2s_tready & s_axis_weight_mm2s_tvalid)
						ns = END ;
					else if ((rdata_cnt[17:0]=='h3ffff) & (s_axis_weight_mm2s_tready
							& s_axis_weight_mm2s_tvalid)) begin
						ns = R_config ;
					end
					else ns = R_data ;
				end
				
				END: ns = IDLE ;
				
				default: ns = IDLE ;
			endcase
		end
	end


	always @(posedge clk ) begin
		if(~rst_n) begin
			config_cnt <= 'd0 ;
		end
		else begin
			case (ns)
				IDLE: begin
					m_axis_weight_s2mm_cmd_tvalid  <= 'd0;
					m_axis_weight_mm2s_cmd_tvalid  <= 'd0;
					s_axis_weight_tready_ctrl      <= 'd0;
					s_axis_weight_mm2s_tready_ctrl <= 'd0;
					wdata_cnt <= 'd0;
					rdata_cnt <= 'd0;
					wr_sub_flag  <= 'd0;
					rd_sub_flag  <= 'd0;

					if (s_axis_wmconfig_tvalid & s_axis_wmconfig_tready) begin
						config_cnt <= config_cnt + 1'b1;
					end

					case (config_cnt)
						0: begin
							weight_len <= s_axis_wmconfig_tdata[24:0];
							r_btt      <= {s_axis_wmconfig_tdata[24:0],1'b0};
							weight_source <= s_axis_wmconfig_tdata[25];
						end
						1: begin
							w_addr <= s_axis_wmconfig_tdata;
						end
						2: begin
							r_addr <= s_axis_wmconfig_tdata;
						end
						3: begin
							w_btt       <= {s_axis_wmconfig_tdata,1'b0};
							pakage_len  <= s_axis_wmconfig_tdata >> 3; //byte(bus16) to bus128 
						end
					endcase

					if (config_cnt >= 3) s_axis_wmconfig_tready  <= 'd0;
					else s_axis_wmconfig_tready  <= 'd1;
				end

				W_config: begin
					m_axis_weight_s2mm_cmd_tvalid  <= 'd1;
					m_axis_weight_mm2s_cmd_tvalid  <= 'd0;
					m_axis_weight_mm2s_cmd_tdata   <= 'd0;
					s_axis_weight_mm2s_tready_ctrl <= 'd0;
					s_axis_weight_tready_ctrl      <= 'd0;
					rdata_cnt               <= 'd0;
					s_axis_wmconfig_tready  <= 'd0;

					if (m_axis_weight_s2mm_tready & m_axis_weight_s2mm_tvalid) wdata_cnt <= wdata_cnt + 1'b1;

					if((w_btt > {1'b1,22'd0}) & (~wr_sub_flag)) begin
						m_axis_weight_s2mm_cmd_tdata <=  w_cmd_overflow;
						w_addr                       <=  w_addr + {1'b1,22'd0};
						w_btt                        <=  w_btt - {1'b1,22'd0};
						wr_sub_flag                  <=  1;
					end
					else m_axis_weight_s2mm_cmd_tdata <=  w_cmd;

				end

				W_data: begin
					m_axis_weight_s2mm_cmd_tvalid <= 'd0;
					m_axis_weight_s2mm_cmd_tdata  <= 'd0;
					wr_sub_flag               <= 'd0;

					s_axis_weight_tready_ctrl <= 'd1;
					if (m_axis_weight_s2mm_tready & m_axis_weight_s2mm_tvalid) wdata_cnt <= wdata_cnt + 1'b1;
				end

				R_config: begin
					m_axis_weight_mm2s_cmd_tvalid <= 'd1;
					s_axis_weight_tready_ctrl     <= 'd0;

					if((r_btt > {1'b1,22'd0}) & (~rd_sub_flag)) begin
						m_axis_weight_mm2s_cmd_tdata    <=  r_cmd_overflow;
						r_addr                          <=  r_addr + {1'b1,22'd0};
						r_btt                           <=  r_btt - {1'b1,22'd0};
						rd_sub_flag                     <=  1;
					end
					else m_axis_weight_mm2s_cmd_tdata   <=  r_cmd;

					if (s_axis_weight_mm2s_tvalid & s_axis_weight_mm2s_tready) rdata_cnt <= rdata_cnt + 1'b1;
				end

				R_data: begin
					m_axis_weight_mm2s_cmd_tvalid <= 'd0;
					s_axis_weight_mm2s_tready_ctrl<= 'd1;
					if (s_axis_weight_mm2s_tvalid & s_axis_weight_mm2s_tready) rdata_cnt <= rdata_cnt + 1'b1;
					rd_sub_flag <= 'd0;
					config_cnt  <= 'd0;
				end

			endcase

		end
	end


	integer handle5 ;
	initial handle5=$fopen("../PRINT/weight_write.txt");
	always @ (posedge clk) begin
		if (m_axis_weight_s2mm_tvalid&m_axis_weight_s2mm_tready) begin
			$fdisplay(handle5,"%h",m_axis_weight_s2mm_tdata);
		end
	end


	integer handle6;
	initial handle6=$fopen("../PRINT/weight_read.txt");
	always @ (posedge clk) begin
		if (s_axis_weight_mm2s_tvalid&s_axis_weight_mm2s_tready) begin
			$fdisplay(handle6,"%h",s_axis_weight_mm2s_tdata);
		end
	end

endmodule
