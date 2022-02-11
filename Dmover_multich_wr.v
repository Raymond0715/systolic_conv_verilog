
`timescale 1ns/1ps

module Dmover_multich_wr (
	input clk   ,
	input rst_n ,

	//config
	input   [31:0]      s_axis_dmwconfig_tdata  ,
	input               s_axis_dmwconfig_tvalid ,
	output  reg         s_axis_dmwconfig_tready ,

	//data_in
	input   [127:0]     s_axis_dmw_tdata    ,
	input               s_axis_dmw_tvalid   ,
	output              s_axis_dmw_tready   ,

	//m_axis_s2mm_cmd
	input               m_axis_s2mm_cmd_tready  ,
	output  reg [71:0]  m_axis_s2mm_cmd_tdata   ,
	output  reg         m_axis_s2mm_cmd_tvalid  ,

	//s_axis_s2mm_sts
	input   [7:0]       s_axis_s2mm_sts_tdata   ,
	input               s_axis_s2mm_sts_tvalid  ,
	input               s_axis_s2mm_sts_tlast   ,
	input               s_axis_s2mm_sts_tkeep   ,
	output  reg         s_axis_s2mm_sts_tready = 1  ,
	
	// DDR data output
	input               m_axis_dmw_tready   ,
	output      [127:0] m_axis_dmw_tdata    ,
	output              m_axis_dmw_tvalid   ,
	output  reg         m_axis_dmw_tlast = 1'b0    ,
	output  reg [15:0]  m_axis_dmw_tkeep = 16'hffff ,
	
	// SDK data output
	input               m_axis_output2ps_tready,
	output     [127:0]  m_axis_output2ps_tdata,
	output              m_axis_output2ps_tvalid,
	output reg          m_axis_output2ps_tlast,
	output reg [15:0]   m_axis_output2ps_tkeep = 16'hffff,
	
	output     [3:0]    status_dmw

);

	reg [3:0]   w_rsvd ='d0;
	reg [3:0]   w_tag ='d0;
	reg         w_drr ='d0;
	reg         w_eof ='d0;
	reg [5:0]   w_dsa ='d0;
	reg         w_type ='d1;
	wire[22:0]  w_btt;
	reg [31:0]  w_addr; // ='h8000_0000 ;

	wire [71:0] w_cmd;
	assign w_cmd = {w_rsvd, w_tag, w_addr, w_drr, w_eof, w_dsa, w_type, w_btt};


	reg [15:0]  len_unit ;
	reg [7 :0]  w_tile;
	reg [15:0]  chout_perwtile;
	reg [11:0]  chout_group_perwram;
	reg [11:0]  img_w, img_h;
	reg [31:0]  act_len;
	reg         switch_sampling;
	reg         output_sink;

	reg [15:0]    cnt_channel;
	reg [15:0]    cnt_package;
	reg [31:0]    cnt_unit;
	reg [31:0]    cnt_sdk_data;
	reg [7 :0]    cnt_tile;

	reg [22:0]   addr_unit;
	reg [31:0]   addr_base;

	reg [31:0]   channel_shift;

	reg [2:0]   config_cnt;
	reg         cal_over;
	reg         s_axis_dmw_tready_en;

	// DDR output
	// Ready singal for post data 
	assign s_axis_dmw_tready = (s_axis_dmw_tready_en & m_axis_dmw_tready) | m_axis_output2ps_tready ;
	// Valid signal for DDR datamover.
	assign m_axis_dmw_tvalid = ~output_sink & s_axis_dmw_tready_en & s_axis_dmw_tvalid ;
	assign m_axis_dmw_tdata = s_axis_dmw_tdata ;

	// SDK output
	assign m_axis_output2ps_tvalid = output_sink & s_axis_dmw_tvalid;
	assign m_axis_output2ps_tdata = s_axis_dmw_tdata;

	assign w_btt = addr_unit;

	reg [2:0]   c_state   ;
	reg [2:0]   n_state   ;

	assign status_dmw = c_state;

	localparam CONFIG           = 3'b000    ;

	// Calculate parameters(initial_addr, offset_addr...) which will be used
	localparam PARA_CAL         = 3'b001    ;

	// Config Datamover
	localparam DMOVER_CONFIG    = 3'b011    ;

	//Write a package of Data to Datamover
	localparam DMOVER_WR        = 3'b010    ;

	//End FSM, or recalculate wr_addr and back to DMOVER_CONFIG
	localparam ADDR_UPDATE      = 3'b110    ;

	localparam END              = 3'b100    ;
	localparam SDK_OUTPUT       = 3'b101    ;

	always @(posedge clk) begin
		if(~rst_n) begin
			c_state <= END ;
		end
		else begin
			c_state <= n_state  ;
		end
	end

	// FSM: Jump state.
	always @(*) begin
		if(~rst_n) begin
			n_state = END ;
		end
		else begin
			case(c_state)
				CONFIG: begin
					if(config_cnt == 4 & ~output_sink) begin
						n_state = DMOVER_CONFIG;
					end
					else if (config_cnt == 4 & output_sink) begin
						n_state = SDK_OUTPUT;
					end
					else begin
						n_state = CONFIG ;
					end
				end

				DMOVER_CONFIG: begin
					if(m_axis_s2mm_cmd_tvalid & m_axis_s2mm_cmd_tready) begin
						n_state = DMOVER_WR ;
					end
					else begin
						n_state = DMOVER_CONFIG ;
					end
				end

				DMOVER_WR: begin
					if(s_axis_dmw_tvalid & (cnt_unit + 1'b1 == len_unit)) n_state = ADDR_UPDATE;
					else n_state = DMOVER_WR;
				end

				ADDR_UPDATE: begin
					if(cal_over) n_state = END;
					else n_state = DMOVER_CONFIG;
				end

				SDK_OUTPUT: begin
					if (m_axis_output2ps_tlast) n_state = END;
					else n_state = SDK_OUTPUT;
				end

				END: begin
					n_state = CONFIG ;
				end

				default: begin
					n_state = CONFIG ;
				end
			endcase
		end
	end

	// FSM: Set signal.
	always @(posedge clk) begin
		if(~rst_n) begin
			config_cnt             <= 'd0;
			cnt_tile               <= 'd0;
			m_axis_s2mm_cmd_tvalid <= 'd0;
			s_axis_dmw_tready_en   <= 'd0;
			cal_over               <= 'd0;
			cnt_sdk_data           <= 'd0;
			m_axis_output2ps_tlast <= 'd0;
		end else begin
			case(n_state)
				CONFIG: begin
					case (config_cnt)
						0:begin
							s_axis_dmwconfig_tready <= 'd1 ;
							m_axis_s2mm_cmd_tvalid  <= 'd0 ;
							s_axis_dmw_tready_en    <= 'd0 ;
							cnt_channel             <= 'd0 ;
							cnt_unit                <= 'd0 ;
							cnt_package             <= 'd0 ;
							cal_over                <= 'd0 ;

							if (s_axis_dmwconfig_tvalid & s_axis_dmwconfig_tready) begin
								config_cnt  <= config_cnt + 1'b1 ;
								{switch_sampling, output_sink, chout_perwtile, chout_group_perwram} <= 
									s_axis_dmwconfig_tdata ;
							end
						end

						1:begin
							s_axis_dmwconfig_tready <= 1 ;

							if (s_axis_dmwconfig_tvalid & s_axis_dmwconfig_tready) begin
								config_cnt  <= config_cnt + 1'b1 ;
								img_w <= switch_sampling ?
									s_axis_dmwconfig_tdata[11: 1]
									: s_axis_dmwconfig_tdata[11: 0];
								img_h <= switch_sampling ?
									s_axis_dmwconfig_tdata[23:13]
									: s_axis_dmwconfig_tdata[23:12];
								//addr_unit   <= {s_axis_dmwconfig_tdata[11:0],4'b0};
								//each 128bit has 16Bytes,so here mult 16  //len_unit>>3 ;

								w_tile <= s_axis_dmwconfig_tdata[31:24];
							end
						end

						2:begin
							if (s_axis_dmwconfig_tvalid & s_axis_dmwconfig_tready) begin
								s_axis_dmwconfig_tready <= 0 ;
								config_cnt <= config_cnt + 1'b1 ;

								len_unit <= img_w * (chout_perwtile>>3);//bus128
								addr_unit <= img_w * (chout_perwtile<<1);//bytes

								addr_base <= s_axis_dmwconfig_tdata[31:0];
								w_addr <= s_axis_dmwconfig_tdata[31:0];
							end
						end

						3: begin
							act_len <= s_axis_dmwconfig_tdata;
							channel_shift <= addr_unit * w_tile;
							config_cnt <= config_cnt + 1'b1;
						end
					endcase
				end

				DMOVER_CONFIG: begin
					m_axis_s2mm_cmd_tdata  <= w_cmd ;
					m_axis_s2mm_cmd_tvalid <= 1 ;
				end

				DMOVER_WR: begin
					m_axis_s2mm_cmd_tvalid  <= 0 ;
					s_axis_dmw_tready_en    <= 1 ;
					
					if(s_axis_dmw_tvalid && s_axis_dmw_tready) begin
						cnt_unit <= cnt_unit + 1 ;
					end
				end

				ADDR_UPDATE: begin
					s_axis_dmw_tready_en <= 0 ;
					cnt_unit <= 0 ;
					
					if(cnt_package+1 < img_h) begin
						w_addr <= w_addr + channel_shift;
						cnt_package <= cnt_package + 1 ;
					end
					else begin
						cnt_package <= 0 ;

						if(cnt_channel+1 < w_tile) begin
							cnt_channel <= cnt_channel + 1 ;
							addr_base   <= addr_base + addr_unit;
							w_addr      <= addr_base + addr_unit;
						end
						else begin
							cal_over    <= 1'b1;
						end
					end
				end

				SDK_OUTPUT: begin
					if (m_axis_output2ps_tready & m_axis_output2ps_tvalid)
						cnt_sdk_data <= cnt_sdk_data + 'd1;
					if (cnt_sdk_data == act_len)
						m_axis_output2ps_tlast <= 'd1;
					else m_axis_output2ps_tlast <= 'd0;
				end

				END: begin
					cnt_channel            <= 'd0 ;
					cnt_package            <= 'd0 ;
					cnt_unit               <= 'd0 ;
					cnt_tile               <= 'd0 ;
					chout_perwtile         <= 'd0 ;
					chout_group_perwram    <= 'd0 ;
					addr_unit              <= 'd0 ;
					config_cnt             <= 'd0 ;
					m_axis_s2mm_cmd_tvalid <= 'd0 ;
					s_axis_dmw_tready_en   <= 'd0 ;
					cal_over               <= 'd0 ;
					cnt_sdk_data           <= 'd0;
					m_axis_output2ps_tlast <= 'd0;
				end
			endcase
		end
	end

endmodule
