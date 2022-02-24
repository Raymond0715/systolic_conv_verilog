
module data_gen # (
	parameter  Width       =  32,
	parameter  CONFIG_LEN  =  2048,//脉冲�?
	parameter  FRAME_NUM   =  1,//距�?�门
	parameter  Data_Path
)
(
	input                  i_sys_clk,
	input                  i_sys_rst_n,

	input                  i_start,

	output [Width-1: 0]    O_chan_cha1_ph_tdata,

	output                 O_chan_ph_tvalid,
	output                 O_chan_ph_tlast,
	input                  O_chan_ph_tready

	);


	reg                r_axis_data_tvalid;
	reg                r_axis_config_tvalid;

	reg  [Width-1: 0]  input_data1[0:FRAME_NUM*CONFIG_LEN-1];


	initial begin
		$readmemh(Data_Path,input_data1,0,FRAME_NUM*CONFIG_LEN-1);
		//$readmemh("/home/yuheihei/LINK2_SFAR/LINK2.SFAR.matlab/din.txt",input_data1,0,FRAME_NUM*CONFIG_LEN-1);
	end

	// ----------------------------------------------------------
	reg [64:0]      r_config_cnt   = 64'b0   ;
	reg             valid_ctrl = 0 ;

	always @(posedge i_sys_clk) begin
		if (~i_sys_rst_n) begin
			r_config_cnt <= 0;
			valid_ctrl <= 1;
		end
		else if (r_config_cnt==(FRAME_NUM*CONFIG_LEN-1) && O_chan_ph_tvalid && O_chan_ph_tready) begin
			r_config_cnt <= 0;
			valid_ctrl <=  0;
		end
		else if (O_chan_ph_tvalid && O_chan_ph_tready)
			r_config_cnt <= r_config_cnt + 1;
		else;
	end

	always @(posedge i_sys_clk) begin
		if(~i_sys_rst_n)begin
				r_axis_config_tvalid <= 1'b0;
			end
		else if (r_config_cnt==(FRAME_NUM*CONFIG_LEN-1) && O_chan_ph_tvalid && O_chan_ph_tready)begin
				r_axis_config_tvalid <= 1'b0;
			end
		else if (i_start)begin
				r_axis_config_tvalid <= 1'b1;
			end
		else begin
				r_axis_config_tvalid <= r_axis_config_tvalid;
			end
	end

	assign O_chan_ph_tvalid = r_axis_config_tvalid & valid_ctrl;
	assign O_chan_cha1_ph_tdata = input_data1[r_config_cnt];

	assign O_chan_ph_tlast = ( (r_config_cnt % CONFIG_LEN) == CONFIG_LEN-1 ) ? 1 : 0;


endmodule
