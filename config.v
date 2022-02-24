//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2021/06/20 00:25:45
// Design Name:
// Module Name: 1D_convolution
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
//////////////////////////////////////////////////////////////////////////////////

`include "DEFINE.vh"
`include "SIM_CTRL.vh"

module ctrl (
	input                                               clk                     ,
	input                                               rst_n                   ,

	input                                               s_axis_config_tvalid    ,
	output  reg                                         s_axis_config_tready    ,
	input       [31:0]                                  s_axis_config_tdata     ,

	output  reg                                         m_axis_wbconfig_tvalid  ,
	input                                               m_axis_wbconfig_tready  ,
	output  reg [31:0]                                  m_axis_wbconfig_tdata   ,

	output  reg                                         m_axis_dmconfig_tvalid  ,
	input                                               m_axis_dmconfig_tready  ,
	output  reg [31:0]                                  m_axis_dmconfig_tdata   ,

	output  reg                                         m_axis_wmconfig_tvalid  ,
	input                                               m_axis_wmconfig_tready  ,
	output  reg [31:0]                                  m_axis_wmconfig_tdata   ,

	output  reg                                         m_axis_dconfig_tvalid   ,
	input                                               m_axis_dconfig_tready   ,
	output  reg [31:0]                                  m_axis_dconfig_tdata    ,

	output  reg                                         m_axis_wconfig_tvalid   ,
	input                                               m_axis_wconfig_tready   ,
	output  reg [31:0]                                  m_axis_wconfig_tdata    ,

	output  reg                                         m_axis_synconfig_tvalid ,
	input                                               m_axis_synconfig_tready ,
	output  reg [31:0]                                  m_axis_synconfig_tdata  ,

	output  reg                                         m_axis_sumconfig_tvalid ,
	input                                               m_axis_sumconfig_tready ,
	output  reg [31:0]                                  m_axis_sumconfig_tdata  ,

	output  reg                                         m_axis_roconfig_tvalid  ,
	input                                               m_axis_roconfig_tready  ,
	output  reg [31:0]                                  m_axis_roconfig_tdata   ,

	output  reg                                         m_axis_ppconfig_tvalid  ,
	input                                               m_axis_ppconfig_tready  ,
	output  reg [31:0]                                  m_axis_ppconfig_tdata   ,

	output  reg                                         m_axis_dmwconfig_tvalid ,
	input                                               m_axis_dmwconfig_tready ,
	output  reg [31:0]                                  m_axis_dmwconfig_tdata  ,

	output  reg                                         mode_1_1,
	output  reg [31:0]                                  frame_cnt,

	output      [3 :0]                                  status_config
);

//********************** DIV ***********************//
	reg  s_axis_divisor_tvalid, s_axis_dividend_tvalid;
	reg  [31:0] s_axis_divisor_tdata, s_axis_dividend_tdata;
	wire [31:0] m_axis_dout_fix;
	wire m_axis_dout_tvalid;
	wire [47:0] m_axis_dout_tdata;

	reg [24:0] act_len ;
	reg [24:0] weight_rlen ;
	reg [15:0] i_ch  ;
	reg [15:0] o_ch  ;

	assign m_axis_dout_fix = m_axis_dout_tdata[47:16];

// module parameters gen
	reg workmode;
	reg [7:0]   w_tile, a_tile;

	// act manager
	reg [7:0]   act_tile_line_num;    // IMG_W/A_TILE;
	reg [15:0]  act_line_len ;        // IMG_W*I_CH/8; bus128
	reg [11:0]  chout_group_perwram;
	reg [15:0]  chout_perwtile;
	reg [31:0]  w_btt;                // act_len*2; 32bit to 1byte
	reg [31:0]  act_waddr;            // act_waddr;
	wire[22:0]  r_btt;                // act_len*2/A_TILE;
	reg [31:0]  act_raddr;            // act_raddr;
	reg [23:0]  raddr_tile_offset;    // act_len*2/A_TILE; 128bus/TILE
	assign r_btt = raddr_tile_offset[22:0];

	// data mux
	reg [11:0]  img_h;
	reg [11:0]  img_w;

	// weight mux
	reg [23:0] config_cycle_cnt;      // weight_rlen/64 ;
	reg [23:0] weight_switch_num;     // IMG_W*I_CH*ACT_REPEAT_NUM/4;

	// sync
	reg [23:0]  sync_weight_num;      //= weight_rlen/4/W_TILE;//(d32,bus128)
	reg [23:0]  act_block_len;        //= act_len/4;//(d32,bus128)

	// sources
	reg act_source;
	reg weight_source;
	reg bias_source;

	// post
	reg relumode            = 1 ;
	reg switch_bias         = 1 ;
	reg switch_sampling     = 0 ;
	reg switch_relu         = 1 ;
	reg switch_bitintercept = 1 ;
	reg switch_rowfilter        ;
	reg [31:0] bias_waddr       ;
	reg [31:0] bias_raddr       ;

	//ddr write
	reg [31:0] ddr_write_addr   ;

	reg [31:0] weight_waddr;
	reg [31:0] weight_raddr;
	reg [31:0] weight_wlen  ;
	reg [31:0] bias_wlen  ;

	// Output sink
	reg         output_sink;

//Config data
	wire[9:0]   config_finish_bus, config_ready_bus ;
	reg [7:0]   para_cal_cnt ;
	reg [3:0]   config_cnt;
	reg [31:0]  W_LEN_TEMP;
	reg [31:0]  A_LEN_TEMP;
	reg [31:0]  WEI_DEPTH = `WEIGHT_DEPTH;

	localparam CONFIG_SLAVE  = 0;
	localparam CAL_PARAM     = 1;
	localparam CONFIG_MASTER = 2;
	localparam CALCULATE     = 3;
	localparam FINISH        = 4;

	reg [2:0] cs;
	reg [2:0] ns;

	assign status_config = cs;

	always @ (posedge clk) begin
		if (~rst_n) begin
			cs <= CONFIG_SLAVE ;
		end
		else begin
			cs <= ns ;
		end
	end


	// State control
	always @ (*) begin
		if (~rst_n) ns = CONFIG_SLAVE ;
		else begin
			case (cs)
				CONFIG_SLAVE:
					if (config_cnt == `PS_CONFIG_LEN) ns = CAL_PARAM;
					else ns = CONFIG_SLAVE;

				CAL_PARAM:
					if (para_cal_cnt >= 'd120) ns = CONFIG_MASTER;
					else ns = CAL_PARAM;

				CONFIG_MASTER :
					if (&config_finish_bus) ns = CALCULATE ;
					else ns = CONFIG_MASTER;

				CALCULATE  :
					if (&config_ready_bus) ns = FINISH;
					else  ns = CALCULATE ;

				FINISH: ns = CONFIG_SLAVE ;

				default: ns = CONFIG_SLAVE ;
			endcase
		end
	end


	// State machine
	always @ (posedge clk) begin
		if (~rst_n) begin
			para_cal_cnt <= 'd0 ;
			config_cnt   <= 'd0 ;
			frame_cnt    <= 'd0 ;
			mode_1_1     <= 'd0 ;
		end
		else begin
			case (ns)
				CONFIG_SLAVE : begin
					if (s_axis_config_tvalid & s_axis_config_tready) begin
						config_cnt <= config_cnt + 1'b1 ;

						case (config_cnt)
							0: begin
								mode_1_1            <=  s_axis_config_tdata[0] ;
								switch_rowfilter    <= ~s_axis_config_tdata[0] ;
								act_source          <=  s_axis_config_tdata[1] ;
								weight_source       <=  s_axis_config_tdata[2] ;
								bias_source         <=  s_axis_config_tdata[2] ;
								relumode            <=  s_axis_config_tdata[3] ;
								switch_relu         <=  s_axis_config_tdata[4] ;
								switch_bias         <=  s_axis_config_tdata[5] ;
								switch_sampling     <=  s_axis_config_tdata[6] ;
								switch_bitintercept <=  s_axis_config_tdata[7] ;
								img_h               <=  s_axis_config_tdata[16:8] ;
								img_w               <=  s_axis_config_tdata[16:8] ;
								output_sink         <=  s_axis_config_tdata[19:19];
							end
							1: begin
								i_ch                <=  s_axis_config_tdata[11: 0];
								o_ch                <=  s_axis_config_tdata[23:12];
							end
							2: act_waddr            <=  s_axis_config_tdata +`DDR_OFFSET;
							3: act_raddr            <=  s_axis_config_tdata +`DDR_OFFSET;
							4: weight_waddr         <=  s_axis_config_tdata +`DDR_OFFSET;
							5: weight_raddr         <=  s_axis_config_tdata +`DDR_OFFSET; 
							6: weight_wlen          <=  s_axis_config_tdata ;
							7: bias_waddr           <=  s_axis_config_tdata +`DDR_OFFSET;
							8: bias_raddr           <=  s_axis_config_tdata +`DDR_OFFSET;
							9: bias_wlen            <=  s_axis_config_tdata ;
							10: ddr_write_addr      <=  s_axis_config_tdata +`DDR_OFFSET;
						endcase
					end
					
					if (s_axis_config_tready & s_axis_config_tvalid & (config_cnt >= (`PS_CONFIG_LEN-1)))
						s_axis_config_tready  <= 'd0;
					else s_axis_config_tready  <= 'd1;
				end

				CAL_PARAM : begin
					case (para_cal_cnt)
						0: begin
							w_tile                 <= 1;
							a_tile                 <= 1;
							chout_group_perwram    <= 1;

							s_axis_divisor_tvalid  <= 'd0;
							s_axis_dividend_tvalid <= 'd0;

							para_cal_cnt           <= para_cal_cnt + 1 ;
						end

						1: begin
							act_len                <= img_w * i_ch ;
							weight_rlen            <= i_ch * o_ch ;
							chout_perwtile         <= o_ch;

							para_cal_cnt           <= para_cal_cnt + 1 ;
						end

						2: begin
							act_len                <= act_len * img_h ;
							act_line_len           <= act_len >> 3; // act_len / 8
							weight_switch_num      <= act_len >> 2; // act_len / 4
                                                      // Later I shall mult chout_group_perwram

							if(~mode_1_1) weight_rlen <= weight_rlen * 9;

							para_cal_cnt           <= para_cal_cnt + 1 ;
						end

						3: begin
							W_LEN_TEMP <= weight_rlen;
							A_LEN_TEMP <= act_len;

							w_btt <= act_len << 1; // act_len * 2;
							config_cycle_cnt <= weight_rlen >> 6; // weight_rlen / 64 ;
							act_block_len <= act_len >> 2; //act_len / 4;

							if (weight_rlen > `WEIGHT_DEPTH) workmode <= 1;
							else workmode <= 0 ;

							para_cal_cnt <= para_cal_cnt + 1 ;
						end

						4: begin
							if (workmode==0) begin
								w_tile <= 1 ; //cal a_tile
								chout_group_perwram <= o_ch >> 6; // i_ch/64

								s_axis_dividend_tdata <= act_len;
								s_axis_divisor_tdata <= `ACT_DEPTH;

								if (A_LEN_TEMP > `ACT_DEPTH) begin
									a_tile <= a_tile * 2;
									A_LEN_TEMP <= A_LEN_TEMP >> 1;
								end
								else begin
									para_cal_cnt <= para_cal_cnt + 1;
								end

								s_axis_divisor_tvalid <= 'd1;
								s_axis_dividend_tvalid <= 'd1;
							end
							else begin
								a_tile <= 1 ; // cal w_tile

								if (W_LEN_TEMP > `WEIGHT_DEPTH) begin
									w_tile <= w_tile * 2;
									chout_perwtile <= chout_perwtile >> 1;
									W_LEN_TEMP <= W_LEN_TEMP >> 1;
								end
								else begin
									para_cal_cnt <= para_cal_cnt + 1;
								end
							end
						end

						5: begin
							if (workmode==1) begin
								//cal act_repeat num(chout_group_perwram)
								if (mode_1_1) begin
									if (`WEIGHT_RAMf_WIDTH > chout_group_perwram * (i_ch>>1)) begin
										chout_group_perwram <= chout_group_perwram * 2;
									end
									else begin
										para_cal_cnt <= para_cal_cnt + 1 ;
									end
								end
								else begin
									if (WEI_DEPTH > o_ch*576) begin
										chout_group_perwram <= chout_group_perwram * 2;
										WEI_DEPTH <= WEI_DEPTH >> 1;
									end
									else begin
										para_cal_cnt <= para_cal_cnt + 1 ;
									end
								end
							end
							else begin
								para_cal_cnt <= para_cal_cnt + 1 ;
							end
						end

						5+`DIV_LANTANCY:begin
							s_axis_divisor_tvalid <= 'd1;
							s_axis_dividend_tvalid <= 'd1;

							s_axis_dividend_tdata <= img_w;
							s_axis_divisor_tdata <= a_tile;

							para_cal_cnt <= para_cal_cnt + 1 ;
						end

						6+`DIV_LANTANCY:begin
							weight_switch_num <= weight_switch_num * chout_group_perwram ;

							s_axis_dividend_tdata <= act_len*2;
							s_axis_divisor_tdata  <= a_tile;

							s_axis_divisor_tvalid  <= 'd1;
							s_axis_dividend_tvalid <= 'd1;

							para_cal_cnt <= para_cal_cnt + 1 ;
						end

						7+`DIV_LANTANCY:begin
							s_axis_dividend_tdata <= weight_rlen>>2;
							s_axis_divisor_tdata  <= w_tile;

							s_axis_divisor_tvalid  <= 'd1;
							s_axis_dividend_tvalid <= 'd1;

							para_cal_cnt <= para_cal_cnt + 1 ;
						end

						5+`DIV_LANTANCY*2:begin
							act_tile_line_num <= m_axis_dout_fix;

							para_cal_cnt <= para_cal_cnt + 1 ;
						end

						6+`DIV_LANTANCY*2:begin
							raddr_tile_offset <= m_axis_dout_fix;

							para_cal_cnt <= para_cal_cnt + 1 ;
						end

						7+`DIV_LANTANCY*2:begin
							sync_weight_num <= m_axis_dout_fix;

							para_cal_cnt <= para_cal_cnt + 1 ;
						end

						default:begin
							para_cal_cnt <= para_cal_cnt + 1 ;

							s_axis_divisor_tvalid  <= 'd0;
							s_axis_dividend_tvalid <= 'd0;
						end
					endcase
				end

				CALCULATE : begin
					para_cal_cnt <= 'd0 ;
					config_cnt   <= 'd0 ;
				end
				
				FINISH:begin
					frame_cnt <= frame_cnt + 1'b1 ;
				end

				default:begin
					para_cal_cnt <= 'd0 ;
					config_cnt   <= 'd0 ;
				end
			endcase
		end
	end


	// weight bias seperate config
	reg         config_finish_wb = 0 ;
	reg [2:0]   cnt_wbconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_wbconfig_tvalid & m_axis_wbconfig_tready) begin
				if(cnt_wbconfig == 1) begin
					cnt_wbconfig <= 'd0;
					config_finish_wb <= 1'b1;
					m_axis_wbconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_wbconfig_tvalid <= 1'b1 ;
					cnt_wbconfig <= cnt_wbconfig + 1'b1 ;
				end
			end
			else if (~config_finish_wb) m_axis_wbconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_wbconfig_tvalid <= 1'b0 ;
			config_finish_wb <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_wbconfig)
			0: m_axis_wbconfig_tdata  <= {weight_source ,bias_wlen[30:0]}   ;
			1: m_axis_wbconfig_tdata  <= weight_wlen  ;
			default: m_axis_wbconfig_tdata <= 'd0;
		endcase
	end


	// data manager config
	reg         config_finish_dm = 0 ;
	reg [3:0]   cnt_dmconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_dmconfig_tvalid & m_axis_dmconfig_tready) begin
				if(cnt_dmconfig == 7) begin
					cnt_dmconfig <= 'd0;
					config_finish_dm <= 1'b1;
					m_axis_dmconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_dmconfig_tvalid <= 1'b1 ;
					cnt_dmconfig <= cnt_dmconfig + 1'b1 ;
				end
			end
			else if (~config_finish_dm) m_axis_dmconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_dmconfig_tvalid <= 1'b0 ;
			config_finish_dm <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_dmconfig)
			0: m_axis_dmconfig_tdata <= {act_line_len, act_tile_line_num, a_tile};
			1: m_axis_dmconfig_tdata <= w_btt  ;
			2: m_axis_dmconfig_tdata <= act_waddr ;
			3: m_axis_dmconfig_tdata <= r_btt  ;
			4: m_axis_dmconfig_tdata <= act_raddr ;
			5: m_axis_dmconfig_tdata <= {act_source, workmode,w_tile[7:0], act_line_len} ;
			6: m_axis_dmconfig_tdata <= raddr_tile_offset ;
			7: m_axis_dmconfig_tdata <= chout_group_perwram ;
			default: m_axis_dmconfig_tdata <= 'd0;
		endcase
	end


	// weight manager config
	reg         config_finish_wm = 0 ;
	reg [2:0]   cnt_wmconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_wmconfig_tvalid & m_axis_wmconfig_tready) begin
				if(cnt_wmconfig == 3) begin
					cnt_wmconfig <= 'd0;
					config_finish_wm <= 1'b1;
					m_axis_wmconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_wmconfig_tvalid <= 1'b1 ;
					cnt_wmconfig <= cnt_wmconfig + 1'b1 ;
				end
			end
			else if (~config_finish_wm) m_axis_wmconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_wmconfig_tvalid <= 1'b0 ;
			config_finish_wm <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_wmconfig)
			0: m_axis_wmconfig_tdata <= {weight_source, weight_rlen};
			1: m_axis_wmconfig_tdata <= weight_waddr  ;
			2: m_axis_wmconfig_tdata <= weight_raddr  ;
			3: m_axis_wmconfig_tdata <= weight_wlen    ;
			default: m_axis_wmconfig_tdata <= 'd0;
		endcase
	end


	// data mux config
	reg         config_finish_d = 0 ;
	reg [2:0]   cnt_dconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_dconfig_tvalid & m_axis_dconfig_tready) begin
				if(cnt_dconfig == 1) begin
					cnt_dconfig             <= 'd0  ;
					config_finish_d         <= 1'b1 ;
					m_axis_dconfig_tvalid   <= 1'b0 ;
				end
				else begin
					m_axis_dconfig_tvalid   <= 1'b1 ;
					cnt_dconfig <= cnt_dconfig + 1'b1 ;
				end
			end
			else if (~config_finish_d) m_axis_dconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_dconfig_tvalid <= 1'b0 ;
			config_finish_d <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_dconfig)
			0: m_axis_dconfig_tdata  <= {img_h,img_w};
			1: m_axis_dconfig_tdata  <= act_len[24:8]*o_ch  ;
			default: m_axis_dconfig_tdata <= 'd0;
		endcase
	end


	// weight mux config
	reg        config_finish_w   = 0     ;
	reg [2:0]  cnt_wconfig       = 0     ;


	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_wconfig_tvalid & m_axis_wconfig_tready) begin
				if(cnt_wconfig == 0) begin
					cnt_wconfig             <= 'd0  ;
					config_finish_w         <= 1'b1 ;
					m_axis_wconfig_tvalid   <= 1'b0 ;
				end
				else begin
					m_axis_wconfig_tvalid   <= 1'b1 ;
					cnt_wconfig <= cnt_wconfig + 1'b1 ;
				end
			end
			else if (~config_finish_w) m_axis_wconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_wconfig_tvalid <= 1'b0 ;
			config_finish_w <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_wconfig)
			0: m_axis_wconfig_tdata <= config_cycle_cnt  ;
			default: m_axis_wconfig_tdata <= 'd0;
		endcase
	end


	// sync config
	reg         config_finish_sync  = 0     ;
	reg [2:0]   cnt_synconfig       = 0     ;


	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_synconfig_tvalid & m_axis_synconfig_tready) begin
				if(cnt_synconfig == 5) begin
					cnt_synconfig <= 'd0  ;
					config_finish_sync <= 1'b1 ;
					m_axis_synconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_synconfig_tvalid <= 1'b1 ;
					cnt_synconfig <= cnt_synconfig + 1'b1 ;
				end
			end
			else if (~config_finish_sync) m_axis_synconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_synconfig_tvalid <= 1'b0 ;
			config_finish_sync <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_synconfig)
			0: m_axis_synconfig_tdata <= {mode_1_1,chout_group_perwram, i_ch[13:2]};//before it is chgroup_cnt
			1: m_axis_synconfig_tdata <= {img_h, img_w}  ;
			2: m_axis_synconfig_tdata <= sync_weight_num  ;
			3: m_axis_synconfig_tdata <= act_block_len  ;
			4: m_axis_synconfig_tdata <= weight_switch_num  ;
			5: m_axis_synconfig_tdata <= act_len[24:8]*o_ch  ;//[24:2]*O_CH[]
			default: m_axis_synconfig_tdata <= 'd0;
		endcase
	end


	// sum config
	reg         config_finish_sum = 0 ;
	reg [2:0]   cnt_sumconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_sumconfig_tvalid & m_axis_sumconfig_tready) begin
				if(cnt_sumconfig == 2) begin
					cnt_sumconfig <= 'd0;
					config_finish_sum <= 1'b1;
					m_axis_sumconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_sumconfig_tvalid <= 1'b1 ;
					cnt_sumconfig <= cnt_sumconfig + 1'b1 ;
				end
			end
			else if (~config_finish_sum) m_axis_sumconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_sumconfig_tvalid <= 1'b0 ;
			config_finish_sum <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_sumconfig)
			0: m_axis_sumconfig_tdata  <= {img_h,img_w}  ;
			1: m_axis_sumconfig_tdata  <= {o_ch[15:6],i_ch[13:2]}  ;
			2: m_axis_sumconfig_tdata  <= {mode_1_1,chout_group_perwram}  ;
			default: m_axis_sumconfig_tdata <= 'd0;
		endcase
	end


	// ro config
	reg         config_finish_ro = 0 ;
	reg [2:0]   cnt_roconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_roconfig_tvalid & m_axis_roconfig_tready) begin
				if(cnt_roconfig == 1) begin
					cnt_roconfig <= 'd0;
					config_finish_ro <= 1'b1;
					m_axis_roconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_roconfig_tvalid <= 1'b1 ;
					cnt_roconfig <= cnt_roconfig + 1'b1 ;
				end
			end
			else if (~config_finish_ro) m_axis_roconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_roconfig_tvalid <= 1'b0 ;
			config_finish_ro <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_roconfig)
			0: m_axis_roconfig_tdata  <= {mode_1_1,img_h,img_w}  ;
			1: m_axis_roconfig_tdata  <= {chout_perwtile,w_tile}  ;
			default: m_axis_roconfig_tdata <= 'd0;
		endcase
	end


	// pp config
	reg         config_finish_pp = 0 ;
	reg [2:0]   cnt_ppconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_ppconfig_tvalid & m_axis_ppconfig_tready) begin
				if(cnt_ppconfig == 5) begin
					cnt_ppconfig <= 'd0;
					config_finish_pp <= 1'b1;
					m_axis_ppconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_ppconfig_tvalid <= 1'b1 ;
					cnt_ppconfig <= cnt_ppconfig + 1'b1 ;
				end
			end
			else if (~config_finish_pp) m_axis_ppconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_ppconfig_tvalid <= 1'b0 ;
			config_finish_pp <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_ppconfig)
			0: m_axis_ppconfig_tdata <=
				{o_ch, relumode, switch_bias, switch_sampling, switch_relu, switch_bitintercept,
				switch_rowfilter, mode_1_1, workmode};
			1: m_axis_ppconfig_tdata <= {bias_source,img_h,img_w};
			2: m_axis_ppconfig_tdata <= bias_waddr;
			3: m_axis_ppconfig_tdata <= bias_raddr;
			4: m_axis_ppconfig_tdata <= {w_tile,chout_perwtile};
			5: m_axis_ppconfig_tdata <= bias_wlen ;
			default: m_axis_ppconfig_tdata <= 'd0;
		endcase
	end


	// dmw config
	reg         config_finish_dmw = 0 ;
	reg [2:0]   cnt_dmwconfig     = 0 ;

	always @(posedge clk ) begin
		if (ns == CONFIG_MASTER) begin
			if (m_axis_dmwconfig_tvalid & m_axis_dmwconfig_tready) begin
				if(cnt_dmwconfig == 3) begin
					cnt_dmwconfig <= 'd0;
					config_finish_dmw <= 1'b1;
					m_axis_dmwconfig_tvalid <= 1'b0 ;
				end
				else begin
					m_axis_dmwconfig_tvalid <= 1'b1 ;
					cnt_dmwconfig <= cnt_dmwconfig + 1'b1 ;
				end
			end
			else if (~config_finish_dmw) m_axis_dmwconfig_tvalid <= 1'b1 ;
		end
		else begin
			m_axis_dmwconfig_tvalid <= 1'b0 ;
			config_finish_dmw <= 1'b0 ;
		end
	end

	always @ (*) begin
		case (cnt_dmwconfig)
			0: m_axis_dmwconfig_tdata <=
				{switch_sampling, output_sink, chout_perwtile, chout_group_perwram} ;
			1: m_axis_dmwconfig_tdata <= {w_tile, img_w, img_h};
			2: m_axis_dmwconfig_tdata <= ddr_write_addr ;
			3: m_axis_dmwconfig_tdata <= act_len;
			default: m_axis_dmwconfig_tdata <= 'd0;
		endcase
	end


	assign config_finish_bus = {config_finish_wb, config_finish_dm, config_finish_d,
		config_finish_w, config_finish_sync, config_finish_sum, config_finish_wm, config_finish_pp,
		config_finish_ro, config_finish_dmw };
	assign config_ready_bus =  {m_axis_wbconfig_tready, m_axis_dmconfig_tready,
		m_axis_wmconfig_tready, m_axis_dconfig_tready, m_axis_wconfig_tready, m_axis_synconfig_tready,
		m_axis_sumconfig_tready, m_axis_roconfig_tready, m_axis_ppconfig_tready,
		m_axis_dmwconfig_tready};

	div_gen_0 div_32 (
		.aclk(clk),                                       // input wire aclk
		.s_axis_divisor_tvalid(s_axis_divisor_tvalid),    // input wire s_axis_divisor_tvalid
		.s_axis_divisor_tdata(s_axis_divisor_tdata),      // input wire [31 : 0] s_axis_divisor_tdata
		.s_axis_dividend_tvalid(s_axis_dividend_tvalid),  // input wire s_axis_dividend_tvalid
		.s_axis_dividend_tdata(s_axis_dividend_tdata),    // input wire [31 : 0] s_axis_dividend_tdata
		.m_axis_dout_tvalid(m_axis_dout_tvalid),          // output wire m_axis_dout_tvalid
		.m_axis_dout_tdata(m_axis_dout_tdata)             // output wire [47 : 0] m_axis_dout_tdata
	);


	`ifndef SIM
		`ifdef DEBUG
			vio_config_crc vio_config_crc (
			.clk(clk),                      // input wire clk
			.probe_in0({mode_1_1,
				act_source         ,
				weight_source      ,
				relumode           ,
				switch_relu        ,
				switch_bias        ,
				switch_sampling    ,
				switch_bitintercept,
				img_h}),                      // input wire [31 : 0] probe_in0
			.probe_in1({i_ch,o_ch}),        // input wire [31 : 0] probe_in1
			.probe_in2(act_waddr),          // input wire [31 : 0] probe_in2
			.probe_in3(act_raddr),          // input wire [31 : 0] probe_in3
			.probe_in4(weight_waddr   ),    // input wire [31 : 0] probe_in4
			.probe_in5(weight_raddr   ),    // input wire [31 : 0] probe_in5
			.probe_in6(weight_wlen    ),    // input wire [31 : 0] probe_in6
			.probe_in7(bias_waddr     ),    // input wire [31 : 0] probe_in7
			.probe_in8(bias_raddr     ),    // input wire [31 : 0] probe_in8
			.probe_in9(bias_wlen      ),    // input wire [31 : 0] probe_in9
			.probe_in10 (ddr_write_addr)    // input wire [31 : 0] probe_in10
			);
		`endif
	`endif

endmodule
