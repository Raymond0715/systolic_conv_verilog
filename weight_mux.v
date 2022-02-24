`include "DEFINE.vh"

module weight_mux (
	input                                   clk                 ,
	input                                   rst_n               ,

	input                                   s_config_valid      ,
	output  reg                             s_config_ready      ,
	input [31:0]                            s_config_data       ,

	input                                   s_weight_valid      ,
	output                                  s_weight_ready      ,
	input [127:0]                           s_weight            ,

	output [63 :0]                          m_weight_valid      ,
	output [`DATA_WEIGHT_WIDTH*64-1: 0]     m_weight_data       ,
	input  [63 :0]                          m_weight_ready      ,
	output reg [9:0]                        weight_dcnt         ,

	output [3:0]                            status_wmux
);

	//reg [3:0] config_cnt ;
	reg [7:0] conv_group_cnt;


	localparam IDLE                 = 1;
	localparam CYCLE_CONV_GROUP     = 2;
	localparam CYCLE_CONV_3_3       = 3;
	localparam CYCLE_CONV_4         = 4;
	localparam CYCLE_CH_GROUP       = 5;
	localparam CYCLE_CH_OFFSET      = 6;
	localparam END                  = 7;

	reg [2:0]  c_state, n_state;
	assign status_wmux = c_state;

	reg        r_weight_ready;
	reg [23:0] cycle_cnt ;
	reg        out_valid_ctrl;

	reg  [`DATA_WEIGHT_WIDTH-1:0] fifo_din[63:0];
	wire [`DATA_WEIGHT_WIDTH-1:0] fifo_dout[63:0];
	wire [9 :0] weight_fifo_dcnt[63:0];

	reg  [63:0] fifo_we;
	wire [63:0] prog_full;
	wire [63:0] fifo_valid;

	reg  [23:0] config_cycle_cnt ; //56*56*4
	reg  [2 :0] config_cnt ;

	always @ (posedge clk) begin
		if (s_config_valid & s_config_ready)begin
			config_cnt <= config_cnt + 1'b1 ;
			case(config_cnt)
				0: config_cycle_cnt <= s_config_data[23:0];
			endcase
		end
		else config_cnt <= 0 ;
	end

	always @(posedge clk) begin
		if (~rst_n) c_state <= IDLE ;
		else c_state <= n_state ;
	end

	always @(posedge clk ) begin
		weight_dcnt <= weight_fifo_dcnt[`CONV_GROUP_NUM-1];
	end

	always @ (*) begin
		case(c_state)
			IDLE:if(s_config_valid & s_config_ready & (config_cnt == 0)) n_state = CYCLE_CONV_GROUP;
				else n_state = IDLE;
			CYCLE_CONV_GROUP: if(conv_group_cnt == `CONV_GROUP_NUM) n_state = CYCLE_CONV_3_3;
				else n_state = CYCLE_CONV_GROUP;
			CYCLE_CONV_3_3: if(cycle_cnt < config_cycle_cnt) n_state = CYCLE_CONV_GROUP; 
				else n_state = END ;
			END : n_state = IDLE;
			default:n_state = IDLE;
		endcase
	end

	always @(posedge clk) begin
		case (n_state)
			IDLE:begin
				s_config_ready <= 1'b1 ;
				conv_group_cnt <= 8'd0 ;
				r_weight_ready <= 1'b0 ;
				cycle_cnt      <= 24'd0;
				out_valid_ctrl <= 1'b0;

				fifo_we[0] <= 1'b0 ;
				fifo_we[1] <= 1'b0 ;
				fifo_we[2] <= 1'b0 ;
				fifo_we[3] <= 1'b0 ;
				fifo_we[4] <= 1'b0 ;
				fifo_we[5] <= 1'b0 ;
				fifo_we[6] <= 1'b0 ;
				fifo_we[7] <= 1'b0 ;
				fifo_we[8] <= 1'b0 ;
				fifo_we[9] <= 1'b0 ;
				fifo_we[10] <= 1'b0 ;
				fifo_we[11] <= 1'b0 ;
				fifo_we[12] <= 1'b0 ;
				fifo_we[13] <= 1'b0 ;
				fifo_we[14] <= 1'b0 ;
				fifo_we[15] <= 1'b0 ;
				fifo_we[16] <= 1'b0 ;
				fifo_we[17] <= 1'b0 ;
				fifo_we[18] <= 1'b0 ;
				fifo_we[19] <= 1'b0 ;
				fifo_we[20] <= 1'b0 ;
				fifo_we[21] <= 1'b0 ;
				fifo_we[22] <= 1'b0 ;
				fifo_we[23] <= 1'b0 ;
				fifo_we[24] <= 1'b0 ;
				fifo_we[25] <= 1'b0 ;
				fifo_we[26] <= 1'b0 ;
				fifo_we[27] <= 1'b0 ;
				fifo_we[28] <= 1'b0 ;
				fifo_we[29] <= 1'b0 ;
				fifo_we[30] <= 1'b0 ;
				fifo_we[31] <= 1'b0 ;
				fifo_we[32] <= 1'b0 ;
				fifo_we[33] <= 1'b0 ;
				fifo_we[34] <= 1'b0 ;
				fifo_we[35] <= 1'b0 ;
				fifo_we[36] <= 1'b0 ;
				fifo_we[37] <= 1'b0 ;
				fifo_we[38] <= 1'b0 ;
				fifo_we[39] <= 1'b0 ;
				fifo_we[40] <= 1'b0 ;
				fifo_we[41] <= 1'b0 ;
				fifo_we[42] <= 1'b0 ;
				fifo_we[43] <= 1'b0 ;
				fifo_we[44] <= 1'b0 ;
				fifo_we[45] <= 1'b0 ;
				fifo_we[46] <= 1'b0 ;
				fifo_we[47] <= 1'b0 ;
				fifo_we[48] <= 1'b0 ;
				fifo_we[49] <= 1'b0 ;
				fifo_we[50] <= 1'b0 ;
				fifo_we[51] <= 1'b0 ;
				fifo_we[52] <= 1'b0 ;
				fifo_we[53] <= 1'b0 ;
				fifo_we[54] <= 1'b0 ;
				fifo_we[55] <= 1'b0 ;
				fifo_we[56] <= 1'b0 ;
				fifo_we[57] <= 1'b0 ;
				fifo_we[58] <= 1'b0 ;
				fifo_we[59] <= 1'b0 ;
				fifo_we[60] <= 1'b0 ;
				fifo_we[61] <= 1'b0 ;
				fifo_we[62] <= 1'b0 ;
				fifo_we[63] <= 1'b0 ;
			end

			CYCLE_CONV_GROUP:begin
				s_config_ready <= 1'b0 ;

				if(s_weight_ready & s_weight_valid) begin
					conv_group_cnt <= conv_group_cnt + 8 ;

					if(conv_group_cnt == `CONV_GROUP_NUM - 8) r_weight_ready <= 1'b0 ;
					else r_weight_ready <= 1'b1 ;

					//fifo_din[conv_group_cnt  ] <= s_weight[112+11: 112];
					//fifo_din[conv_group_cnt+1] <= s_weight[96 +11:  96];
					//fifo_din[conv_group_cnt+2] <= s_weight[80 +11:  80];
					//fifo_din[conv_group_cnt+3] <= s_weight[64 +11:  64];
					//fifo_din[conv_group_cnt+4] <= s_weight[48 +11:  48];
					//fifo_din[conv_group_cnt+5] <= s_weight[32 +11:  32];
					//fifo_din[conv_group_cnt+6] <= s_weight[16 +11:  16];
					//fifo_din[conv_group_cnt+7] <= s_weight[0  +11:   0];
					fifo_din[conv_group_cnt  ] <= s_weight[112+`DATA_WEIGHT_WIDTH-1: 112];
					fifo_din[conv_group_cnt+1] <= s_weight[96 +`DATA_WEIGHT_WIDTH-1:  96];
					fifo_din[conv_group_cnt+2] <= s_weight[80 +`DATA_WEIGHT_WIDTH-1:  80];
					fifo_din[conv_group_cnt+3] <= s_weight[64 +`DATA_WEIGHT_WIDTH-1:  64];
					fifo_din[conv_group_cnt+4] <= s_weight[48 +`DATA_WEIGHT_WIDTH-1:  48];
					fifo_din[conv_group_cnt+5] <= s_weight[32 +`DATA_WEIGHT_WIDTH-1:  32];
					fifo_din[conv_group_cnt+6] <= s_weight[16 +`DATA_WEIGHT_WIDTH-1:  16];
					fifo_din[conv_group_cnt+7] <= s_weight[0  +`DATA_WEIGHT_WIDTH-1:   0];

					fifo_we[conv_group_cnt  ]  <= 1'b1 ;
					fifo_we[conv_group_cnt+1]  <= 1'b1 ;
					fifo_we[conv_group_cnt+2]  <= 1'b1 ;
					fifo_we[conv_group_cnt+3]  <= 1'b1 ;
					fifo_we[conv_group_cnt+4]  <= 1'b1 ;
					fifo_we[conv_group_cnt+5]  <= 1'b1 ;
					fifo_we[conv_group_cnt+6]  <= 1'b1 ;
					fifo_we[conv_group_cnt+7]  <= 1'b1 ;

					fifo_we[conv_group_cnt-1]  <= 1'b0 ;
					fifo_we[conv_group_cnt-2]  <= 1'b0 ;
					fifo_we[conv_group_cnt-3]  <= 1'b0 ;
					fifo_we[conv_group_cnt-4]  <= 1'b0 ;
					fifo_we[conv_group_cnt-5]  <= 1'b0 ;
					fifo_we[conv_group_cnt-6]  <= 1'b0 ;
					fifo_we[conv_group_cnt-7]  <= 1'b0 ;
					fifo_we[conv_group_cnt-8]  <= 1'b0 ;
				end
				else begin
					r_weight_ready <= 1'b1 ;
					fifo_we[conv_group_cnt  ]  <= 1'b0 ;
					fifo_we[conv_group_cnt+1]  <= 1'b0 ;
					fifo_we[conv_group_cnt+2]  <= 1'b0 ;
					fifo_we[conv_group_cnt+3]  <= 1'b0 ;
					fifo_we[conv_group_cnt+4]  <= 1'b0 ;
					fifo_we[conv_group_cnt+5]  <= 1'b0 ;
					fifo_we[conv_group_cnt+6]  <= 1'b0 ;
					fifo_we[conv_group_cnt+7]  <= 1'b0 ;

					fifo_we[conv_group_cnt-1]  <= 1'b0 ;
					fifo_we[conv_group_cnt-2]  <= 1'b0 ;
					fifo_we[conv_group_cnt-3]  <= 1'b0 ;
					fifo_we[conv_group_cnt-4]  <= 1'b0 ;
					fifo_we[conv_group_cnt-5]  <= 1'b0 ;
					fifo_we[conv_group_cnt-6]  <= 1'b0 ;
					fifo_we[conv_group_cnt-7]  <= 1'b0 ;
					fifo_we[conv_group_cnt-8]  <= 1'b0 ;
				end
			end

			CYCLE_CONV_3_3:begin
				conv_group_cnt <= 8'd0;
				r_weight_ready <= 1'b0;
				cycle_cnt      <= cycle_cnt + 1'b1 ;

				fifo_we[conv_group_cnt-1]  <= 1'b0 ;
				fifo_we[conv_group_cnt-2]  <= 1'b0 ;
				fifo_we[conv_group_cnt-3]  <= 1'b0 ;
				fifo_we[conv_group_cnt-4]  <= 1'b0 ;
				fifo_we[conv_group_cnt-5]  <= 1'b0 ;
				fifo_we[conv_group_cnt-6]  <= 1'b0 ;
				fifo_we[conv_group_cnt-7]  <= 1'b0 ;
				fifo_we[conv_group_cnt-8]  <= 1'b0 ;
			end

			END:out_valid_ctrl <= 1'b1 ;
		endcase
	end


	genvar i ;
	generate
		for (i=0; i<64; i=i+1) begin:fifo_gen
			fifo_w4_d512_fwft fifo (
				.clk(clk),                  // input wire clk
				.srst(~rst_n),                // input wire rst
				.din(fifo_din[i]),                  // input wire [11 : 0] din

				.wr_en(fifo_we[i]),              // input wire wr_en
				.rd_en(m_weight_ready[i]),              // input wire rd_en
				.dout(fifo_dout[i]),                // output wire [11 : 0] dout
				.full(),                // output wire full
				.empty(),              // output wire empty
				.valid(fifo_valid[i]),            // output wire valid
				.data_count(weight_fifo_dcnt[i]),          // output wire [9 : 0] data_count
				.prog_full(prog_full[i])
			);

			assign m_weight_valid[i] = fifo_valid[i] ;
			assign m_weight_data [`DATA_WEIGHT_WIDTH*(i+1)-1 : `DATA_WEIGHT_WIDTH*i] = fifo_dout[i] ;
		end
	endgenerate

	assign s_weight_ready = ~prog_full[0] & r_weight_ready;

endmodule
