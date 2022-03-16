`include "DEFINE.vh"
`include "SIM_CTRL.vh"
`timescale 1ns/1ps

module Top_PL # (
	`ifdef SIM
		parameter CONV_NUM = 8
		//this should be 64 on actual chip,change it to 1,2,3.. to accelarate simulation while debug.
	`else
		parameter CONV_NUM = 64
	`endif
)(
	input clk,
	input rst_n,

	// config
	input               s_axis_config_tvalid    ,
	output              s_axis_config_tready    ,
	input  [31:0]       s_axis_config_tdata     ,

	// act in
	input               s_axis_act_tvalid,
	output              s_axis_act_tready,
	input  [31:0]       s_axis_act_tdata,
	input               s_axis_act_tlast,
	input  [3:0]        s_axis_act_tkeep,

	// weight in
	input               s_axis_weight_tvalid,
	output              s_axis_weight_tready,
	input  [31:0]       s_axis_weight_tdata,
	input               s_axis_weight_tlast,
	input  [3:0]        s_axis_weight_tkeep,

	/*****Datamover1*****/
	//m_axis_s2mm
	output [127:0]      m_axis_s2mm_tdata,
	output [15:0]       m_axis_s2mm_tkeep ,
	output              m_axis_s2mm_tlast ,
	input               m_axis_s2mm_tready,
	output              m_axis_s2mm_tvalid,

	//s_axis_mm2s
	input  [127:0]      s_axis_mm2s_tdata,
	input  [15:0]       s_axis_mm2s_tkeep,
	input               s_axis_mm2s_tlast,
	output              s_axis_mm2s_tready,
	input               s_axis_mm2s_tvalid,

	//m_axis_s2mm_cmd
	input               m_axis_s2mm_cmd_tready,
	output              m_axis_s2mm_cmd_tvalid,
	output [71:0]       m_axis_s2mm_cmd_tdata ,

	//m_axis_mm2s_cmd
	input               m_axis_mm2s_cmd_tready,
	output              m_axis_mm2s_cmd_tvalid,
	output [71:0]       m_axis_mm2s_cmd_tdata ,

	//s_axis_mm2s_sts
	output              s_axis_mm2s_sts_tready,
	input               s_axis_mm2s_sts_tvalid,
	input  [7 :0]       s_axis_mm2s_sts_tdata ,
	input               s_axis_mm2s_sts_tlast ,
	input               s_axis_mm2s_sts_tkeep ,

	//s_axis_s2mm_sts
	output              s_axis_s2mm_sts_tready ,
	input               s_axis_s2mm_sts_tvalid,
	input  [7 :0]       s_axis_s2mm_sts_tdata ,
	input               s_axis_s2mm_sts_tlast ,
	input               s_axis_s2mm_sts_tkeep ,

	/*****Datamover4*****/
	//m_axis_s2mm
	output [127:0]      m_axis_weight_s2mm_tdata,
	output [15:0]       m_axis_weight_s2mm_tkeep ,
	output              m_axis_weight_s2mm_tlast ,
	input               m_axis_weight_s2mm_tready,
	output              m_axis_weight_s2mm_tvalid,

	//s_axis_mm2s
	input  [127:0]      s_axis_weight_mm2s_tdata,
	input  [15:0]       s_axis_weight_mm2s_tkeep,
	input               s_axis_weight_mm2s_tlast,
	output              s_axis_weight_mm2s_tready,
	input               s_axis_weight_mm2s_tvalid,

	//m_axis_s2mm_cmd
	input               m_axis_weight_s2mm_cmd_tready,
	output              m_axis_weight_s2mm_cmd_tvalid,
	output [71:0]       m_axis_weight_s2mm_cmd_tdata ,

	//m_axis_mm2s_cmd
	input               m_axis_weight_mm2s_cmd_tready,
	output              m_axis_weight_mm2s_cmd_tvalid,
	output [71:0]       m_axis_weight_mm2s_cmd_tdata ,

	//s_axis_mm2s_sts
	output              s_axis_weight_mm2s_sts_tready,
	input               s_axis_weight_mm2s_sts_tvalid,
	input  [7 :0]       s_axis_weight_mm2s_sts_tdata ,
	input               s_axis_weight_mm2s_sts_tlast ,
	input               s_axis_weight_mm2s_sts_tkeep ,

	//s_axis_s2mm_sts
	output              s_axis_weight_s2mm_sts_tready ,
	input               s_axis_weight_s2mm_sts_tvalid,
	input  [7 :0]       s_axis_weight_s2mm_sts_tdata ,
	input               s_axis_weight_s2mm_sts_tlast ,
	input               s_axis_weight_s2mm_sts_tkeep ,

	/*****Datamover2*****/
	//m_axis_s2mm
	output [31:0]       m_axis_biass2mm_tdata,
	output [3:0]        m_axis_biass2mm_tkeep ,
	output              m_axis_biass2mm_tlast ,
	input               m_axis_biass2mm_tready,
	output              m_axis_biass2mm_tvalid,

	//s_axis_mm2s
	input  [31:0]       s_axis_biasmm2s_tdata,
	input  [3:0]        s_axis_biasmm2s_tkeep,
	input               s_axis_biasmm2s_tlast,
	output              s_axis_biasmm2s_tready,
	input               s_axis_biasmm2s_tvalid,

	//m_axis_s2mm_cmd
	input               m_axis_biass2mm_cmd_tready,
	output              m_axis_biass2mm_cmd_tvalid,
	output [71:0]       m_axis_biass2mm_cmd_tdata ,

	//m_axis_mm2s_cmd
	input               m_axis_biasmm2s_cmd_tready,
	output              m_axis_biasmm2s_cmd_tvalid,
	output [71:0]       m_axis_biasmm2s_cmd_tdata ,

	//s_axis_mm2s_sts
	output              s_axis_biasmm2s_sts_tready,
	input               s_axis_biasmm2s_sts_tvalid,
	input  [7 :0]       s_axis_biasmm2s_sts_tdata ,
	input               s_axis_biasmm2s_sts_tlast ,
	input               s_axis_biasmm2s_sts_tkeep ,

	//s_axis_s2mm_sts
	output              s_axis_biass2mm_sts_tready ,
	input               s_axis_biass2mm_sts_tvalid,
	input  [7 :0]       s_axis_biass2mm_sts_tdata ,
	input               s_axis_biass2mm_sts_tlast ,
	input               s_axis_biass2mm_sts_tkeep ,

	/*****Datamover3*****/
	//m_axis_s2mm
	output [127:0]      m_axis_wrs2mm_tdata,
	output [15:0]       m_axis_wrs2mm_tkeep ,
	output              m_axis_wrs2mm_tlast ,
	input               m_axis_wrs2mm_tready,
	output              m_axis_wrs2mm_tvalid,

	//m_axis_s2mm_cmd
	input               m_axis_wrs2mm_cmd_tready,
	output              m_axis_wrs2mm_cmd_tvalid,
	output [71:0]       m_axis_wrs2mm_cmd_tdata ,

	//s_axis_s2mm_sts
	output              s_axis_wrs2mm_sts_tready ,
	input               s_axis_wrs2mm_sts_tvalid,
	input  [7 :0]       s_axis_wrs2mm_sts_tdata ,
	input               s_axis_wrs2mm_sts_tlast ,
	input               s_axis_wrs2mm_sts_tkeep ,

	// result out
	input                m_axis_output2ps_tready,
	output [127:0]       m_axis_output2ps_tdata,
	output               m_axis_output2ps_tvalid,
	output               m_axis_output2ps_tlast,
	output [15:0]        m_axis_output2ps_tkeep,

	// frame count
	output [31:0]       frame_cnt

);

`ifdef SIM
	initial begin
		#5000
		$display("Scene: %dx%dx%dx%dx%d",`IMG_H,`IMG_W,`I_CH,`O_CH, CONV_NUM);
	end

	`ifdef SCENE1
		reg [0:0]  workmode  = 0;
		reg [0:0]  act_source = 1;
		reg [0:0]  weight_bias_source = 1 ;
		reg [0:0]  relumode  =1;
		reg [0:0]  switch_relu =1 ;
		reg [0:0]  switch_bias =1 ;
		reg [0:0]  switch_sampling =0 ;
		reg [0:0]  switch_bitintercept=1 ;
		reg [8:0]  img_w=56;
		reg [11:0] i_ch=256;
		reg [11:0] o_ch=256;
		reg [31:0] act_waddr = 32'h0;
		reg [31:0] act_raddr = 32'h0;
		reg [31:0] weight_waddr = 32'h100_0000;
		reg [31:0] weight_raddr = 32'h100_0000;
		reg [31:0] weight_wlen  = 256*256*9;
		reg [31:0] bias_waddr = 32'h200_0000;
		reg [31:0] bias_raddr = 32'h200_0000;
		reg [31:0] bias_wlen = 256;
		reg [31:0] ddr_write_addr = 32'h300_0000;
	`endif

	`ifdef SCENE2
		reg [0:0]  workmode  = 0;
		reg [0:0]  act_source = 1;
		reg [0:0]  weight_bias_source = 1 ;
		reg [0:0]  relumode  =1;
		reg [0:0]  switch_relu =1 ;
		reg [0:0]  switch_bias =1 ;
		reg [0:0]  switch_sampling =0 ;
		reg [0:0]  switch_bitintercept=1 ;
		reg [8:0]  img_w=28;
		reg        output_ps = 0;
		reg        init_weight = 0;
		reg [11:0] i_ch=512;
		reg [11:0] o_ch=512;
		reg [31:0] act_waddr = 32'h200_0000;
		reg [31:0] act_raddr = 32'h200_0000;
		reg [31:0] weight_waddr = 32'h000_0000;
		reg [31:0] weight_raddr = 32'h000_0000;
		reg [31:0] weight_wlen  = 512*512*9;
		reg [31:0] bias_waddr = 32'h100_0000;
		reg [31:0] bias_raddr = 32'h100_0000;
		reg [31:0] bias_wlen = 512;
		reg [31:0] ddr_write_addr = 32'h300_0000;
	`endif

	`ifdef SCENE5
		reg [0:0]  workmode = 1;
		reg [0:0]  act_source = 1;
		reg [0:0]  weight_bias_source = 1;
		reg [0:0]  relumode = 1;
		reg [0:0]  switch_relu = 1;
		reg [0:0]  switch_bias = 1;
		reg [0:0]  switch_sampling = 0;
		reg [0:0]  switch_bitintercept = 1;
		reg [8:0]  img_w = 13;
		reg [11:0] i_ch = 1024;
		reg [11:0] o_ch = 256;
		reg [31:0] act_waddr = 32'h0;
		reg [31:0] act_raddr = 32'h0;
		reg [31:0] weight_waddr = 32'h100_0000;
		reg [31:0] weight_raddr = 32'h100_0000;
		reg [31:0] weight_wlen  = 256*1024*1;
		reg [31:0] bias_waddr = 32'h200_0000;
		reg [31:0] bias_raddr = 32'h200_0000;
		reg [31:0] bias_wlen = 256;
		reg [31:0] ddr_write_addr = 32'h300_0000;
	`endif

	`ifdef SCENE6
		reg        workmode = 0;
		reg        act_source = 1;
		reg        weight_bias_source = 1;
		reg        relumode = 1;
		reg        switch_relu = 0;
		reg        switch_bias = 0;
		reg        switch_sampling = 0;
		reg        switch_bitintercept = 0;
		reg [8:0]  img_w = 0;
		reg        output_ps = 0;
		reg        init_weight = 1;
		reg [11:0] i_ch = 0;
		reg [11:0] o_ch = 0;
		reg [31:0] act_waddr = 32'h200_0000;
		reg [31:0] act_raddr = 32'h200_0000;
		reg [31:0] weight_waddr = 32'h000_0000;
		reg [31:0] weight_raddr = 32'h000_0000;
		reg [31:0] weight_wlen  = 27648;
		reg [31:0] bias_waddr = 32'h100_0000;
		reg [31:0] bias_raddr = 32'h100_0000;
		reg [31:0] bias_wlen = 128;
		reg [31:0] ddr_write_addr = 32'h300_0000;
	`endif

	`ifdef SCENE7
		reg        workmode = 0;
		reg        act_source = 1;
		reg        weight_bias_source = 1;
		reg        relumode = 1;
		reg        switch_relu = 0;
		reg        switch_bias = 0;
		reg        switch_sampling = 0;
		reg        switch_bitintercept = 0;
		reg [8:0]  img_w = 0;
		reg        output_ps = 0;
		reg        init_weight = 1;
		reg [11:0] i_ch = 0;
		reg [11:0] o_ch = 0;
		reg [31:0] act_waddr = 32'h200_0000;
		reg [31:0] act_raddr = 32'h200_0000;
		reg [31:0] weight_waddr = 32'h000_0000;
		reg [31:0] weight_raddr = 32'h000_0000;
		reg [31:0] weight_wlen  = 1179648;
		reg [31:0] bias_waddr = 32'h100_0000;
		reg [31:0] bias_raddr = 32'h100_0000;
		reg [31:0] bias_wlen = 512;
		reg [31:0] ddr_write_addr = 32'h300_0000;
	`endif

	`ifdef SCENE8
		reg        workmode = 0;
		reg        act_source = 1;
		reg        weight_bias_source = 1;
		reg        relumode = 1;
		reg        switch_relu = 1;
		reg        switch_bias = 1;
		reg        switch_sampling = 0;
		reg        switch_bitintercept = 0;
		reg [8:0]  img_w = 13;
		reg        output_ps = 0;
		reg        init_weight = 0;
		reg [11:0] i_ch = 256;
		reg [11:0] o_ch = 512;
		reg [31:0] act_waddr = 32'h200_0000;
		reg [31:0] act_raddr = 32'h200_0000;
		reg [31:0] weight_waddr = 32'h000_0000;
		reg [31:0] weight_raddr = 32'h000_0000;
		reg [31:0] weight_wlen  = 1179648;
		reg [31:0] bias_waddr = 32'h100_0000;
		reg [31:0] bias_raddr = 32'h100_0000;
		reg [31:0] bias_wlen = 512;
		reg [31:0] ddr_write_addr = 32'h300_0000;
	`endif

	reg [31:0] s_axis_config_tdata_sim;
	reg s_axis_config_tvalid_sim = 0;

	reg [4:0] config_cnt = 0 ;

	reg continue_sim = 0 ;

	initial begin
		wait (rst_n);
		wait (s_axis_config_tready);
		$display("[SIM][Top_PL.v] Begin configtask.");
		configtask({init_weight, output_ps, img_w, switch_bitintercept, switch_sampling, switch_bias,
			switch_relu, relumode, weight_bias_source, act_source, workmode});
		configtask({o_ch, i_ch}      );
		configtask(act_waddr        );
		configtask(act_raddr        );
		configtask(weight_waddr     );
		configtask(weight_raddr     );
		configtask(weight_wlen      );
		configtask(bias_waddr       );
		configtask(bias_raddr       );
		configtask(bias_wlen        );
		configtask(ddr_write_addr   );

		// one cycle
		`ifdef SCENE6
			$display("[SIM][Top_PL.v] One cycle.");

			workmode            <= 0;
			act_source          <= 1;
			weight_bias_source  <= 0;
			relumode            <= 1;
			switch_relu         <= 1;
			switch_bias         <= 1;
			switch_sampling     <= 1 ;
			switch_bitintercept <= 0;
			img_w               <= 208;
			output_ps           <= 0;
			init_weight         <= 0;
			i_ch                <= 16;
			o_ch                <= 64;
			act_raddr           <= 32'h200_0000;
			act_waddr           <= 32'h200_0000;
			weight_raddr        <= 32'h000_0000;
			weight_wlen         <= 9216;
			bias_raddr          <= 32'h100_0000;
			bias_wlen           <= 64;
			ddr_write_addr      <= 32'h300_0000;
		`endif

		`ifdef SCENE7
			$display("[SIM][Top_PL.v] One cycle.");

			workmode            <= 0;
			act_source          <= 1;
			weight_bias_source  <= 0;
			relumode            <= 1;
			switch_relu         <= 1;
			switch_bias         <= 1;
			switch_sampling     <= 0 ;
			switch_bitintercept <= 0;
			img_w               <= 13;
			output_ps           <= 0;
			init_weight         <= 0;
			i_ch                <= 256;
			o_ch                <= 512;
			act_raddr           <= 32'h200_0000;
			act_waddr           <= 32'h200_0000;
			weight_raddr        <= 32'h000_0000;
			weight_wlen         <= 1179648;
			bias_raddr          <= 32'h100_0000;
			bias_wlen           <= 512;
			ddr_write_addr      <= 32'h300_0000;
		`endif

		`ifdef SCENE8
			$display("[SIM][Top_PL.v] One cycle.");

			workmode            <= 0;
			act_source          <= 0;
			weight_bias_source  <= 0;
			relumode            <= 1;
			switch_relu         <= 1;
			switch_bias         <= 1;
			switch_sampling     <= 0 ;
			switch_bitintercept <= 0;
			img_w               <= 13;
			output_ps           <= 0;
			init_weight         <= 0;
			i_ch                <= 256;
			o_ch                <= 512;
			act_raddr           <= 32'h200_0000;
			act_waddr           <= 32'h200_0000;
			weight_raddr        <= 32'h000_0000;
			weight_wlen         <= 1179648;
			bias_raddr          <= 32'h100_0000;
			bias_wlen           <= 512;
			ddr_write_addr      <= 32'h400_0000;
		`endif

		wait (s_axis_config_tready);
		configtask({init_weight, output_ps, img_w, switch_bitintercept, switch_sampling, switch_bias,
			switch_relu, relumode, weight_bias_source, act_source, workmode});
		configtask({o_ch,i_ch}      );
		configtask(act_waddr        );
		configtask(act_raddr        );
		configtask(weight_waddr     );
		configtask(weight_raddr     );
		configtask(weight_wlen      );
		configtask(bias_waddr       );
		configtask(bias_raddr       );
		configtask(bias_wlen        );
		configtask(ddr_write_addr   );
		$display("[SIM][Top_PL.v] Finish configtask.");

		wait (s_axis_config_tready);

		$stop;
	end

	task configtask;
		input [31:0] data ;
		begin
			s_axis_config_tvalid_sim <= 0 ;
			#100 @(posedge clk)begin
				s_axis_config_tdata_sim  <= data;
				s_axis_config_tvalid_sim <= 1 ;
			end
			@(posedge clk)s_axis_config_tvalid_sim <= 0 ;
			#100 @(posedge clk)begin
				s_axis_config_tdata_sim  <= 0;
				s_axis_config_tvalid_sim <= 0 ;
			end
		end
	endtask
`endif

	/********************************/
	//Config
	/********************************/

	wire [31:0] m_axis_dmconfig_tdata, m_axis_dconfig_tdata,
		m_axis_wmconfig_tdata, m_axis_wconfig_tdata, m_axis_synconfig_tdata,
		m_axis_roconfig_tdata, m_axis_wbconfig_tdata, m_axis_ppconfig_tdata,
		m_axis_dmwconfig_tdata, m_axis_sumconfig_tdata;
	wire [3:0] status_config, status_wbs, status_act_manager, status_wm,
		status_dmux, status_wmux, status_sync, status_sum, status_ro, status_post,
		status_dmw;
	wire mode_1_1;
	wire m_axis_wbconfig_tvalid, m_axis_wbconfig_tready, m_axis_dmconfig_tvalid,
		m_axis_dmconfig_tready, m_axis_wmconfig_tvalid, m_axis_wmconfig_tready,
		m_axis_dconfig_tvalid, m_axis_dconfig_tready, m_axis_wconfig_tvalid,
		m_axis_wconfig_tready, m_axis_synconfig_tvalid, m_axis_synconfig_tready,
		m_axis_sumconfig_tvalid, m_axis_sumconfig_tready, m_axis_roconfig_tvalid,
		m_axis_roconfig_tready, m_axis_ppconfig_tvalid, m_axis_ppconfig_tready,
		m_axis_dmwconfig_tready, m_axis_dmwconfig_tvalid;

	ctrl ctrl (
		.clk                        (clk                        ),
		.rst_n                      (rst_n                      ),

		`ifndef SIM
			.s_axis_config_tvalid     (s_axis_config_tvalid       ),
			.s_axis_config_tdata      (s_axis_config_tdata        ),
		`else
			.s_axis_config_tvalid     (s_axis_config_tvalid_sim   ),
			.s_axis_config_tdata      (s_axis_config_tdata_sim    ),
		`endif

		.s_axis_config_tready       (s_axis_config_tready       ),

		.m_axis_wbconfig_tvalid     (m_axis_wbconfig_tvalid     ),
		.m_axis_wbconfig_tready     (m_axis_wbconfig_tready     ),
		.m_axis_wbconfig_tdata      (m_axis_wbconfig_tdata      ),

		.m_axis_dmconfig_tvalid     (m_axis_dmconfig_tvalid     ),
		.m_axis_dmconfig_tready     (m_axis_dmconfig_tready     ),
		.m_axis_dmconfig_tdata      (m_axis_dmconfig_tdata      ),

		.m_axis_wmconfig_tvalid     (m_axis_wmconfig_tvalid     ),
		.m_axis_wmconfig_tready     (m_axis_wmconfig_tready     ),
		.m_axis_wmconfig_tdata      (m_axis_wmconfig_tdata      ),

		.m_axis_dconfig_tvalid      (m_axis_dconfig_tvalid      ),
		.m_axis_dconfig_tready      (m_axis_dconfig_tready      ),
		.m_axis_dconfig_tdata       (m_axis_dconfig_tdata       ),

		.m_axis_wconfig_tvalid      (m_axis_wconfig_tvalid      ),
		.m_axis_wconfig_tready      (m_axis_wconfig_tready      ),
		.m_axis_wconfig_tdata       (m_axis_wconfig_tdata       ),

		.m_axis_synconfig_tvalid    (m_axis_synconfig_tvalid    ),
		.m_axis_synconfig_tready    (m_axis_synconfig_tready    ),
		.m_axis_synconfig_tdata     (m_axis_synconfig_tdata     ),

		.m_axis_sumconfig_tvalid    (m_axis_sumconfig_tvalid    ),
		.m_axis_sumconfig_tready    (m_axis_sumconfig_tready    ),
		.m_axis_sumconfig_tdata     (m_axis_sumconfig_tdata     ),

		.m_axis_roconfig_tvalid     (m_axis_roconfig_tvalid     ),
		.m_axis_roconfig_tready     (m_axis_roconfig_tready     ),
		.m_axis_roconfig_tdata      (m_axis_roconfig_tdata      ),

		.m_axis_ppconfig_tvalid     (m_axis_ppconfig_tvalid     ),
		.m_axis_ppconfig_tready     (m_axis_ppconfig_tready     ),
		.m_axis_ppconfig_tdata      (m_axis_ppconfig_tdata      ),

		.m_axis_dmwconfig_tvalid    (m_axis_dmwconfig_tvalid    ),
		.m_axis_dmwconfig_tready    (m_axis_dmwconfig_tready    ),
		.m_axis_dmwconfig_tdata     (m_axis_dmwconfig_tdata     ),

		.mode_1_1                   (mode_1_1),
		.frame_cnt                  (frame_cnt),

		.status_config              (status_config)
	);

	/********************************/
	//Width Trans
	/********************************/
	wire [127:0] m_axis_act_bus128_tdata, m_axis_weight_bias_tdata;
	wire m_axis_act_bus128_tvalid, m_axis_act_bus128_tready,
		m_axis_weight_bias_tvalid, m_axis_weight_bias_tready;

	width_trans width_trans (
		.clk                        (clk                        ),
		.rst_n                      (rst_n                      ),

		.s_axis_act_tvalid          (s_axis_act_tvalid          ),
		.s_axis_act_tready          (s_axis_act_tready          ),
		.s_axis_act_tdata           (s_axis_act_tdata           ),

		.s_axis_weight_tvalid       (s_axis_weight_tvalid       ),
		.s_axis_weight_tready       (s_axis_weight_tready       ),
		.s_axis_weight_tdata        (s_axis_weight_tdata        ),

		.m_axis_act_tvalid          (m_axis_act_bus128_tvalid   ),
		.m_axis_act_tready          (m_axis_act_bus128_tready   ),
		.m_axis_act_tdata           (m_axis_act_bus128_tdata    ),

		.m_axis_weight_tvalid       (m_axis_weight_bias_tvalid ),
		.m_axis_weight_tready       (m_axis_weight_bias_tready ),
		.m_axis_weight_tdata        (m_axis_weight_bias_tdata  )
	);


	/********************************/
	//Weight Bias Seperate
	/********************************/
	wire [127:0] m_axis_weight_bus128_tdata, m_axis_bias_tdata;
	wire m_axis_weight_bus128_tvalid, m_axis_weight_bus128_tready,
		m_axis_bias_tvalid, m_axis_bias_tready;

	Weight_Bias_Seperate Weight_Bias_Seperate (
		.clk                        (clk                        ),
		.rst_n                      (rst_n                      ),

		.s_axis_wbconfig_tvalid     (m_axis_wbconfig_tvalid     ),
		.s_axis_wbconfig_tready     (m_axis_wbconfig_tready     ),
		.s_axis_wbconfig_tdata      (m_axis_wbconfig_tdata      ),

		.s_axis_weight_tvalid       (m_axis_weight_bias_tvalid  ),
		.s_axis_weight_tready       (m_axis_weight_bias_tready  ),
		.s_axis_weight_tdata        (m_axis_weight_bias_tdata   ),

		.m_axis_weight_tvalid       (m_axis_weight_bus128_tvalid),
		.m_axis_weight_tready       (m_axis_weight_bus128_tready),
		.m_axis_weight_tdata        (m_axis_weight_bus128_tdata ),

		.m_axis_bias_tvalid         (m_axis_bias_tvalid         ),
		.m_axis_bias_tready         (m_axis_bias_tready         ),
		.m_axis_bias_tdata          (m_axis_bias_tdata          ),

		.status_wbs                 (status_wbs)
	);


`ifdef INIT_TRANS2SUM
	/********************************/
	//ACT_Manager
	/********************************/
	wire            m_axis_act_tvalid    ;
	wire            m_axis_act_tready    ;
	wire [63:0]     m_axis_act_tdata     ;


	ACT_Manager ACT_Manager (
		.clk                      (clk                    ),
		.rst_n                    (rst_n                  ),

		.s_axis_dmconfig_tvalid   (m_axis_dmconfig_tvalid ),
		.s_axis_dmconfig_tready   (m_axis_dmconfig_tready ),
		.s_axis_dmconfig_tdata    (m_axis_dmconfig_tdata  ),

		.s_axis_act_tvalid        (m_axis_act_bus128_tvalid),
		.s_axis_act_tready        (m_axis_act_bus128_tready),
		.s_axis_act_tdata         (m_axis_act_bus128_tdata ),
		.s_axis_act_tlast         (       ),
		.s_axis_act_tkeep         (       ),

		.m_axis_s2mm_tdata        (m_axis_s2mm_tdata      ),
		.m_axis_s2mm_tkeep        (m_axis_s2mm_tkeep      ),
		.m_axis_s2mm_tlast        (m_axis_s2mm_tlast      ),
		.m_axis_s2mm_tready       (m_axis_s2mm_tready     ),
		.m_axis_s2mm_tvalid       (m_axis_s2mm_tvalid     ),

		.s_axis_mm2s_tdata        (s_axis_mm2s_tdata      ),
		.s_axis_mm2s_tkeep        (s_axis_mm2s_tkeep      ),
		.s_axis_mm2s_tlast        (s_axis_mm2s_tlast      ),
		.s_axis_mm2s_tready       (s_axis_mm2s_tready     ),
		.s_axis_mm2s_tvalid       (s_axis_mm2s_tvalid     ),

		.m_axis_s2mm_cmd_tready   (m_axis_s2mm_cmd_tready ),
		.m_axis_s2mm_cmd_tvalid   (m_axis_s2mm_cmd_tvalid ),
		.m_axis_s2mm_cmd_tdata    (m_axis_s2mm_cmd_tdata  ),

		.m_axis_mm2s_cmd_tready   (m_axis_mm2s_cmd_tready ),
		.m_axis_mm2s_cmd_tvalid   (m_axis_mm2s_cmd_tvalid ),
		.m_axis_mm2s_cmd_tdata    (m_axis_mm2s_cmd_tdata  ),

		.s_axis_mm2s_sts_tready   (s_axis_mm2s_sts_tready ),
		.s_axis_mm2s_sts_tvalid   (s_axis_mm2s_sts_tvalid ),
		.s_axis_mm2s_sts_tdata    (s_axis_mm2s_sts_tdata  ),
		.s_axis_mm2s_sts_tlast    (s_axis_mm2s_sts_tlast  ),
		.s_axis_mm2s_sts_tkeep    (s_axis_mm2s_sts_tkeep  ),

		.s_axis_s2mm_sts_tready   (s_axis_s2mm_sts_tready ),
		.s_axis_s2mm_sts_tvalid   (s_axis_s2mm_sts_tvalid ),
		.s_axis_s2mm_sts_tdata    (s_axis_s2mm_sts_tdata  ),
		.s_axis_s2mm_sts_tlast    (s_axis_s2mm_sts_tlast  ),
		.s_axis_s2mm_sts_tkeep    (s_axis_s2mm_sts_tkeep  ),

		.m_axis_act_tvalid        (m_axis_act_tvalid      ),
		.m_axis_act_tready        (m_axis_act_tready      ),
		.m_axis_act_tdata         (m_axis_act_tdata       ),

		.status_act_manager       (status_act_manager)
	);


	/********************************/
	//Weight_Manager
	/********************************/
	wire            m_axis_weight_tvalid ;
	wire            m_axis_weight_tready ;
	wire [127:0]    m_axis_weight_tdata  ;


	Weight_Manager Weight_Manager (
		.clk                             (clk                           ),
		.rst_n                           (rst_n                         ),

		.s_axis_wmconfig_tvalid          (m_axis_wmconfig_tvalid        ),
		.s_axis_wmconfig_tready          (m_axis_wmconfig_tready        ),
		.s_axis_wmconfig_tdata           (m_axis_wmconfig_tdata         ),

		.s_axis_weight_tvalid            (m_axis_weight_bus128_tvalid   ),
		.s_axis_weight_tready            (m_axis_weight_bus128_tready   ),
		.s_axis_weight_tdata             (m_axis_weight_bus128_tdata    ),
		.s_axis_weight_tlast             (    ),
		.s_axis_weight_tkeep             (    ),

		.m_axis_weight_s2mm_tdata        (m_axis_weight_s2mm_tdata      ),
		.m_axis_weight_s2mm_tkeep        (m_axis_weight_s2mm_tkeep      ),
		.m_axis_weight_s2mm_tlast        (m_axis_weight_s2mm_tlast      ),
		.m_axis_weight_s2mm_tready       (m_axis_weight_s2mm_tready     ),
		.m_axis_weight_s2mm_tvalid       (m_axis_weight_s2mm_tvalid     ),

		.s_axis_weight_mm2s_tdata        (s_axis_weight_mm2s_tdata      ),
		.s_axis_weight_mm2s_tkeep        (s_axis_weight_mm2s_tkeep      ),
		.s_axis_weight_mm2s_tlast        (s_axis_weight_mm2s_tlast      ),
		.s_axis_weight_mm2s_tready       (s_axis_weight_mm2s_tready     ),
		.s_axis_weight_mm2s_tvalid       (s_axis_weight_mm2s_tvalid     ),

		.m_axis_weight_s2mm_cmd_tready   (m_axis_weight_s2mm_cmd_tready ),
		.m_axis_weight_s2mm_cmd_tvalid   (m_axis_weight_s2mm_cmd_tvalid ),
		.m_axis_weight_s2mm_cmd_tdata    (m_axis_weight_s2mm_cmd_tdata  ),

		.m_axis_weight_mm2s_cmd_tready   (m_axis_weight_mm2s_cmd_tready ),
		.m_axis_weight_mm2s_cmd_tvalid   (m_axis_weight_mm2s_cmd_tvalid ),
		.m_axis_weight_mm2s_cmd_tdata    (m_axis_weight_mm2s_cmd_tdata  ),

		.s_axis_weight_mm2s_sts_tready   (s_axis_weight_mm2s_sts_tready ),
		.s_axis_weight_mm2s_sts_tvalid   (s_axis_weight_mm2s_sts_tvalid ),
		.s_axis_weight_mm2s_sts_tdata    (s_axis_weight_mm2s_sts_tdata  ),
		.s_axis_weight_mm2s_sts_tlast    (s_axis_weight_mm2s_sts_tlast  ),
		.s_axis_weight_mm2s_sts_tkeep    (s_axis_weight_mm2s_sts_tkeep  ),

		.s_axis_weight_s2mm_sts_tready   (s_axis_weight_s2mm_sts_tready ),
		.s_axis_weight_s2mm_sts_tvalid   (s_axis_weight_s2mm_sts_tvalid ),
		.s_axis_weight_s2mm_sts_tdata    (s_axis_weight_s2mm_sts_tdata  ),
		.s_axis_weight_s2mm_sts_tlast    (s_axis_weight_s2mm_sts_tlast  ),
		.s_axis_weight_s2mm_sts_tkeep    (s_axis_weight_s2mm_sts_tkeep  ),

		.m_axis_weight_tvalid            (m_axis_weight_tvalid          ),
		.m_axis_weight_tready            (m_axis_weight_tready          ),
		.m_axis_weight_tdata             (m_axis_weight_tdata           ),

		.status_wm                       (status_wm)
	);


	/********************************/
	//Act_Mux
	/********************************/
	wire  [`DATA_ACT_WIDTH-1 :0]    act_data_1, act_data_2, act_data_3, act_data_4;
	wire  [9:0] act_dcnt;
	wire  act_data_valid;
	wire  act_ready;

	act_mux  act_mux (
		.clk                    ( clk                   ),
		.rst_n                  ( rst_n                 ),

		.s_config_valid         ( m_axis_dconfig_tvalid ),
		.s_config_data          ( m_axis_dconfig_tdata  ),
		.s_config_ready         ( m_axis_dconfig_tready ),

		.s_data_valid           ( m_axis_act_tvalid     ),
		.s_data                 ( m_axis_act_tdata      ),
		.s_data_ready           ( m_axis_act_tready     ),

		.act_data_1             ( act_data_1            ),
		.act_data_2             ( act_data_2            ),
		.act_data_3             ( act_data_3            ),
		.act_data_4             ( act_data_4            ),

		.act_dcnt               ( act_dcnt              ),
		.act_valid              ( act_data_valid        ),
		.act_ready              ( act_ready             ),

		.status_dmux            ( status_dmux)
	);


	/********************************/
	//Weight_Mux
	/********************************/
	wire  [9:0]       weight_dcnt;
	wire  [63:0]      m_axis_wmux_tvalid;
	wire  [63:0]      m_axis_wmux_tready;
	wire  [`DATA_WEIGHT_WIDTH*64-1: 0]  m_axis_wmux_tdata;


	weight_mux  weight_mux (
		.clk                    ( clk                   ),
		.rst_n                  ( rst_n                 ),

		.s_config_valid         ( m_axis_wconfig_tvalid ),
		.s_config_ready         ( m_axis_wconfig_tready ),
		.s_config_data          ( m_axis_wconfig_tdata  ),

		.s_weight_valid         ( m_axis_weight_tvalid  ),
		.s_weight_ready         ( m_axis_weight_tready  ),
		.s_weight               ( m_axis_weight_tdata   ),

		.weight_dcnt            ( weight_dcnt           ),
		.m_weight_valid         ( m_axis_wmux_tvalid    ),
		.m_weight_ready         ( m_axis_wmux_tready    ),
		.m_weight_data          ( m_axis_wmux_tdata     ),

		.status_wmux            ( status_wmux)
	);


	/********************************/
	//act_weight_sync
	/********************************/
	wire                                  weight_switch;
	wire    [2:0]                         m_weight_valid;
	wire    [`DATA_WEIGHT_WIDTH*256-1 :0] m_weight_data;

	wire                                  m_act_valid;
	wire    [`DATA_ACT_WIDTH-1 :0]        m_act_data_1;
	wire    [`DATA_ACT_WIDTH-1 :0]        m_act_data_2;
	wire    [`DATA_ACT_WIDTH-1 :0]        m_act_data_3;
	wire    [`DATA_ACT_WIDTH-1 :0]        m_act_data_4;

	wire line_valid, partial_rstn, ro_busy;


	act_weight_sync  act_weight_sync (
		.clk                     ( clk                    ),
		.rst_n                   ( rst_n                  ),

		.s_axis_synconfig_tvalid ( m_axis_synconfig_tvalid),
		.s_axis_synconfig_tready ( m_axis_synconfig_tready),
		.s_axis_synconfig_tdata  ( m_axis_synconfig_tdata ),

		.act_data_1              ( act_data_1             ),
		.act_data_2              ( act_data_2             ),
		.act_data_3              ( act_data_3             ),
		.act_data_4              ( act_data_4             ),
		.act_valid               ( act_data_valid         ),
		.act_ready               ( act_ready              ),

		.s_weight_valid          ( m_axis_wmux_tvalid     ),
		.s_weight_ready          ( m_axis_wmux_tready     ),
		.s_weight_data           ( m_axis_wmux_tdata      ),

		.act_dcnt                ( act_dcnt               ),
		.weight_dcnt             ( weight_dcnt            ),

		.m_weight_data           ( m_weight_data          ),
		.m_weight_valid          ( m_weight_valid         ),
		.weight_switch           ( weight_switch          ),

		.m_act_valid             ( m_act_valid            ),
		.m_act_data_1            ( m_act_data_1           ),
		.m_act_data_2            ( m_act_data_2           ),
		.m_act_data_3            ( m_act_data_3           ),
		.m_act_data_4            ( m_act_data_4           ),

		.ro_busy                 ( ro_busy                ),

		.partial_rstn            ( partial_rstn           ),
		.status_sync              ( status_sync)
	);



	/********************************/
	//Conv_Group
	/********************************/
	// wire  [CONV_NUM-1:0] sum_valid_group ;

	wire [63:0]conv_valid ;
	wire [`DATA_INTER_WIDTH * 64-1 :0] conv_data_1;
	wire [`DATA_INTER_WIDTH * 64-1 :0] conv_data_2;
	wire [`DATA_INTER_WIDTH * 64-1 :0] conv_data_3;

	genvar i ;
	generate
		for (i=0; i<CONV_NUM; i=i+1) begin:conv_group_gen
			conv_group  conv_group (
				.clk           ( clk                          ),
				.rst_n         ( rst_n                        ),

				.act_data_1    ( m_act_data_1                 ),
				.act_data_2    ( m_act_data_2                 ),
				.act_data_3    ( m_act_data_3                 ),
				.act_data_4    ( m_act_data_4                 ),

				.act_valid     ( m_act_valid                  ),
				.mode_1_1      ( mode_1_1                     ),

				//.weight_data   ( m_weight_data[48*i+47 :48*i] ),
				.weight_data   ( m_weight_data[4*`DATA_WEIGHT_WIDTH*i+4*`DATA_WEIGHT_WIDTH-1
					:4*`DATA_WEIGHT_WIDTH*i] ),
				.weight_valid  ( m_weight_valid               ),
				.weight_switch ( weight_switch                ),
				.partial_rstn  ( partial_rstn                 ),

				.conv_valid    ( conv_valid[63-i]             ),
				.conv_data_1   ( conv_data_1[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]),
				.conv_data_2   ( conv_data_2[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH]),
				.conv_data_3   ( conv_data_3[(64-i)*`DATA_INTER_WIDTH-1 : (63-i)*`DATA_INTER_WIDTH])
			);
		end
		//assign sum_valid = sum_valid_group[0];
	endgenerate


	/********************************/
	//Conv_SUM
	/********************************/
	wire  [`DATA_INTER_WIDTH*64-1 :0]  sum_data;
	wire  sum_valid, sum_ready ;

	conv_sum conv_sum(
		.clk             (clk           ),
		.rst_n           (rst_n         ),

		.s_config_valid  (m_axis_sumconfig_tvalid  ),
		.s_config_ready  (m_axis_sumconfig_tready  ),
		.s_config_data   (m_axis_sumconfig_tdata   ),

		.inter_data_1    (conv_data_1  ),
		.inter_data_2    (conv_data_2  ),
		.inter_data_3    (conv_data_3  ),
		.inter_valid     (conv_valid[63]),

		.sum_data        (sum_data     ),
		.sum_valid       (sum_valid    ),
		.status_sum      (status_sum  )
	);

`else

	assign m_axis_s2mm_tvalid = 0;
	assign s_axis_mm2s_tready = 1;
	assign m_axis_s2mm_cmd_tvalid = 0;
	assign m_axis_mm2s_cmd_tvalid = 0;

`endif

`ifdef INIT_RO2DDRW

	/********************************/
	//Reorder
	/********************************/
	wire [191:0] reorder_data;
	wire         reorder_valid, reorder_ready;
	wire [`DATA_INTER_WIDTH*64-1 :0]  m_axis_rosim_tdata;

	`ifdef REORDER_DATAGEN

		data_gen  #(
			.Width                (`DATA_INTER_WIDTH*64 ),
			.CONFIG_LEN           (`REORDER_LEN         ),
			.FRAME_NUM            (`FRAME_NUM           ),
			.Data_Path            (`REORDER_DIR         )
		)
		inst_reorder_gen (
			.i_sys_clk            (clk                  ),
			.i_sys_rst_n          (rst_n                ),

			.i_start              (1'b1                 ),

			.O_chan_cha1_ph_tdata (m_axis_rosim_tdata  ),
			.O_chan_ph_tvalid     (sum_valid),
			.O_chan_ph_tlast      ( ),
			.O_chan_ph_tready     (reorder_ready)
		);

	`endif

	reorder reorder (
		.clk              (clk            ),
		.rst_n            (rst_n          ),

	`ifdef REORDER_DATAGEN
		.sum_valid        (sum_valid      ),
		//.sum_data         ({sum_data[64*`DATA_INTER_WIDTH-1:56*`DATA_INTER_WIDTH],
			//m_axis_rosim_tdata[56*`DATA_INTER_WIDTH-1:0]}),
		.sum_data         (m_axis_rosim_tdata),
		//.sum_data         (sum_data     ),
		.ro_busy          (ro_busy      ),
	`else
		.sum_valid        (sum_valid    ),
		.sum_data         (sum_data     ),
		//.sum_data         ({sum_data[64*24-1:63*24],1512'd0}     ),
		.ro_busy          (ro_busy      ),
	`endif

	`ifndef POST_DATAGEN
		.reorder_data     (reorder_data   ),
		.reorder_valid    (reorder_valid  ),
		.reorder_ready    (reorder_ready  ),
	`endif

		.s_config_valid   (m_axis_roconfig_tvalid ),
		.s_config_ready   (m_axis_roconfig_tready ),
		.s_config_data    (m_axis_roconfig_tdata  ),

		.status_ro        (status_ro)
	);


	/********************************/
	//Post Process
	/********************************/
	wire [127:0] post_data;
	wire         post_valid, post_ready, post_ready_ddr, post_ready_output;

	`ifdef POST_DATAGEN
		data_gen  #(
			.Width                (`DATA_INTER_WIDTH * 8 ),
			.CONFIG_LEN           (`IMG_H *`IMG_W * `O_CH /8 ),
			.FRAME_NUM            (`FRAME_NUM    ),
			.Data_Path            (`POST_DIR     )
		)
		inst_post_gen (
			.i_sys_clk            (clk           ),
			.i_sys_rst_n          (rst_n         ),

			.i_start              (R_gen_data    ),

			.O_chan_cha1_ph_tdata (reorder_data  ),
			.O_chan_ph_tvalid     (reorder_valid ),
			.O_chan_ph_tlast      (              ),
			.O_chan_ph_tready     (reorder_ready )
		);

	`endif

	post_process post_process (
		.clk                      (clk                                ),
		.rst_n                    (rst_n                              ),

		.s_axis_ppconfig_tvalid   (m_axis_ppconfig_tvalid             ),
		.s_axis_ppconfig_tready   (m_axis_ppconfig_tready             ),
		.s_axis_ppconfig_tdata    (m_axis_ppconfig_tdata              ),

		.reorder_data             (reorder_data                       ),
		.reorder_valid            (reorder_valid                      ),
		.reorder_ready            (reorder_ready                      ),

		.post_data                (post_data                          ),
		.post_valid               (post_valid                         ),
		.post_ready               (post_ready_ddr                     ),

		.s_axis_bias_tvalid       (m_axis_bias_tvalid                 ),
		.s_axis_bias_tready       (m_axis_bias_tready                 ),
		.s_axis_bias_tdata        (m_axis_bias_tdata                  ),

		.s_axis_mm2s_tdata        (s_axis_biasmm2s_tdata              ),
		.s_axis_mm2s_tkeep        (s_axis_biasmm2s_tkeep              ),
		.s_axis_mm2s_tlast        (s_axis_biasmm2s_tlast              ),
		.s_axis_mm2s_tready       (s_axis_biasmm2s_tready             ),
		.s_axis_mm2s_tvalid       (s_axis_biasmm2s_tvalid             ),

		.m_axis_mm2s_cmd_tready   (m_axis_biasmm2s_cmd_tready         ),
		.m_axis_mm2s_cmd_tvalid   (m_axis_biasmm2s_cmd_tvalid         ),
		.m_axis_mm2s_cmd_tdata    (m_axis_biasmm2s_cmd_tdata          ),

		.s_axis_mm2s_sts_tready   (s_axis_biasmm2s_sts_tready         ),
		.s_axis_mm2s_sts_tvalid   (s_axis_biasmm2s_sts_tvalid         ),
		.s_axis_mm2s_sts_tdata    (s_axis_biasmm2s_sts_tdata          ),
		.s_axis_mm2s_sts_tlast    (s_axis_biasmm2s_sts_tlast          ),
		.s_axis_mm2s_sts_tkeep    (s_axis_biasmm2s_sts_tkeep          ),

		.m_axis_s2mm_tdata        (m_axis_biass2mm_tdata              ),
		.m_axis_s2mm_tkeep        (m_axis_biass2mm_tkeep              ),
		.m_axis_s2mm_tlast        (m_axis_biass2mm_tlast              ),
		.m_axis_s2mm_tready       (m_axis_biass2mm_tready             ),
		.m_axis_s2mm_tvalid       (m_axis_biass2mm_tvalid             ),

		.m_axis_s2mm_cmd_tready   (m_axis_biass2mm_cmd_tready         ),
		.m_axis_s2mm_cmd_tvalid   (m_axis_biass2mm_cmd_tvalid         ),
		.m_axis_s2mm_cmd_tdata    (m_axis_biass2mm_cmd_tdata          ),
		.s_axis_s2mm_sts_tready   (s_axis_biass2mm_sts_tready         ),
		
		.s_axis_s2mm_sts_tvalid   (s_axis_biass2mm_sts_tvalid         ),
		.s_axis_s2mm_sts_tdata    (s_axis_biass2mm_sts_tdata          ),
		.s_axis_s2mm_sts_tlast    (s_axis_biass2mm_sts_tlast          ),
		.s_axis_s2mm_sts_tkeep    (s_axis_biass2mm_sts_tkeep          ),

		.status_post              (status_post                        )
	);


	/********************************/
	//MultiChannel WrDDR
	/********************************/
	wire [31:0] cnt_unit_wire;
	wire [15:0] len_unit_wire;
	wire [15:0] cnt_package_wire;
	wire        s_axis_dmw_tready_en_wire;

	Dmover_multich_wr multich_wr (
		.clk                       (clk                        ),
		.rst_n                     (rst_n                      ),

		.s_axis_dmwconfig_tdata    (m_axis_dmwconfig_tdata     ),
		.s_axis_dmwconfig_tvalid   (m_axis_dmwconfig_tvalid    ),
		.s_axis_dmwconfig_tready   (m_axis_dmwconfig_tready    ),

		.s_axis_dmw_tdata          (post_data                  ),
		.s_axis_dmw_tvalid         (post_valid                 ),
		.s_axis_dmw_tready         (post_ready_ddr             ),

		.m_axis_s2mm_cmd_tready    (m_axis_wrs2mm_cmd_tready   ),
		.m_axis_s2mm_cmd_tdata     (m_axis_wrs2mm_cmd_tdata    ),
		.m_axis_s2mm_cmd_tvalid    (m_axis_wrs2mm_cmd_tvalid   ),

		.s_axis_s2mm_sts_tdata     (s_axis_wrs2mm_sts_tdata    ),
		.s_axis_s2mm_sts_tvalid    (s_axis_wrs2mm_sts_tvalid   ),
		.s_axis_s2mm_sts_tlast     (s_axis_wrs2mm_sts_tlast    ),
		.s_axis_s2mm_sts_tkeep     (s_axis_wrs2mm_sts_tkeep    ),
		.s_axis_s2mm_sts_tready    (s_axis_wrs2mm_sts_tready   ),

		.m_axis_dmw_tready         (m_axis_wrs2mm_tready       ),
		.m_axis_dmw_tdata          (m_axis_wrs2mm_tdata        ),
		.m_axis_dmw_tvalid         (m_axis_wrs2mm_tvalid       ),
		.m_axis_dmw_tlast          (m_axis_wrs2mm_tlast        ),
		.m_axis_dmw_tkeep          (m_axis_wrs2mm_tkeep        ),

		.m_axis_output2ps_tready   (m_axis_output2ps_tready    ),
		.m_axis_output2ps_tdata    (m_axis_output2ps_tdata     ),
		.m_axis_output2ps_tvalid   (m_axis_output2ps_tvalid    ),
		.m_axis_output2ps_tlast    (m_axis_output2ps_tlast     ),
		.m_axis_output2ps_tkeep    (m_axis_output2ps_tkeep     ),

		.cnt_unit_wire             (cnt_unit_wire              ),
		.len_unit_wire             (len_unit_wire              ),
		.cnt_package_wire          (cnt_package_wire           ),
		.s_axis_dmw_tready_en_wire (s_axis_dmw_tready_en_wire  ),

		.status_dmw                (status_dmw)
	);

  // ------------- FOR SIM ------------- //

`else

	assign sum_ready = 1 ;

`endif

// ---------------------------------------------------------------------- //
// -------------------------------- END --------------------------------- //
// ---------------------------------------------------------------------- //

  // Not define SIM. Define DEBUG. Instance ila
	`ifndef SIM
		`ifdef ILA

			//ila_36_4 ila_1 (
				//.clk(clk), // input wire clk
				//.probe0({s_axis_weight_tvalid,s_axis_weight_tready,s_axis_weight_tdata}),
				//.probe1({s_axis_act_tvalid,s_axis_act_tready,s_axis_act_tdata}),
				//.probe2({m_axis_act_bus128_tvalid,m_axis_act_bus128_tready,m_axis_act_bus128_tdata[31:0]}),
				//.probe3({m_axis_weight_bias_tvalid,m_axis_weight_bias_tready,m_axis_weight_bias_tdata[31:0]})
				//);

			//ila_36_4 ila_1 (
				//.clk(clk),
				//.probe0({m_axis_output2ps_tdata[31:0], m_axis_output2ps_tvalid, m_axis_output2ps_tready,
					//m_axis_output2ps_tlast}),
				//.probe1({m_axis_output2ps_tdata[63:32]}),
				//.probe2({m_axis_output2ps_tdata[95:64]}),
				//.probe3({m_axis_output2ps_tdata[127:96]})
				//);

			//ila_36_4 ila_2 (
				//.clk(clk),
				//.probe0({m_axis_weight_bus128_tvalid, m_axis_weight_bus128_tready,
					//m_axis_weight_bus128_tdata[15:0], m_axis_bias_tvalid, m_axis_bias_tready,
					//m_axis_bias_tdata[15:0]}),
				//.probe1({m_axis_act_tvalid, m_axis_act_tready, m_axis_act_tdata[15:0], m_axis_weight_tvalid,
					//m_axis_weight_tready,m_axis_weight_tdata[15:0]}),
				//.probe2({act_data_valid, act_ready, act_data_1, m_axis_wmux_tvalid, m_axis_wmux_tready,
					//m_axis_wmux_tdata[11:0]}),
				//.probe3({m_act_valid,m_act_data_1,m_weight_valid,m_weight_data[11:0]})
			//);


			ila_36_4 ila_dmw (
				.clk(clk),
				.probe0({cnt_unit_wire, status_dmw}),
				.probe1({len_unit_wire, cnt_package_wire, post_valid}),
				.probe2({m_axis_wrs2mm_tvalid, m_axis_wrs2mm_tready, post_ready_ddr,
					s_axis_dmw_tready_en_wire, m_axis_wrs2mm_tdata[31:0]})
			);

			//ila_36_4 ila_3 (
				//.clk(clk),
				//.probe0({conv_valid[0], conv_data_1[15:0], conv_data_2[15:0]}),
				//.probe1({reorder_valid, reorder_ready, reorder_data[31:0]}),
				//.probe2({m_axis_wrs2mm_tvalid, m_axis_wrs2mm_tready, m_axis_wrs2mm_tdata[31:0]}),
				//.probe3({conv_data_1[39:24], conv_data_2[39:24]})
			//);

			ila_36_4 ila_4 (
				.clk(clk),
				.probe0({status_config, status_wbs, status_act_manager, status_wm, status_dmux, status_wmux,
					status_sync, status_sum, status_ro}),
				//.probe1({status_post, sum_data[23:0]}),
				//.probe2({sum_valid, sum_data[47:24]}),
				//.probe3({sum_data[24*64-1:24*63]})
				.probe1({status_post, sum_data[`DATA_INTER_WIDTH-1:0]}),
				.probe2({sum_valid, sum_data[`DATA_INTER_WIDTH*2-1:`DATA_INTER_WIDTH]}),
				.probe3({sum_data[`DATA_INTER_WIDTH*64-1:`DATA_INTER_WIDTH*63]})
			);
		`endif
	`endif

	// Define SIM. Define PRINT. Print log to txt.
	`ifdef SIM 
		`ifdef PRINT
			`ifdef INIT_TRANS2SUM

				integer handle1 ;
				initial handle1=$fopen("../PRINT/DM_act.txt");
				always @ (posedge clk) begin
					if (m_axis_act_tvalid & m_axis_act_tready) begin
						$fdisplay(handle1,"%h",m_axis_act_tdata);
					end
				end

				integer handle2 ;
				initial handle2=$fopen("../PRINT/DM_weight.txt");
				always @ (posedge clk) begin
					if (m_axis_weight_tvalid & m_axis_weight_tready) begin
						$fdisplay(handle2,"%h",m_axis_weight_tdata);
					end
				end


				integer handle3 ;
				initial handle3=$fopen("../PRINT/Dmux.txt");
				always @ (posedge clk) begin
					if (act_data_valid & act_ready) begin
						$fdisplay(handle3,"%h",{act_data_1, act_data_2, act_data_3, act_data_4});
					end
				end

				integer handle4 ;
				initial handle4=$fopen("../PRINT/Wmux1.txt");
				always @ (posedge clk) begin
					if (m_axis_wmux_tvalid[0] & m_axis_wmux_tready) begin
						$fdisplay(handle4,"%h",m_axis_wmux_tdata[11:0]);
					end
				end


				integer handle5 ;
				initial handle5=$fopen("../PRINT/Sync_act.txt");
				always @ (posedge clk) begin
					if (m_act_valid) begin
						$fdisplay(handle5,"%h",{m_act_data_1, m_act_data_2, m_act_data_3, m_act_data_4});
					end
				end

				integer handle6 ;
				initial handle6=$fopen("../PRINT/Sync_weight.txt");
				always @ (posedge clk) begin
					if (m_weight_valid > 0) begin
						$fdisplay(handle6,"%h",m_weight_data[`DATA_WEIGHT_WIDTH*4-1 :0]);
					end
				end

				integer handle7 ;
				initial handle7=$fopen("../PRINT/Conv_group1.txt");
				always @ (posedge clk) begin
					if (conv_valid) begin
						$fdisplay(handle7,"%h",
							{conv_data_1[64*`DATA_INTER_WIDTH-1 : 63*`DATA_INTER_WIDTH],
							conv_data_2[64*`DATA_INTER_WIDTH-1 : 63*`DATA_INTER_WIDTH],
							conv_data_3[64*`DATA_INTER_WIDTH-1 : 63*`DATA_INTER_WIDTH]});
					end
				end

				integer handle8 ;
				initial handle8=$fopen("../PRINT/Conv_sum1.txt");
				always @ (posedge clk) begin
					if (sum_valid) begin
						$fdisplay(handle8,"%h",sum_data[64*`DATA_INTER_WIDTH-1 : 63*`DATA_INTER_WIDTH]);
					end
				end

			`endif

			`ifdef INIT_RO2DDRW

				integer handle9 ;
				initial handle9=$fopen("../PRINT/Reorder.txt");
				always @ (posedge clk) begin
					if (reorder_valid & reorder_ready) begin
						$fdisplay(handle9,"%h",reorder_data);
					end
				end

				integer handle10 ;
				initial handle10=$fopen("../PRINT/Post.txt");
				always @ (posedge clk) begin
					if (post_valid & post_ready) begin
						$fdisplay(handle10,"%h",post_data);
					end
				end

				integer handle11 ;
				initial handle11=$fopen("../PRINT/DDR_W.txt");
				always @ (posedge clk) begin
					if (m_axis_wrs2mm_tvalid & m_axis_wrs2mm_tready) begin
						$fdisplay(handle11,"%h",m_axis_wrs2mm_tdata);
					end
				end

			`endif
		`endif
	`endif

endmodule
