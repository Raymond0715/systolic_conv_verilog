// --------------------------------------------------------------------------------------
// Company:
// Engineer:
//
// Create Date: 2021/11/15
// Design Name:
// Module Name: reorder
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
//      Take 56 * 56 * 256 as example.
//
//      Mode0: full weight  Mode1: full act
//
//      In mode0, each sum_din cycle as :
//
//      line 1 to 56
//          ch_out 1-64, 65-128, 129-192, 193-256
//              pix 1-56;
//
//      So this module will regard ecah 8 ch_out as a group,
//      and round-robin these channles until reaching the end of current line.
//      and directly write data to DDR;
//
//      In mode1, each sum_din cycle as :
//
//      total 1 to 4
//          line 1 to 56
//              ch_out 1-64, 65-1 // ch_out 1-64, 65-128 (total==2: ch_out 129-192, 193-256)
//                  pix 1-56;
//
//      So this module will also regard each 8 ch_out as a group,
//      and round-robin these channles until reaching the end of current line.
//      and write data to DDR for multi-times with offset address;
//
//      OUTPUT:
//      total 1 to 4(if mode1)
//          line 1-56
//              ch1-8(8ch as per clk),8-16....
//                  pix1-56
// --------------------------------------------------------------------------------------

`include "DEFINE.vh"
`include "SIM_CTRL.vh"

module reorder (
	input                                       clk             ,
	input                                       rst_n           ,

	input                                       s_config_valid  ,
	output  reg                                 s_config_ready  ,
	input           [31:0]                      s_config_data   ,

	input                                       sum_valid       ,
	input           [`DATA_INTER_WIDTH*64-1 :0] sum_data        ,
	output                                      ro_busy         ,

	output          [`DATA_INTER_WIDTH*8-1 :0]  reorder_data    ,
	output                                      reorder_valid   ,
	input                                       reorder_ready   ,

	output          [3:0]                       status_ro
);

// ----------------------------------------------------------------
// Xlinx IP requests data width less than 1024, so here seperate

	wire [7:0] fifo_valid, fifo_prog_full;
	wire [`DATA_INTER_WIDTH*8-1:0] fifo_din  [7:0];
	wire [`DATA_INTER_WIDTH*8-1:0] fifo_dout [7:0];
	reg  [7:0] fifo_rd_en;

	genvar i ;
	generate
		for (i=0; i<8; i=i+1) begin:fifo_gen

			//reorder_fifo_w192_d1k_fwft fifo (
			reorder_fifo_w128_d1k_fwft fifo (
				.clk(clk),                                // input wire clk
				.srst(~rst_n),                            // input wire srst
				.din(fifo_din[i]),                        // input wire [95 : 0] din
				.wr_en(sum_valid), //& sum_ready),        // input wire wr_en
				.rd_en(fifo_rd_en[i] & reorder_ready),    // input wire rd_en
				.dout(fifo_dout[i]),                      // output wire [95 : 0] dout
				.valid(fifo_valid[i]),                    // output wire valid
				.prog_full(fifo_prog_full[i])             // output wire prog_full
				//.full(full),                            // output wire full
				//.empty(empty),                          // output wire empty
				//.wr_rst_busy(wr_rst_busy),              // output wire wr_rst_busy
				//.rd_rst_busy(rd_rst_busy)               // output wire rd_rst_busy
			);

			assign fifo_din[i] = {
				sum_data[`DATA_INTER_WIDTH*(64-i*8-0)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-1)],
				sum_data[`DATA_INTER_WIDTH*(64-i*8-1)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-2)],
				sum_data[`DATA_INTER_WIDTH*(64-i*8-2)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-3)],
				sum_data[`DATA_INTER_WIDTH*(64-i*8-3)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-4)],
				sum_data[`DATA_INTER_WIDTH*(64-i*8-4)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-5)],
				sum_data[`DATA_INTER_WIDTH*(64-i*8-5)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-6)],
				sum_data[`DATA_INTER_WIDTH*(64-i*8-6)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-7)],
				sum_data[`DATA_INTER_WIDTH*(64-i*8-7)-1/*-13*/ :`DATA_INTER_WIDTH*(64-i*8-8)]  };
		end
	endgenerate

	assign ro_busy = fifo_prog_full>0 ? 1:0 ;

// ----------------------------------------------------------------

	reg [15:0] pix_cnt, chout_cnt, line_cnt, total_cnt;
	reg [15:0] ch_perwtile;
	reg [11:0] img_w, img_h;
	reg        mode_1_1;
	reg [7 :0] w_tile;
	reg        cycle_finish;
	reg [2:0]  current_fifo;
	reg [2:0]  config_cnt;
	reg        init_weight;

	localparam CONFIG               = 0 ;
	localparam CYCLE                = 1 ;

	reg [2:0] cs ;
	reg [2:0] ns ;

	assign status_ro = cs;

	//! fsm_extract
	always @ (posedge clk) begin
		if (~rst_n) begin
			cs <= CONFIG;
		end
		else begin
			cs <= ns;
		end
	end

	//! fsm_extract
	always @ (*) begin
		if (~rst_n) begin
			ns = CONFIG;
		end else begin
			case (cs)
				CONFIG:begin
					ns = (config_cnt>1) ? CYCLE : CONFIG ;
				end

				CYCLE:begin
					ns = cycle_finish ? CONFIG :CYCLE;
				end

				default: ns = CONFIG;
			endcase
		end
	end

	//! fsm_extract
	always @ (posedge clk) begin
		if (~rst_n) begin
			config_cnt <= 'd0 ;
		end
		else begin
			case (ns)
				CONFIG: begin
					pix_cnt         <= 'd0 ;
					chout_cnt       <= 'd0 ;
					line_cnt        <= 'd0 ;
					total_cnt       <= 'd0 ;
					cycle_finish    <= 'd0 ;

					fifo_rd_en      <= 8'd1;
					current_fifo    <= 'd0 ;

					if (s_config_valid & s_config_ready) begin
						config_cnt <= config_cnt + 1'b1 ;
					end

					case (config_cnt)
						0: {init_weight, mode_1_1, img_h, img_w} <= s_config_data ;
						1: begin
							{ch_perwtile,w_tile} <= s_config_data ;
							if(~mode_1_1) img_h <= img_h + 1;
						end
					endcase

					if (config_cnt >= 1 && ~init_weight) s_config_ready  <= 'd0;
					else if (config_cnt >= 1 && init_weight) begin
						config_cnt <= 'd0;
						s_config_ready <= 'd1;
					end
					else s_config_ready <= 'd1;

				end

				CYCLE:begin
					s_config_ready <= 1'b0;
					config_cnt <= 'd0;

					if(((fifo_valid & fifo_rd_en)>0) & reorder_ready)begin
						// cal axis
						if (pix_cnt + 1'b1 < img_w)begin
							pix_cnt <= pix_cnt + 1'b1 ;
							//reorder_data  <= fifo_dout[current_fifo];
						end
						else begin
							pix_cnt <= 'd0 ;
							fifo_rd_en <= {fifo_rd_en[6:0],fifo_rd_en[7]};
							current_fifo <= current_fifo + 1'b1;
							//reorder_data  <= fifo_dout[current_fifo];

							if (chout_cnt + 8'd8 < ch_perwtile) chout_cnt <= chout_cnt + 8'd8 ;
							else begin
								chout_cnt <= 'd0 ;
								if (line_cnt + 1'b1 < img_h) line_cnt <= line_cnt + 1'b1 ;
								else begin
									line_cnt <= 'd0 ;
									if (total_cnt + 1'b1 < w_tile) total_cnt <= total_cnt + 1'b1 ;
									else begin
										cycle_finish <= 1'b1 ;
										//$stop;
									end
								end
							end
						end
					end
				end
			endcase
		end
	end

	assign reorder_data  = fifo_dout[current_fifo];
	assign reorder_valid = fifo_valid[current_fifo] & fifo_rd_en[current_fifo] ;

endmodule
