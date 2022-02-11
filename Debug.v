module Debug (
    input               clk   ,
    input               rst_n ,

    input   [7:0]       s_axis_debug_mm2s_sts_tdata    ,
    input               s_axis_debug_mm2s_sts_tkeep    ,
    input               s_axis_debug_mm2s_sts_tlast    ,
    output  reg         s_axis_debug_mm2s_sts_tready =1,
    input               s_axis_debug_mm2s_sts_tvalid   ,

    output   [71:0]     m_axis_debug_mm2s_cmd_tdata    ,
    input               m_axis_debug_mm2s_cmd_tready   ,
    output  reg         m_axis_debug_mm2s_cmd_tvalid   ,

    input    [15:0]     m_axis_debug_mm2s_tdata        ,
    input    [1:0]      m_axis_debug_mm2s_tkeep        ,
    input               m_axis_debug_mm2s_tlast        ,
    output  reg         m_axis_debug_mm2s_tready =1    ,
    input               m_axis_debug_mm2s_tvalid     
);

    // VIO
    wire [31:0] addr ;
    wire [22:0] length;
    wire start_raw ;
    reg  start_d1 =0;
    reg  start = 0 ;

    vio_debug vio_debug (
        .clk(clk),                // input wire clk
        .probe_out0(start_raw),  // output wire [0 : 0] probe_out0
        .probe_out1(addr),  // output wire [31 : 0] probe_out1
        .probe_out2(length),  // output wire [21 : 0] probe_out2
        .probe_in0(start_raw),  // output wire [0 : 0] probe_out0
        .probe_in1(addr),  // output wire [31 : 0] probe_out1
        .probe_in2(length)  // output wire [21 : 0] probe_out2
    );

    //Dmover Config
    reg [3:0]   r_rsvd ='d0 ;
    reg [3:0]   r_tag  ='d0 ;
    reg         r_drr  ='d0 ;
    reg         r_eof  ='d1 ;
    reg [5:0]   r_dsa  ='d0 ;
    reg         r_type ='d1 ;
    reg [22:0]  r_btt       ;
    reg [31:0]  r_addr      ;


    // Posedge start
    always @(posedge clk) begin
        start_d1 <= start_raw;
        start <= start_raw & (~start_d1);
        m_axis_debug_mm2s_cmd_tvalid <= start;
        if (start_raw) begin
            r_addr <= addr ;
            r_btt  <= length;
        end
    end


    //Config
    assign m_axis_debug_mm2s_cmd_tdata  = {r_rsvd,r_tag,r_addr,r_drr,r_eof,r_dsa,r_type,r_btt};

    //Cnt
    reg [9:0] data_cnt;

    always @ (posedge clk) begin
        if (start) data_cnt <= 'd0 ;
        else if (m_axis_debug_mm2s_tready & m_axis_debug_mm2s_tvalid) data_cnt <= data_cnt + 1 ;
    end

    //Ila
    ila_36 ila_debug (
        .clk(clk), // input wire clk
        .probe0({m_axis_debug_mm2s_tvalid, m_axis_debug_mm2s_tdata, data_cnt, 
                s_axis_debug_mm2s_sts_tvalid, s_axis_debug_mm2s_sts_tdata}) // input wire [35:0] probe0
    );

    integer handle1 ;
    initial handle1=$fopen("../PRINT/Debug_get.txt");
    always @ (posedge clk) begin
        if (m_axis_debug_mm2s_tvalid & m_axis_debug_mm2s_tready) begin
            $fdisplay(handle1,"%h",m_axis_debug_mm2s_tdata);
        end
    end

endmodule
