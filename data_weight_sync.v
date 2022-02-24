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

module act_weight_sync (
	input                                               clk                     ,
	input                                               rst_n                   ,

	//config
	input                                               s_axis_synconfig_tvalid ,
	output          reg                                 s_axis_synconfig_tready ,
	input           [31:0]                              s_axis_synconfig_tdata  ,

	input           [`DATA_ACT_WIDTH-1 :0]              act_data_1              ,
	input           [`DATA_ACT_WIDTH-1 :0]              act_data_2              ,
	input           [`DATA_ACT_WIDTH-1 :0]              act_data_3              ,
	input           [`DATA_ACT_WIDTH-1 :0]              act_data_4              ,
	input                                               act_valid               ,
	output                                              act_ready               ,

	input           [63 :0]                             s_weight_valid          ,
	input           [`DATA_WEIGHT_WIDTH*64-1: 0]        s_weight_data           ,
	output          reg    [63:0]                       s_weight_ready          ,

	input                                               ro_busy                 ,

	input           [9:0]                               act_dcnt                ,
	input           [9:0]                               weight_dcnt             ,

	output          reg                                 m_act_valid      = 0    ,
	output          [`DATA_ACT_WIDTH-1 :0]              m_act_data_1            ,
	output          [`DATA_ACT_WIDTH-1 :0]              m_act_data_2            ,
	output          [`DATA_ACT_WIDTH-1 :0]              m_act_data_3            ,
	output          [`DATA_ACT_WIDTH-1 :0]              m_act_data_4            ,

	//用位宽转�?fifo,generate�?64�?
	output          [`DATA_WEIGHT_WIDTH*256-1 :0]       m_weight_data           ,

	output          reg       [2:0]                     m_weight_valid          ,
	output          reg                                 weight_switch           ,
	output                                              partial_rstn            ,

	output          [3:0]                               status_sync
);


	localparam  CONFIG          = 1;
	localparam  GET_WEIGHT      = 2;
	localparam  ACT_PRE         = 3;
	localparam  CAL_PING        = 4;
	localparam  CAL_PONG        = 5;
	localparam  WEI_SWITCH      = 6;
	localparam  WEI_CONFIG      = 7;
	localparam  M11_GETACT      = 8;
	localparam  M11_DOUT        = 9;

	reg [3:0] current_state = 'd0;
	reg [3:0] next_state    = 'd0;

	reg [23:0] weight_din_cnt   [63:0];
	reg [63:0] weight_load_finish;

	assign status_sync = current_state ;

	 //config
	reg [11:0]  ch_cycle_cnt;// = 64 ;
	reg [11:0]  img_h, img_w ;
	reg [23:0]  weight_len;//   = 9*256*256/4; 
	reg [23:0]  act_block_len;// = 56*56*256/4;
	reg [11:0]  ch_group_num ;
	reg         mode_1_1;



/*-------------------------- RAM GEN --------------------------*/
	wire [`DATA_WEIGHT_WIDTH-1:0] weight       [63 :0];
	wire [63:0]                   ram_we1             ;
	wire [63:0]                   ram_we2             ;
	wire [63:0]                   ram_we3             ;
	wire [63:0]                   ram_we4             ;
	reg  [11:0]                   ram_rd_addr         ;
	reg  [11:0]                   ram_addr1     [63:0];
	reg  [11:0]                   ram_addr2     [63:0];
	reg  [11:0]                   ram_addr3     [63:0];
	reg  [11:0]                   ram_addr4     [63:0];
	wire [`DATA_WEIGHT_WIDTH-1:0] ram_dout1     [63:0];
	wire [`DATA_WEIGHT_WIDTH-1:0] ram_dout2     [63:0];
	wire [`DATA_WEIGHT_WIDTH-1:0] ram_dout3     [63:0];
	wire [`DATA_WEIGHT_WIDTH-1:0] ram_dout4     [63:0];

	reg  [3 :0]                   ram_cnt       [63:0];
	reg  [3 :0]                   sel           [63:0];

	reg                           wram_waddr_rst ;
	reg                           wram_raddr_rst ;

	genvar i ;
	generate
		for (i=0; i<64; i=i+1) begin: weight_gen
			assign weight[i] = s_weight_data[`DATA_WEIGHT_WIDTH*(i+1)-1 : `DATA_WEIGHT_WIDTH*i];
		end
	endgenerate

	genvar j ;
	generate
		for (j=0; j<64; j=j+1) begin: weight_ram_gen
			weight_ram weight_ram1 (
				.clka(clk),              // input wire clka
				.clkb(clk),              // input wire clka
				.wea(ram_we1[j]),        // input wire [0 : 0] wea
				.addra(ram_addr1[j]),    // input wire addra
				.addrb(ram_rd_addr),     // input wire addra
				.dina(weight[j]),        // input wire dina
				.doutb(ram_dout1[j])     // output wire douta
			);

			weight_ram weight_ram2 (
				.clka(clk),              // input wire clka
				.clkb(clk),              // input wire clka
				.wea(ram_we2[j]),        // input wire [0 : 0] wea
				.addra(ram_addr2[j]),    // input wire [11 : 0] addra
				.addrb(ram_rd_addr),    // input wire [11 : 0] addra
				.dina(weight[j]),      // input wire [11 : 0] dina
				.doutb(ram_dout2[j])     // output wire [11 : 0] douta
			);

			weight_ram weight_ram3 (
				.clka(clk),              // input wire clka
				.clkb(clk),              // input wire clka
				.wea(ram_we3[j]),        // input wire [0 : 0] wea
				.addra(ram_addr3[j]),    // input wire [11 : 0] addra
				.addrb(ram_rd_addr),    // input wire [11 : 0] addra
				.dina(weight[j]),      // input wire [11 : 0] dina
				.doutb(ram_dout3[j])     // output wire [11 : 0] douta
			);

			weight_ram weight_ram4 (
				.clka(clk),              // input wire clka
				.clkb(clk),              // input wire clka
				.wea(ram_we4[j]),        // input wire [0 : 0] wea
				.addra(ram_addr4[j]),    // input wire [11 : 0] addra
				.addrb(ram_rd_addr),    // input wire [11 : 0] addra
				.dina(weight[j]),      // input wire [11 : 0] dina
				.doutb(ram_dout4[j])     // output wire [11 : 0] douta
			);

			assign ram_we1[j] = s_weight_valid[j] & s_weight_ready[j] & sel[j][0];
			assign ram_we2[j] = s_weight_valid[j] & s_weight_ready[j] & sel[j][1];
			assign ram_we3[j] = s_weight_valid[j] & s_weight_ready[j] & sel[j][2];
			assign ram_we4[j] = s_weight_valid[j] & s_weight_ready[j] & sel[j][3];

			assign m_weight_data[j*4*(`DATA_WEIGHT_WIDTH)+(`DATA_WEIGHT_WIDTH)-1:
				j*4*(`DATA_WEIGHT_WIDTH)] = ram_dout1[j];

			assign m_weight_data[j*4*(`DATA_WEIGHT_WIDTH)+2*(`DATA_WEIGHT_WIDTH)-1:
				j*4*(`DATA_WEIGHT_WIDTH)+(`DATA_WEIGHT_WIDTH)] = ram_dout2[j];

			assign m_weight_data[j*4*(`DATA_WEIGHT_WIDTH)+3*(`DATA_WEIGHT_WIDTH)-1:
				j*4*(`DATA_WEIGHT_WIDTH)+2*(`DATA_WEIGHT_WIDTH)] = ram_dout3[j];

			assign m_weight_data[j*4*(`DATA_WEIGHT_WIDTH)+4*(`DATA_WEIGHT_WIDTH)-1:
				j*4*(`DATA_WEIGHT_WIDTH)+3*(`DATA_WEIGHT_WIDTH)] = ram_dout4[j];
			//assign m_weight_data[j*16+3: j*16] = ram_dout1[j];

			//assign m_weight_data[j*16+7: j*16+4] = ram_dout2[j];

			//assign m_weight_data[j*16+11: j*16+8] = ram_dout3[j];

			//assign m_weight_data[j*16+15: j*16+12] = ram_dout4[j];

			always @ (posedge clk) begin
				if (wram_waddr_rst)    ram_addr1[j] <= 12'd0;
				else if (ram_we1[j]) ram_addr1[j] <= ram_addr1[j] + 1'b1 ;
			end

			always @ (posedge clk) begin
				if (wram_waddr_rst)    ram_addr2[j] <= 12'd0;
				else if (ram_we2[j]) ram_addr2[j] <= ram_addr2[j] + 1'b1 ;
			end

			always @ (posedge clk) begin
				if (wram_waddr_rst)    ram_addr3[j] <= 12'd0;
				else if (ram_we3[j]) ram_addr3[j] <= ram_addr3[j] + 1'b1 ;
			end

			always @ (posedge clk) begin
				if (wram_waddr_rst)    ram_addr4[j] <= 12'd0;
				else if (ram_we4[j]) ram_addr4[j] <= ram_addr4[j] + 1'b1 ;
			end

			always @ (posedge clk) begin
				if (wram_waddr_rst)    sel[j] <= 4'b0001;
				else begin
					if (mode_1_1) begin
						if (s_weight_valid[j] & s_weight_ready[j]) sel[j] <= {sel[j][2:0],sel[j][3]};
					end
					else if (ram_cnt[j] == 8 & s_weight_valid[j] & s_weight_ready[j])
						sel[j] <= {sel[j][2:0],sel[j][3]};
				end
			end

			always @ (posedge clk) begin
				if (wram_waddr_rst)    ram_cnt[j] <= 4'd0;
				else if (ram_cnt[j] == 8 & s_weight_valid[j] & s_weight_ready[j]) ram_cnt[j] <= 4'd0;
				else if (s_weight_valid[j] & s_weight_ready[j]) ram_cnt[j] <= ram_cnt[j] + 1'b1;
			end

			always @ (posedge clk) begin
				case(next_state)
					GET_WEIGHT:begin
						if ((s_weight_valid[j]) & s_weight_ready[j])
							weight_din_cnt[j] <= weight_din_cnt[j] + 1'b1 ;
					end
					default: weight_din_cnt[j] <='d0;
				endcase
			end

			always @ (posedge clk) begin
				case(next_state)
					GET_WEIGHT:begin
						if((weight_din_cnt[j] + 1 >= weight_len/16) & s_weight_valid[j]
								& s_weight_ready[j]) begin
							s_weight_ready[j] <= 0;
							weight_load_finish[j] <= 1 ;
						end
						else s_weight_ready[j] <= 1;
					end
					default:begin
						s_weight_ready[j] <= 0;
						weight_load_finish[j] <= 0 ;
					end
				endcase
			end
		end
	endgenerate

/*-------------------------------------------------------------*/

/*------------------------ DATA EXPAND ------------------------*/

/************************************ Activation block ram. ***************************************/
	reg [8:0]   act4_we_addr, act4_rd_addr  ;
	reg         act4_we_offset, act4_rd_offset;
	wire        act4_we                     ;
	reg         act4_re                     ;
	reg         act_ready_reg               ;
	wire [4*`DATA_ACT_WIDTH-1:0] act4_din, act4_dout         ;

	wire [9:0]  w_act4_we_addr, w_act4_rd_addr;

	reg         partial_rstn_reg = 1        ;

	assign w_act4_we_addr = {act4_we_offset, act4_we_addr};
	assign w_act4_rd_addr = {act4_rd_offset, act4_rd_addr};

	act_ram_4 act_ram_4 (
		.clka(clk),    // input wire clka
		.wea(act4_we),      // input wire [0 : 0] wea
		.addra(w_act4_we_addr),  // input wire [8 : 0] addra
		.dina(act4_din),    // input wire [47 : 0] dina
		.clkb(clk),    // input wire clkb
		.enb(act4_re),      // input wire enb
		.addrb(w_act4_rd_addr),  // input wire [8 : 0] addrb
		.doutb(act4_dout)  // output wire [47 : 0] doutb
	);

/**************************************************************************************************/

	reg [2 :0] config_cnt = 'd0 ;
	
	reg        ping_rd_over, pong_rd_over, ping_we_over, pong_we_over, weight_over, wei_switch_pre0;
	reg        wei_switch_ping, wei_switch_pong, wei_switch_flag, act_ready_ctrl;
	reg        m_act_valid_pre = 0, weight_switch_pre = 0;
	reg [2:0]  weight_valid_pre = 0;
	reg [3:0]  weight_cnt  = 0;
	reg [10:0] ch_cycle = 0 ;
	reg [11:0] group_cycle = 0 ;
	reg [11:0] weight_reload_cnt;
	reg [31:0] total_len;
	reg [11:0] repeat_num;

	reg [23:0] weight_switch_cnt;
	reg [23:0] weight_switch_num;

	assign act4_we = act_valid & act_ready ;
	assign act_ready = act_ready_ctrl & act_ready_reg ;
	assign act4_din= {act_data_4, act_data_3, act_data_2, act_data_1};
	assign {m_act_data_4, m_act_data_3, m_act_data_2, m_act_data_1} = act4_dout;

	reg [31:0] dout_cnt;

	always @ (posedge clk) begin
		if (~rst_n) begin
			dout_cnt <= 'd0;
		end
		else begin
			if(next_state == CONFIG)begin
				dout_cnt <= 'd0;
			end
			else if(m_act_valid)begin
				dout_cnt <= dout_cnt + 1 ;
			end
		end
	end

	always @ (posedge clk) begin
		current_state <= next_state ;
	end

	always @ (*) begin
		case(current_state)
			CONFIG:begin
				if (config_cnt > 5) next_state = GET_WEIGHT;
				else next_state = CONFIG;
			end

			GET_WEIGHT:begin
				if (weight_load_finish == {64{1'b1}})begin
					//if (mode_1_1) next_state = M11_GETACT; else
					if (weight_reload_cnt > 0) next_state = WEI_CONFIG;
					//else if (mode_1_1) next_state = CAL_PING; 
					else next_state = ACT_PRE; 
				end
				else next_state = GET_WEIGHT;
				// here I should add a state to switch the weight tile
			end

			//switch 3*3
			WEI_CONFIG:begin
				if (weight_switch_pre) next_state = CAL_PING;
				else next_state = WEI_CONFIG;
			end

			ACT_PRE:begin
				if (pong_rd_over) next_state = CAL_PING;
				else next_state = ACT_PRE;
			end

			CAL_PING:begin
				if ((dout_cnt + 1 == total_len) & m_act_valid) next_state = CONFIG;
				else if (ping_rd_over & ping_we_over & (~ro_busy)) begin
					if(weight_switch_cnt == weight_switch_num) next_state = WEI_SWITCH;
					else next_state = CAL_PONG;
				end else next_state = CAL_PING;
			end

			CAL_PONG:begin
				if ((dout_cnt + 1 == total_len) & m_act_valid) next_state = CONFIG;
				else if (pong_rd_over & pong_we_over & (~ro_busy)) begin
					if(weight_switch_cnt == weight_switch_num) next_state = WEI_SWITCH;
					else next_state = CAL_PING;
				end else next_state = CAL_PONG;
			end

			WEI_SWITCH: next_state = GET_WEIGHT ;

			default: next_state = CONFIG;
		endcase
	end


	always @ (posedge clk) begin
		case(next_state)
			CONFIG:begin
				act_ready_reg       <= 0;
				//s_weight_ready  <= 0;
				act4_we_addr    <= 0;
				act4_rd_addr    <= $signed (-1) ;
				act4_re         <= 0;
				ping_we_over    <= 0;
				pong_we_over    <= 0;
				ping_rd_over    <= 0;
				pong_rd_over    <= 0;
				ram_rd_addr     <= 0;
				weight_over     <= 0;
				weight_cnt      <= 0;
				weight_switch_pre <= 0;
				ch_cycle        <= 0;
				wei_switch_ping <= 0;
				wei_switch_pong <= 0;
				wei_switch_flag <= 0;
				group_cycle     <= 1;
				partial_rstn_reg    <= 0;
				wram_waddr_rst <= 1;
				wram_raddr_rst <= 1;
				weight_reload_cnt <= 0 ;
				m_act_valid_pre     <= 0;

				if (s_axis_synconfig_tvalid & s_axis_synconfig_tready) begin
					config_cnt <= config_cnt + 1'b1 ;
				end

				case (config_cnt)
					0: begin 
						{ch_group_num,ch_cycle_cnt} <= s_axis_synconfig_tdata[23:0] ;
						mode_1_1 <= s_axis_synconfig_tdata[24] ;
					end
					1: begin
						{img_h, img_w}   <= s_axis_synconfig_tdata[23:0] ;
						repeat_num <= ch_group_num;
					end
					2: weight_len       <= s_axis_synconfig_tdata[23:0] ;
					3: act_block_len    <= s_axis_synconfig_tdata[23:0] ;
					4: weight_switch_num<= s_axis_synconfig_tdata[23:0] ;
					5: total_len        <= s_axis_synconfig_tdata[31:0] ;
				endcase

				if (config_cnt >= 5) s_axis_synconfig_tready  <= 'd0;
				else s_axis_synconfig_tready  <= 'd1;
			end

			GET_WEIGHT:begin
				weight_switch_cnt   <= 0;
				wram_waddr_rst      <= 0;
				wram_raddr_rst      <= 1;
				config_cnt          <= 0;
				partial_rstn_reg    <= 1;
				m_act_valid_pre     <= 0;
			end

			WEI_CONFIG:begin
				//配权�?
				case(mode_1_1)
					0: begin
						if(weight_cnt < 9) begin
							weight_cnt <= weight_cnt + 1;

							if (wram_raddr_rst) begin
								wram_raddr_rst <= 0 ;
								ram_rd_addr    <= 0 ;
							end else begin
								ram_rd_addr <= ram_rd_addr + 1;
							end

							case (weight_cnt)
								0: weight_valid_pre <= 3'b001; 
								3: weight_valid_pre <= 3'b010; 
								6: weight_valid_pre <= 3'b100; 
							endcase
						end
						else if(weight_cnt == 9) begin
							weight_cnt <= weight_cnt + 1;
							weight_valid_pre <= 0;
							weight_switch_pre<= 1;
						end
						else weight_switch_pre <= 0;
					end

					1:begin
						weight_switch_pre<= 1;
					end
				endcase
			end

			ACT_PRE:begin
				act4_we_offset <= 1'b0;
				partial_rstn_reg    <= 1;

				if (act4_we) begin
					if (act4_we_addr == img_h-1) begin
						act_ready_reg <= 1'b0 ;
						pong_we_over <= 1'b1 ;
						pong_rd_over <= 1'b1 ;
						act4_we_addr <= 0 ;
					end else
						act4_we_addr <= act4_we_addr + 1'b1 ;
				end
				else begin
					act_ready_reg <= 1'b1 ;
				end

				case(mode_1_1)
					0: begin
						if(weight_cnt < 9) begin
							weight_cnt <= weight_cnt + 1;

							if (wram_raddr_rst) begin
								wram_raddr_rst <= 0 ;
								ram_rd_addr    <= 0 ;
							end else begin
								ram_rd_addr <= ram_rd_addr + 1;
							end

							case (weight_cnt)
								0: weight_valid_pre <= 3'b001;
								3: weight_valid_pre <= 3'b010;
								6: weight_valid_pre <= 3'b100;
							endcase
						end
						else if(weight_cnt == 9) begin
							weight_cnt <= weight_cnt + 1;
							weight_valid_pre <= 0;
							weight_switch_pre<= 1;
						end
						else weight_switch_pre <= 0;

					end
				endcase

				ch_cycle <= 1 ;
			end

			CAL_PING:begin
				act4_we_offset <= 1'b1; 
				act4_rd_offset <= 1'b0;
				pong_we_over   <= 1'b0;
				partial_rstn_reg    <= 1;

				if (act4_rd_addr == 1) begin
					if (ch_cycle == ch_cycle_cnt) ch_cycle <= 0 ;
					else ch_cycle <= ch_cycle + 1 ;
				end
				else if (ch_cycle == 0) ch_cycle <= 1 ;

				if (act4_we) begin
					if (act4_we_addr == img_h-1) begin
						act_ready_reg <= 1'b0 ;
						act4_we_addr <= 0;
						ping_we_over <= 1;
					end else
						act4_we_addr <= act4_we_addr + 1'b1 ;
				end
				else if (~ping_we_over) begin
					act_ready_reg <= 1'b1 ;
				end

				act4_re <= 1'b1 ;

				if (pong_rd_over) begin
					act4_rd_addr <= 0 ;
					pong_rd_over <= 0 ;
				end
				else if(act4_rd_addr <= img_h-1) begin
					act4_rd_addr <= act4_rd_addr + 1'b1 ;
				end

				//读valid生成
				if (act4_rd_addr<= img_h-1) m_act_valid_pre <= 1'b1 ;
				else if (act4_rd_addr == img_h) begin
					ping_rd_over <= 1 ;
					m_act_valid_pre <= 1'b0;
				end
				else m_act_valid_pre <= 1'b0;

				// Weight 相关
				case (mode_1_1)
					0: begin
						//配权�?
						if (act4_rd_addr == 3) begin
							weight_cnt <= 0 ;
							weight_valid_pre <= 0;
						end
						else if(weight_cnt < 9) begin
							weight_cnt <= weight_cnt + 1;

							if (wram_raddr_rst) begin
								wram_raddr_rst <= 0 ;
								ram_rd_addr    <= 0 ;
							end else begin
								ram_rd_addr <= ram_rd_addr + 1;
							end

							case (weight_cnt)
								0: weight_valid_pre <= 3'b001; 
								3: weight_valid_pre <= 3'b010; 
								6: weight_valid_pre <= 3'b100; 
							endcase
						end
						else if (ch_cycle == 0) begin
							weight_valid_pre <= 0;

							if (group_cycle==ch_group_num) begin
								wram_raddr_rst <= 1 ;
								group_cycle    <= 1 ;
							end
							else begin
								//重启权重，由于�??一组权重已乒乓，从�?二组权重读起，即-1+9=8
								ram_rd_addr  <= ch_cycle_cnt*9 * group_cycle - 1 ; 
								group_cycle  <= group_cycle + 1 ;
							end
						end
						else weight_valid_pre <= 0;

						//权重switch生成
						if ((act4_rd_addr == img_h)) begin
							weight_switch_pre <= 1'b1 ;
							weight_switch_cnt <= weight_switch_cnt + 1'b1 ;
						end
						else weight_switch_pre <= 1'b0 ;
					end

					1: begin
						//配权�?
						if (pong_rd_over) begin
							if (wram_raddr_rst) begin
								wram_raddr_rst <= 0 ;
								ram_rd_addr    <= 0 ;
							end else begin
								ram_rd_addr <= ram_rd_addr + 1;
							end
						end
						else if (ch_cycle == 0) begin
							if (group_cycle==ch_group_num) begin
								wram_raddr_rst <= 1 ;
								group_cycle    <= 1 ;
							end
							else begin
								//重启权重，由于�??一组权重已乒乓，从�?二组权重读起，即-1+9=8
								ram_rd_addr  <= ch_cycle_cnt * group_cycle - 1 ;
								group_cycle  <= group_cycle + 1 ;
							end
						end

						//权重switch生成
						if ((act4_rd_addr == img_h)) begin
							weight_switch_cnt <= weight_switch_cnt + 1'b1 ;
						end
					end
				endcase

			end

			CAL_PONG:begin
				//s_weight_ready <= 0 ;
				act4_we_offset <= 1'b0; 
				act4_rd_offset <= 1'b1;
				ping_we_over   <= 1'b0;
				partial_rstn_reg    <= 1;

				if (act4_rd_addr == 1) begin
					if (ch_cycle == ch_cycle_cnt) ch_cycle <= 0 ;
					else ch_cycle <= ch_cycle + 1 ;
				end
				else if (ch_cycle == 0) ch_cycle <= 1 ;

				if (act4_we) begin
					if (act4_we_addr == img_h-1) begin
						act_ready_reg <= 1'b0 ;
						act4_we_addr <= 0;
						pong_we_over <= 1;
					end else
						act4_we_addr <= act4_we_addr + 1'b1 ;
				end
				else if (~pong_we_over) begin
					act_ready_reg <= 1'b1 ;
				end

				//读控�?
				act4_re <= 1'b1 ;

				if (ping_rd_over) begin
					act4_rd_addr <= 0 ;
					ping_rd_over <= 0 ;
				end
				else if(act4_rd_addr <= img_h-1) begin
					act4_rd_addr <= act4_rd_addr + 1'b1 ;
				end

				//读valid生成
				if (act4_rd_addr <= img_h-1) m_act_valid_pre <= 1'b1 ;
				else if (act4_rd_addr == img_h) begin
					pong_rd_over <= 1 ;
					m_act_valid_pre <= 1'b0;
				end
				else m_act_valid_pre <= 1'b0;

				// Weight 相关
				case (mode_1_1)
					0: begin
						//配权�?
						if (act4_rd_addr == 3) begin
							weight_cnt <= 0 ;
							weight_valid_pre <= 0;
						end
						else if(weight_cnt < 9) begin
							weight_cnt <= weight_cnt + 1;

							if (wram_raddr_rst) begin
								wram_raddr_rst <= 0 ;
								ram_rd_addr    <= 0 ;
							end
							else begin
								ram_rd_addr <= ram_rd_addr + 1;
							end

							case (weight_cnt)
								0: weight_valid_pre <= 3'b001; 
								3: weight_valid_pre <= 3'b010; 
								6: weight_valid_pre <= 3'b100; 
							endcase
						end
						else if (ch_cycle == 0) begin
							weight_valid_pre <= 0;

							if (group_cycle==ch_group_num) begin
								wram_raddr_rst <= 1 ;
								group_cycle    <= 1 ;
							end
							else begin
								//重启权重，由于�??一组权重已乒乓，从�?二组权重读起，即-1+9=8
								ram_rd_addr  <= ch_cycle_cnt*9 * group_cycle - 1 ;
								group_cycle  <= group_cycle + 1 ;
							end
						end
						else weight_valid_pre <= 0;


						//权重switch生成
						if ((act4_rd_addr == img_h)) begin
							weight_switch_pre <= 1'b1 ;
							weight_switch_cnt <= weight_switch_cnt + 1'b1 ;
						end
						else weight_switch_pre <= 1'b0 ;
					end

					1: begin
						//配权�?
						if (ping_rd_over) begin
							if (wram_raddr_rst) begin
								wram_raddr_rst <= 0 ;
								ram_rd_addr    <= 0 ;
							end else begin
								ram_rd_addr <= ram_rd_addr + 1;
							end
						end
						else if (ch_cycle == 0) begin
							if (group_cycle==ch_group_num) begin
								wram_raddr_rst <= 1 ;
								group_cycle    <= 1 ;
							end
							else begin
								//重启权重，由于�??一组权重已乒乓，从�?二组权重读起，即-1+9=8
								ram_rd_addr  <= ch_cycle_cnt * group_cycle - 1 ;
								group_cycle  <= group_cycle + 1 ;
							end
						end

						//权重switch生成
						if ((act4_rd_addr == img_h)) begin
							weight_switch_cnt <= weight_switch_cnt + 1'b1 ;
						end
					end
				endcase
			end

			WEI_SWITCH:begin
				act_ready_reg           <= 0;
				//s_weight_ready          <= 0;
				act4_we_addr            <= 0;
				act4_rd_addr            <= $signed (-1) ;
				act4_re                 <= 1;
				ping_we_over            <= 0;
				pong_we_over            <= 1;
				ping_rd_over            <= 0;
				pong_rd_over            <= 1;
				ram_rd_addr             <= 0;
				weight_over             <= 0;
				weight_cnt              <= 0;
				weight_switch_pre       <= 0;
				ch_cycle                <= 1;
				wei_switch_ping         <= 0;
				wei_switch_pong         <= 0;
				wei_switch_flag         <= 0;
				partial_rstn_reg        <= 0;
				wram_waddr_rst          <= 1;
				m_act_valid_pre         <= 0;
				weight_reload_cnt       <= weight_reload_cnt + 1 ;
			end
		endcase
	end

	reg [23:0]  act_din_cnt ;

	always @ (posedge clk) begin
		case(next_state)
			CONFIG: begin
				act_ready_ctrl <= 1 ;
				act_din_cnt <= 0 ;
				wei_switch_pre0 <= 0 ;
			end

			WEI_SWITCH : begin
				act_ready_ctrl <= 1 ;
				act_din_cnt <= 0 ;
				wei_switch_pre0 <= 0 ;
			end

		endcase
	end

	always @ (posedge clk)  m_weight_valid <= weight_valid_pre ;
	always @ (posedge clk)  weight_switch  <= weight_switch_pre;
	always @ (posedge clk)  m_act_valid    <= m_act_valid_pre  ;


	data_delay #(
		.DATA_WIDTH ( 1 ),
		.LATENCY    ( 20 ))
	u_data_delay (
		.clk                     ( clk          ),
		.rst_n                   ( rst_n        ),
		.i_data                  ( partial_rstn_reg ),
		.o_data_dly              ( partial_rstn     )
	);

	`ifdef PRINT
		integer handle6 ;
			initial handle6=$fopen("act_data1.txt");
			always @ (posedge clk) begin
				if (m_act_valid)
					if (m_act_data_1[`DATA_ACT_WIDTH-1]) $fdisplay(handle6,"-%d",`ACT_BOUND-m_act_data_1);
					else $fdisplay(handle6,"%d",m_act_data_1);
			end
	`endif
/*-------------------------------------------------------------*/

endmodule
