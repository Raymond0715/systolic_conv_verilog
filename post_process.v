`include "DEFINE.vh"
`include "SIM_CTRL.vh"

module post_process (
	input                                       clk             ,
	input                                       rst_n           ,

	input                                       s_axis_ppconfig_tvalid  ,
	output  reg                                 s_axis_ppconfig_tready  ,
	input           [31:0]                      s_axis_ppconfig_tdata   ,

	input                                       s_axis_bias_tvalid  ,
	output                                      s_axis_bias_tready  ,
	input           [127:0]                     s_axis_bias_tdata   ,

	input           [`DATA_INTER_WIDTH*8-1 :0]  reorder_data    ,
	input                                       reorder_valid   ,
	output  reg                                 reorder_ready   ,

	output          [127 :0]                    post_data       ,
	output                                      post_valid      ,
	input                                       post_ready      ,

	//data-mover
	//s_axis_mm2s
	input       [31:0]  s_axis_mm2s_tdata,
	input       [3:0]   s_axis_mm2s_tkeep,
	input               s_axis_mm2s_tlast,
	output  reg         s_axis_mm2s_tready,
	input               s_axis_mm2s_tvalid,

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

	//m_axis_s2mm
	output     [31:0]   m_axis_s2mm_tdata ,//for sim, locked num
	output reg [3:0]    m_axis_s2mm_tkeep =16'hffff,
	output reg          m_axis_s2mm_tlast = 'd0,
	input               m_axis_s2mm_tready,
	output              m_axis_s2mm_tvalid,

	//m_axis_s2mm_cmd
	input               m_axis_s2mm_cmd_tready,
	output  reg         m_axis_s2mm_cmd_tvalid,
	output  reg [71:0]  m_axis_s2mm_cmd_tdata ,

	//s_axis_s2mm_sts
	output  reg         s_axis_s2mm_sts_tready = 1,
	input               s_axis_s2mm_sts_tvalid,
	input  [7 :0]       s_axis_s2mm_sts_tdata ,
	input               s_axis_s2mm_sts_tlast ,
	input               s_axis_s2mm_sts_tkeep ,

	output [3:0]        status_post
);

	wire out_error;
	wire dout_prog_full;

//bias trans
	wire bias_prog_full;
	reg bias_rdy_ctrl;
	assign s_axis_bias_tready = (~bias_prog_full) & bias_rdy_ctrl;

	fifo_w128r32_d512_2k fifo_bias (
		.clk(clk),                  // input wire clk
		.srst(~rst_n),                // input wire srst

		.din(s_axis_bias_tdata),                  // input wire [191 : 0] din
		.wr_en(s_axis_bias_tvalid & s_axis_bias_tready), // input wire wr_en
		.rd_en(m_axis_s2mm_tready),              // input wire rd_en
		.dout(m_axis_s2mm_tdata),                // output wire [23 : 0] dout
		.valid(m_axis_s2mm_tvalid),              // output wire valid
		.prog_full(bias_prog_full),      // output wire prog_full

		.full(),                // output wire full
		.empty(),              // output wire empty
		.wr_rst_busy(),  // output wire wr_rst_busy
		.rd_rst_busy()  // output wire rd_rst_busy
	);


//FSM
	//bias cache
	reg [11:0]      bias_ram_waddr;
	wire[8 :0]      bias_ram_raddr;
	//wire[24*8-1:0]  bias_dout;
	wire[`DATA_INTER_WIDTH*8-1:0]  bias_dout;
	wire bias_we;
	assign bias_we = s_axis_mm2s_tvalid & s_axis_mm2s_tready;

	//ram_i24_o192_d4k_512 ram_bias (
	ram_i16_o128_d4k_512 ram_bias (
		.clka(clk),    // input wire clka
		.wea(bias_we),      // input wire [0 : 0] wea
		.addra(bias_ram_waddr),  // input wire [11 : 0] addra
		.dina(s_axis_mm2s_tdata[`DATA_INTER_WIDTH-1:0]),    // input wire [23 : 0] dina
		.clkb(clk),    // input wire clkb
		.rstb(~rst_n),    // input wire rstb
		.addrb(bias_ram_raddr),  // input wire [11 : 0] addrb
		.doutb(bias_dout)  // output wire [23 : 0] doutb
	);

	reg [3:0] config_cnt;
	reg [15:0]wdata_cnt;
	reg relumode, switch_bias, switch_sampling, switch_relu, switch_bitintercept,
		switch_rowfilter, mode1_1, workmode;
	reg [11:0]  img_h   ;
	reg [11:0]  img_w   ;
	//reg [15:0]  i_ch  ;
	reg [15:0]  o_ch  ;
	reg source;


	reg [15:0] pix_cnt, line_cnt, total_cnt, chout_cnt;
	reg [15:0] line_len, total_len, chout_len, chout_offset; 
	reg cycle_finish ;

	assign bias_ram_raddr = chout_cnt>>3;

	reg [3:0]   r_rsvd ='d0 ;
	reg [3:0]   r_tag  ='d0 ;
	reg         r_drr  ='d0 ;
	reg         r_eof  ='d1 ;
	reg [5:0]   r_dsa  ='d0 ;
	reg         r_type ='d1 ;
	reg [22:0]  r_btt       ;
	reg [31:0]  r_addr      ;

	wire[71:0] r_cmd;
	assign r_cmd = {r_rsvd,r_tag,r_addr,r_drr,r_eof,r_dsa,r_type,r_btt};

	reg [3:0]   w_rsvd ='d0 ;
	reg [3:0]   w_tag  ='d0 ;
	reg         w_drr  ='d0 ;
	reg         w_eof  ='d0 ;
	reg [5:0]   w_dsa  ='d0 ;
	reg         w_type ='d1 ;
	reg [22:0]  w_btt       ;//  ='d3211264 ;//256*56*56*4
	reg [31:0]  w_addr      ;// ='h8000_0000 ;

	wire[71:0]  w_cmd;
	assign w_cmd = {w_rsvd,w_tag,w_addr,w_drr,w_eof,w_dsa,w_type,w_btt};

	localparam IDLE             = 0;
	localparam W_config         = 1;
	localparam W_bias           = 2;
	localparam R_config         = 3;
	localparam R_bias           = 4;
	localparam WORK             = 5;

	reg [3:0] cs;
	reg [3:0] ns;

	assign status_post = cs ;

	always @ (posedge clk) begin
		if (~rst_n) cs <= IDLE ;
		else cs <= ns;
	end


	//! fsm_extract
	always @ (*) begin
		if (~rst_n) ns = IDLE ;
		else begin
			case (cs)
				IDLE: if(config_cnt >= 6)begin
					if(source == `PS)ns = W_config;//`PS
					else ns = R_config;//`DDR
				end
				else ns = IDLE ;

				W_config: begin
					if (m_axis_s2mm_cmd_tvalid & m_axis_s2mm_cmd_tready) ns = W_bias ;
					else ns = W_config ;
				end

				W_bias: begin
					if (s_axis_s2mm_sts_tvalid & s_axis_s2mm_sts_tready) ns = R_config ;////
					else ns = W_bias ;
				end

				R_config: begin
					if (m_axis_mm2s_cmd_tvalid & m_axis_mm2s_cmd_tready) ns = R_bias ;
					else ns = R_config ;
				end

				R_bias: begin
					if ((bias_ram_waddr+1==o_ch) & bias_we) ns = WORK ;
					else ns = R_bias ;
				end

				WORK: begin
					if (cycle_finish) ns = IDLE ;//ch、pix
					else ns = WORK ;
				end

				default: ns = IDLE ;
			endcase
		end
	end


	always @(posedge clk ) begin
		if (~rst_n)begin
			config_cnt <= 'd0;
			m_axis_mm2s_cmd_tvalid  <= 'd0;
			m_axis_s2mm_cmd_tvalid  <= 'd0;
		end
		else begin
			case (ns)
				IDLE: begin
					m_axis_mm2s_cmd_tvalid  <= 'd0;
					m_axis_s2mm_cmd_tvalid  <= 'd0;
					s_axis_mm2s_tready <= 'd0;
					bias_ram_waddr <='d0;
					reorder_ready  <='d0;
					wdata_cnt  <='d0;
					chout_offset<='d0;
					bias_rdy_ctrl <= 'd0;
					cycle_finish  <= 'd0;

					if (s_axis_ppconfig_tvalid & s_axis_ppconfig_tready) begin
						config_cnt <= config_cnt + 1'b1 ;
					end

					case (config_cnt)
						0: begin
							{relumode, switch_bias, switch_sampling, switch_relu,
								switch_bitintercept,switch_rowfilter, mode1_1, workmode } <=
								s_axis_ppconfig_tdata[7:0];
							o_ch <= s_axis_ppconfig_tdata[23:8] ;
						end
						1: {source,img_h,img_w} <= s_axis_ppconfig_tdata;
						2: begin
							w_addr <= s_axis_ppconfig_tdata ;
						end
						3: begin
							r_addr <= s_axis_ppconfig_tdata ;
							r_btt  <= {o_ch,2'd0};
						end
						4: {total_len,chout_len} <= s_axis_ppconfig_tdata ;
						5: w_btt  <= {s_axis_ppconfig_tdata[20:0],2'd0};
					endcase

					if (config_cnt >= 5) s_axis_ppconfig_tready  <= 'd0;
					else s_axis_ppconfig_tready  <= 'd1;

				end

				W_config: begin
					m_axis_s2mm_cmd_tvalid  <= 'd1 ;
					m_axis_mm2s_cmd_tvalid  <= 'd0 ;
					m_axis_mm2s_cmd_tdata   <= 'd0 ;
					m_axis_s2mm_cmd_tdata   <=  w_cmd;
				end

				W_bias: begin
					m_axis_s2mm_cmd_tvalid <= 'd0;
					m_axis_s2mm_cmd_tdata  <= 'd0;
					bias_rdy_ctrl <= 'd1;
					if (m_axis_s2mm_tvalid & m_axis_s2mm_tready) wdata_cnt <= wdata_cnt + 1'b1 ;
				end

				R_config: begin
					bias_rdy_ctrl <= 'd0;
					m_axis_mm2s_cmd_tvalid <= 'd1;
					m_axis_mm2s_cmd_tdata  <= r_cmd;
				end

				R_bias: begin
					m_axis_mm2s_cmd_tvalid <= 'd0;
					s_axis_mm2s_tready<= 'd1;
					if(bias_we) bias_ram_waddr <= bias_ram_waddr + 1;

					//prepare for work
					pix_cnt   <= 0;
					chout_cnt <= 0;
					line_cnt  <= switch_rowfilter? $signed(-1):0;
					total_cnt <= 0;
				end

				WORK: begin
					config_cnt <= 'd0;
					s_axis_mm2s_tready<= 'd0;
					reorder_ready <= (~dout_prog_full);

					if (reorder_valid & reorder_ready) begin
						if (pix_cnt + 1 < img_w)begin
							pix_cnt     <= pix_cnt + 1 ;
							chout_cnt   <= chout_offset ;
						end
						else begin
							if (chout_offset + 8 < (total_cnt+1) * chout_len)begin
								chout_cnt <= chout_offset + 8 ;
								pix_cnt <= 'd0 ;
								chout_offset <= chout_offset + 8;
							end
							else begin
								if ((&line_cnt == 1) | (line_cnt + 1'b1 < img_h)) begin
									line_cnt <= line_cnt + 1'b1 ;
									pix_cnt <= 'd0 ;
									chout_cnt    <= total_cnt * chout_len ;
									chout_offset <= total_cnt * chout_len ;
								end
								else begin
									line_cnt <= switch_rowfilter? $signed(-1):0;
									pix_cnt <= 'd0 ;
									if (total_cnt + 1'b1 < total_len)begin
										total_cnt    <= total_cnt + 1'b1 ;
										chout_cnt    <= (total_cnt+ 1'b1) * chout_len ;
										chout_offset <= (total_cnt+ 1'b1) * chout_len ;
									end
									else begin
										cycle_finish <= 1'b1 ;
									end
								end
							end
						end
					end
				end
			endcase
		end
	end


//Step1----Throw First line
	reg             step1_valid;
	//reg [23:0]      step1_out[7:0];
	reg [`DATA_INTER_WIDTH:0]      step1_out[7:0];


	always @ (posedge clk) begin
		step1_valid     <= &line_cnt? 0:reorder_valid & reorder_ready;
		//step1_out[0]    <= &line_cnt? 0:reorder_data[24*8-1 : 24*7] ;
		//step1_out[1]    <= &line_cnt? 0:reorder_data[24*7-1 : 24*6] ;
		//step1_out[2]    <= &line_cnt? 0:reorder_data[24*6-1 : 24*5] ;
		//step1_out[3]    <= &line_cnt? 0:reorder_data[24*5-1 : 24*4] ;
		//step1_out[4]    <= &line_cnt? 0:reorder_data[24*4-1 : 24*3] ;
		//step1_out[5]    <= &line_cnt? 0:reorder_data[24*3-1 : 24*2] ;
		//step1_out[6]    <= &line_cnt? 0:reorder_data[24*2-1 : 24*1] ;
		//step1_out[7]    <= &line_cnt? 0:reorder_data[24*1-1 : 24*0] ;
		step1_out[0] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*8-1: `DATA_INTER_WIDTH*7];
		step1_out[1] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*7-1: `DATA_INTER_WIDTH*6];
		step1_out[2] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*6-1: `DATA_INTER_WIDTH*5];
		step1_out[3] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*5-1: `DATA_INTER_WIDTH*4];
		step1_out[4] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*4-1: `DATA_INTER_WIDTH*3];
		step1_out[5] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*3-1: `DATA_INTER_WIDTH*2];
		step1_out[6] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*2-1: `DATA_INTER_WIDTH*1];
		step1_out[7] <= &line_cnt ? 0:reorder_data[`DATA_INTER_WIDTH*1-1: `DATA_INTER_WIDTH*0];
	end


//Step2----Add Bias
	reg             step2_valid;
	//reg [23:0]      step2_out[7:0];
	reg [`DATA_INTER_WIDTH-1:0]      step2_out[7:0];

	always @ (posedge clk) begin
		step2_valid <= step1_valid;
		//step2_out[0] <= switch_bias? step1_out[0] + bias_dout[24*1-1 : 24*0] : step1_out[0];
		//step2_out[1] <= switch_bias? step1_out[1] + bias_dout[24*2-1 : 24*1] : step1_out[1];
		//step2_out[2] <= switch_bias? step1_out[2] + bias_dout[24*3-1 : 24*2] : step1_out[2];
		//step2_out[3] <= switch_bias? step1_out[3] + bias_dout[24*4-1 : 24*3] : step1_out[3];
		//step2_out[4] <= switch_bias? step1_out[4] + bias_dout[24*5-1 : 24*4] : step1_out[4];
		//step2_out[5] <= switch_bias? step1_out[5] + bias_dout[24*6-1 : 24*5] : step1_out[5];
		//step2_out[6] <= switch_bias? step1_out[6] + bias_dout[24*7-1 : 24*6] : step1_out[6];
		//step2_out[7] <= switch_bias? step1_out[7] + bias_dout[24*8-1 : 24*7] : step1_out[7];
		step2_out[0] <= switch_bias ?
			step1_out[0] + bias_dout[`DATA_INTER_WIDTH*1-1: `DATA_INTER_WIDTH*0]: step1_out[0];
		step2_out[1] <= switch_bias ?
			step1_out[1] + bias_dout[`DATA_INTER_WIDTH*2-1: `DATA_INTER_WIDTH*1]: step1_out[1];
		step2_out[2] <= switch_bias ?
			step1_out[2] + bias_dout[`DATA_INTER_WIDTH*3-1: `DATA_INTER_WIDTH*2]: step1_out[2];
		step2_out[3] <= switch_bias ?
			step1_out[3] + bias_dout[`DATA_INTER_WIDTH*4-1: `DATA_INTER_WIDTH*3]: step1_out[3];
		step2_out[4] <= switch_bias ?
			step1_out[4] + bias_dout[`DATA_INTER_WIDTH*5-1: `DATA_INTER_WIDTH*4]: step1_out[4];
		step2_out[5] <= switch_bias ?
			step1_out[5] + bias_dout[`DATA_INTER_WIDTH*6-1: `DATA_INTER_WIDTH*5]: step1_out[5];
		step2_out[6] <= switch_bias ?
			step1_out[6] + bias_dout[`DATA_INTER_WIDTH*7-1: `DATA_INTER_WIDTH*6]: step1_out[6];
		step2_out[7] <= switch_bias ?
			step1_out[7] + bias_dout[`DATA_INTER_WIDTH*8-1: `DATA_INTER_WIDTH*7]: step1_out[7];
	end


//Step3----Relu
	reg         step3_valid;
	//reg [23:0]  step3_out[7:0];
	reg [`DATA_INTER_WIDTH-1:0]  step3_out[7:0];

	always @ (posedge clk) begin
		step3_valid <= step2_valid;
	end

	genvar i;

	generate
		for(i=0;i<8;i=i+1) begin: step3_data
			always @ (posedge clk) begin
				//if(step2_out[i][23])begin
				if(step2_out[i][`DATA_INTER_WIDTH-1])begin
					step3_out[i] <=
						switch_relu ?
						//( relumode ? ({6'h3f,step2_out[i][23:6]}) : 0 )
						( relumode ? ({6'h3f,step2_out[i][`DATA_INTER_WIDTH-1:6]}) : 0 )
						: step2_out[i];
				end
				else begin
					step3_out[i] <= step2_out[i] ;
				end
			end
		end
	endgenerate


//Step4----Scale
	reg         step4_valid;
	//reg [23:0]  step4_out[7:0];
	reg [`DATA_INTER_WIDTH-1:0]  step4_out[7:0];
	wire        step4_mask;

	data_delay #(
		.DATA_WIDTH ( 1 ),
		.LATENCY    ( 3 )
	) u_data_delay (
		.clk                    ( clk            ),
		.rst_n                  ( rst_n          ),
		.i_data                 ( ~(pix_cnt[0] | line_cnt[0]) ),
		.o_data_dly             ( step4_mask )
	);

	always @ (posedge clk) begin
		step4_out[0] <= step3_out[0];
		step4_out[1] <= step3_out[1];
		step4_out[2] <= step3_out[2];
		step4_out[3] <= step3_out[3];
		step4_out[4] <= step3_out[4];
		step4_out[5] <= step3_out[5];
		step4_out[6] <= step3_out[6];
		step4_out[7] <= step3_out[7];
		step4_valid <= switch_sampling ? step3_valid & step4_mask : step3_valid;
	end


//Step5----Change Bit Width
	wire step5_valid;
	wire [15:0] step5_out[7:0];

	assign step5_valid    = step4_valid;
	//assign step5_out[0]   = {{4{step4_out[0][19]}},step4_out[0][19:8]};
	//assign step5_out[1]   = {{4{step4_out[1][19]}},step4_out[1][19:8]};
	//assign step5_out[2]   = {{4{step4_out[2][19]}},step4_out[2][19:8]};
	//assign step5_out[3]   = {{4{step4_out[3][19]}},step4_out[3][19:8]};
	//assign step5_out[4]   = {{4{step4_out[4][19]}},step4_out[4][19:8]};
	//assign step5_out[5]   = {{4{step4_out[5][19]}},step4_out[5][19:8]};
	//assign step5_out[6]   = {{4{step4_out[6][19]}},step4_out[6][19:8]};
	//assign step5_out[7]   = {{4{step4_out[7][19]}},step4_out[7][19:8]};
	assign step5_out[0]   = {{8{step4_out[0][11]}},step4_out[0][11:4]};
	assign step5_out[1]   = {{8{step4_out[1][11]}},step4_out[1][11:4]};
	assign step5_out[2]   = {{8{step4_out[2][11]}},step4_out[2][11:4]};
	assign step5_out[3]   = {{8{step4_out[3][11]}},step4_out[3][11:4]};
	assign step5_out[4]   = {{8{step4_out[4][11]}},step4_out[4][11:4]};
	assign step5_out[5]   = {{8{step4_out[5][11]}},step4_out[5][11:4]};
	assign step5_out[6]   = {{8{step4_out[6][11]}},step4_out[6][11:4]};
	assign step5_out[7]   = {{8{step4_out[7][11]}},step4_out[7][11:4]};


	fifo_w128_d512_fwft fifo_w128_d512_fwft (
		.clk(clk),                // input wire clk
		.srst(~rst_n),            // input wire srst
		.din({step5_out[0],step5_out[1],step5_out[2],step5_out[3],
			step5_out[4],step5_out[5],step5_out[6],step5_out[7]}), // input wire [15 : 0] din
		.wr_en(step5_valid),      // input wire wr_en
		.rd_en(post_ready),       // input wire rd_en
		.dout(post_data),         // output wire [127 : 0] dout
		.full(out_error),         // output wire full
		.empty(),                 // output wire empty
		.valid(post_valid),       // output wire valid
		.prog_full(dout_prog_full), // output wire prog_fulls
		.wr_rst_busy(),  // output wire wr_rst_busy
		.rd_rst_busy()  // output wire rd_rst_busy
	);

endmodule
