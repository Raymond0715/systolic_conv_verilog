//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2021/06/20 23:45:03
// Design Name:
// Module Name: partial_sum
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

module conv_sum(
	input                                       clk             ,
	input                                       rst_n           ,

	input                                       s_config_valid  ,
	output  reg                                 s_config_ready  ,
	input           [31:0]                      s_config_data   ,

	input           [`DATA_INTER_WIDTH*64-1 :0] inter_data_1    ,
	input           [`DATA_INTER_WIDTH*64-1 :0] inter_data_2    ,
	input           [`DATA_INTER_WIDTH*64-1 :0] inter_data_3    ,
	input                                       inter_valid     ,

	output  reg                                 busy            ,

	output          [`DATA_INTER_WIDTH*64-1 :0] sum_data        ,
	output  reg                                 sum_valid       ,

	output          [3:0]                       status_sum
);

	//CTRL
	reg       count_clr;
	reg [10:0] rst_cnt  ;

	//instance
	reg         ram_we, ram_we_d1;
	reg  [8 :0] wr_addr,wr_addr_d1, rd_addr;
	wire [`DATA_INTER_WIDTH*64-1:0] ram1_wrdata_bus,ram2_wrdata_bus,ram3_wrdata_bus;
	wire [`DATA_INTER_WIDTH*64-1:0] ram1_rddata,ram2_rddata,ram3_rddata;
	wire [`DATA_INTER_WIDTH*64-1:0] ram1_rddata_raw,ram2_rddata_raw,ram3_rddata_raw;
	reg  [`DATA_INTER_WIDTH*64-1:0] ram1_wrdata_d1,ram2_wrdata_d1,ram3_wrdata_d1;
	reg  [`DATA_INTER_WIDTH-1:0]    ram1_wrdata[63:0];
	reg  [`DATA_INTER_WIDTH-1:0]    ram2_wrdata[63:0];
	reg  [`DATA_INTER_WIDTH-1:0]    ram3_wrdata[63:0];

	assign ram1_rddata = (wr_addr_d1 == rd_addr) & ram_we_d1 ? ram1_wrdata_d1 : ram1_rddata_raw;
	assign ram2_rddata = (wr_addr_d1 == rd_addr) & ram_we_d1 ? ram2_wrdata_d1 : ram2_rddata_raw;
	assign ram3_rddata = (wr_addr_d1 == rd_addr) & ram_we_d1 ? ram3_wrdata_d1 : ram3_rddata_raw;

	always @ (posedge clk) begin
		ram1_wrdata_d1 <= ram1_wrdata_bus;
		ram2_wrdata_d1 <= ram2_wrdata_bus;
		ram3_wrdata_d1 <= ram3_wrdata_bus;
	end

	ram_1024_512 ram1 (
		.clka(clk),
		.clkb(clk),
		.rstb((~rst_n)|count_clr),
		.wea(ram_we),
		.addra(wr_addr),
		.dina(ram1_wrdata_bus),
		.addrb(rd_addr),
		.doutb(ram1_rddata_raw)
	);

	ram_1024_512 ram2 (
		.clka(clk),
		.clkb(clk),
		.rstb((~rst_n)|count_clr),
		.wea(ram_we),
		.addra(wr_addr),
		.dina(ram2_wrdata_bus),
		.addrb(rd_addr),
		.doutb(ram2_rddata_raw)
	);

	ram_1024_512 ram3 (
		.clka(clk),
		.clkb(clk),
		.rstb((~rst_n)|count_clr),
		.wea(ram_we),
		.addra(wr_addr),
		.dina(ram3_wrdata_bus),
		.addrb(rd_addr),
		.doutb(ram3_rddata_raw)
	);


	reg [23:0] pkg_len ;
	reg [23:0] pkg_cnt ;
	reg [31:0] dout_cnt;
	reg [31:0] total_len;
	reg [11:0] rd_addr_pre;
	reg extra_rd = 0 ;

	//CONFIG
	reg [9:0]  o_chgroup ;
	reg [11:0] ch_cycle_cnt ;
	reg [11:0] img_h;
	reg [11:0] img_w;
	reg [11:0] chout_group_perwram;
	reg mode_1_1;
	reg [2:0] config_cnt;

	//FSM
	localparam IDLE   = 1;
	localparam CONFIG = 2;
	localparam CAL    = 3;
	localparam CYCLE  = 4;
	localparam CLEAR  = 5;
	localparam EXTRA  = 6;

	reg [3:0] cs ;
	reg [3:0] ns ;

	assign status_sum = cs ;

	//! fsm_extract
	always @ (posedge clk) begin
		if (~rst_n) begin
			cs <= IDLE;
		end
		else begin
			cs <= ns;
		end
	end

	//! fsm_extract
	always @ (*) begin
		case (cs)
			IDLE:begin
				ns = CONFIG;
			end

			CONFIG:begin
				ns = (config_cnt>2)? CAL : CONFIG;
			end

			CAL:begin
				ns = CYCLE ;
			end

			CYCLE:begin
				if (pkg_cnt == pkg_len) begin
					ns = mode_1_1? CLEAR: EXTRA ;
				end
				else ns = CYCLE;
			end

			EXTRA:
				if(rd_addr_pre == img_w * chout_group_perwram) ns = CLEAR ;
				else ns = EXTRA;

			CLEAR: begin
				if (rst_cnt >= 511) begin
					if (dout_cnt == total_len) ns = IDLE;
					else ns = CYCLE;
				end
				else ns = CLEAR;
			end

			default: ns = IDLE;
		endcase
	end

	//! fsm_extract
	always @ (posedge clk) begin
		case (ns)
			IDLE: begin
				s_config_ready <= 1'b0 ;
				count_clr <= 1'b0 ;
				dout_cnt  <= 'd0 ;
				rst_cnt   <= 'd0 ;
				total_len <= 'd0 ;
				pkg_len   <= 'd0 ;
				pkg_cnt   <= 'd0 ;
				busy      <= 'd1 ;
				config_cnt<= 'd0 ;

				rd_addr_pre <= $signed (-1);
			end

			CONFIG: begin
				count_clr <= 1'b0 ;

				if (s_config_valid & s_config_ready) begin
					config_cnt <= config_cnt + 1'b1 ;
				end

				case (config_cnt)
					0: {img_h,img_w} <= s_config_data ;
					1: {o_chgroup,ch_cycle_cnt}  <= s_config_data ;
					2: {mode_1_1, chout_group_perwram} <= s_config_data ;
				endcase

				if (config_cnt >= 2) s_config_ready  <= 'd0;
				else s_config_ready  <= 'd1;

				busy      <= 'd1 ;
			end

			CAL: begin
				pkg_len <= img_h * img_w * chout_group_perwram ; ////
				total_len <= img_h * img_w * o_chgroup ; ////
				busy      <= 'd1 ;
				count_clr <= 1'b1 ;
			end

			CYCLE: begin
				busy      <= 'd0 ;
				count_clr <= 1'b0 ;
				rst_cnt   <= $signed(-1);
				rd_addr_pre <= $signed(-1);
				if (sum_valid)begin
					dout_cnt  <= dout_cnt + 1'b1 ;
					pkg_cnt   <= pkg_cnt + 1'b1 ;
				end
			end

			EXTRA: begin
				rd_addr_pre <= rd_addr_pre + 1 ;
				if (rd_addr_pre + 1 == img_w * chout_group_perwram) extra_rd <= 0 ;
				else extra_rd <= 1 ;
			end

			CLEAR: begin
				extra_rd <= 0 ;
				busy     <= 'd1 ;
				pkg_cnt  <='d0;
				count_clr <= 1'b1 ;
				rst_cnt <= rst_cnt + 1'b1 ;
			end

			default:begin
				s_config_ready <= 1'b0 ;
				count_clr <= 1'b0 ;
				dout_cnt  <= 'd0 ;
				rst_cnt   <= 'd0 ;
				total_len <= 'd0 ;
				pkg_len   <= 'd0 ;
				pkg_cnt   <= 'd0 ;
				busy      <= 'd1 ;
				config_cnt<= 'd0 ;

				rd_addr_pre <= $signed (-1);
			end
		endcase
	end


	//COUNT
		reg [11:0] cnt_img_w ;
		reg [11:0] cnt_img_h ;
		reg [11:0] cnt_ch_in ;
		reg [11:0] cnt_ch_out;

		//img_w
		always @ (posedge clk) begin
			if (count_clr) begin
				cnt_img_w <= 'd0;
			end
			else if (inter_valid) begin
				if (cnt_img_w + 1 == img_w) cnt_img_w <= 'd0 ;
				else cnt_img_w <= cnt_img_w + 1 ;
			end
		end

		//ch_in
		always @ (posedge clk) begin
			if (count_clr) begin
				cnt_ch_in <= 'd0;
			end
			else if ((inter_valid) & (cnt_img_w + 1 == img_w)) begin
				if (cnt_ch_in + 1 == ch_cycle_cnt) cnt_ch_in <= 'd0 ;
				else cnt_ch_in <= cnt_ch_in + 1 ;
			end
		end

		//ch_out
		always @ (posedge clk) begin
			if (count_clr) begin
				cnt_ch_out <= 'd0;
			end
			else if ((inter_valid) & (cnt_img_w + 1 == img_w) & (cnt_ch_in + 1 == ch_cycle_cnt)) begin
				if (cnt_ch_out + 1 == chout_group_perwram) cnt_ch_out <= 'd0 ;
				else cnt_ch_out <= cnt_ch_out + 1 ;
			end
		end

		//img_w,start_ram
		always @ (posedge clk) begin
			if (count_clr) begin
				cnt_img_h <= 'd0;
			end
			else if ((inter_valid)
				& (cnt_img_w + 1 == img_w)
				& (cnt_ch_in + 1 == ch_cycle_cnt)
				& (cnt_ch_out + 1 == o_chgroup)) begin
				if (cnt_img_h + 1 == img_h) cnt_img_h <= 'd0 ;
				else cnt_img_h <= cnt_img_h + 1 ;
			end
		end


	//RAM CTRL
	reg [2:0] ram_mask,ram_mask_d1;
	reg       ram_mask_en,ram_mask_en_d1;
	reg [1:0] start_ram,start_ram_d1 ;
	reg       wr_through, wr_through_d1, wr_through_d2;

	//wr_through
	always @ (posedge clk) begin
		if (count_clr) begin
			wr_through <= 'd0;
		end
		else if (cnt_ch_in == 0) begin
			wr_through <= 'd1;
		end
		else begin
			wr_through <= 'd0;
		end

		wr_through_d1 <= wr_through;
		wr_through_d2 <= wr_through_d1;
	end

	//ram din mask(to determine write through or write acc)
	always @ (posedge clk) begin
		if (count_clr | mode_1_1 | (~rst_n)) begin
			ram_mask    <= 3'b101;
			ram_mask_en <= 1;
			start_ram   <= 'd2;
		end
		else if ((inter_valid) & (cnt_img_w  == 0) & (cnt_ch_in  == 0)) begin
			ram_mask_en <= 1 ;

			if(cnt_ch_out  == 0) begin
				if (start_ram == 2) start_ram <= 'd0 ;
				else start_ram <= start_ram + 1 ;

				ram_mask <= {ram_mask[1:0],ram_mask[2]} ;

			end

		end
		else if ((inter_valid) & (cnt_img_w  == 0)) ram_mask_en <= 0 ;

	end

	always @ (posedge clk) begin
		ram_mask_d1 <= ram_mask;
		ram_mask_en_d1 <= ram_mask_en;
		start_ram_d1 <= start_ram;
	end


	//rd ctrl
	reg [`DATA_INTER_WIDTH*64-1 :0] inter_data_1_d1, inter_data_2_d1, inter_data_3_d1;
	reg [`DATA_INTER_WIDTH*64-1 :0] inter_data_1_d2, inter_data_2_d2, inter_data_3_d2;
	reg inter_valid_d1,inter_valid_d2;
	reg [8:0] rd_addr_d1 ;

	always @ (posedge clk) begin
		inter_valid_d1  <= inter_valid  ;
		inter_valid_d2  <= inter_valid_d1  ;

		inter_data_1_d1 <= inter_data_1 ;
		inter_data_2_d1 <= inter_data_2 ;
		inter_data_3_d1 <= inter_data_3 ;

		inter_data_1_d2 <= inter_data_1_d1 ;
		inter_data_2_d2 <= inter_data_2_d1 ;
		inter_data_3_d2 <= inter_data_3_d1 ;

	end

	always @(posedge clk ) begin
		if (count_clr) rd_addr <= 'd0;
		else if (extra_rd) rd_addr <= rd_addr_pre;
		else if (inter_valid) rd_addr <= cnt_img_w + img_w * cnt_ch_out;

		rd_addr_d1  <= rd_addr ;
		wr_addr     <= count_clr ? rst_cnt: rd_addr_d1;
		ram_we      <= count_clr ? 1: inter_valid_d2 ;

		ram_we_d1   <= ram_we;
		wr_addr_d1  <= wr_addr;
	end

	genvar i;
	generate
		for (i=0; i<64; i=i+1) begin:switch_gen
			always @(posedge clk ) begin
				case(start_ram_d1)
					0: begin
						ram1_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[0])) ?
								inter_data_1_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram1_rddata[(64-i)*`DATA_INTER_WIDTH-1: (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_1_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];

						ram2_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[1])) ?
								inter_data_2_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram2_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_2_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];

						ram3_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[2])) ?
								inter_data_3_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram3_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_3_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];
					end

					1: begin
						ram1_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[0])) ?
								inter_data_3_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram1_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_3_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];

						ram2_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[1])) ?
								inter_data_1_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram2_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_1_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];

						ram3_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[2])) ?
								inter_data_2_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram3_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_2_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];
					end

					2: begin
						ram1_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[0])) ?
								inter_data_2_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram1_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_2_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];

						ram2_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[1])) ?
								inter_data_3_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram2_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_3_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];

						ram3_wrdata[i] <= count_clr ?
							0
							: ((mode_1_1 & wr_through_d2)|(ram_mask_en_d1 & ~ram_mask_d1[2])) ?
								inter_data_1_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
								: ram3_rddata[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]
									+ inter_data_1_d2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH];
					end

					default:begin
						ram1_wrdata[i] <= 0;
						ram2_wrdata[i] <= 0;
						ram3_wrdata[i] <= 0;
					end
				endcase
			end

			assign ram1_wrdata_bus[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH] =
				count_clr ? 0 : ram1_wrdata[i];
			assign ram2_wrdata_bus[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH] =
				count_clr ? 0 : ram2_wrdata[i];
			assign ram3_wrdata_bus[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH] =
				count_clr ? 0 : ram3_wrdata[i];
		end
	endgenerate


	// OUT SIGNAL GEN
	reg out_start, out_start_d1, out_start_d2;
	reg extra_rd_d1, extra_rd_d2 ;

	always @ (posedge clk) begin
		if (cnt_ch_in + 1 == ch_cycle_cnt) out_start <= 1'b1 ;
		else out_start <= 1'b0;

		out_start_d1 <= out_start;
		out_start_d2 <= out_start_d1;
	end

	always @ (posedge clk) begin
		extra_rd_d1 <= extra_rd ;
		extra_rd_d2 <= extra_rd_d1;

		if(extra_rd_d1) begin
			if(rd_addr < img_w * chout_group_perwram) sum_valid <= 1;
			else sum_valid <= 0 ;
		end
		else sum_valid <=  inter_valid_d2 & out_start_d2;
	end

	//wire [`DATA_INTER_WIDTH*64-1 :0] sum_data_reverse;

	assign sum_data =
		extra_rd_d2?
			(start_ram_d1 == 0) ?
				ram2_rddata : (start_ram_d1 == 1) ? ram3_rddata : ram1_rddata
			: ((start_ram_d1 == 0) | mode_1_1) ?
				ram1_wrdata_bus : (start_ram_d1 == 1) ? ram2_wrdata_bus : ram3_wrdata_bus ;


endmodule
