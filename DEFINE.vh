`include "SIM_CTRL.vh"

// Activation value.
`define DATA_ACT_WIDTH          12  
`define BUS128_DATA_ACT_NUM     10
`define INT_ACT_WIDTH           4	

// Weight value.
`define DATA_WEIGHT_WIDTH       12  
`define BUS128_DATA_WEIGHT_NUM  10
`define INT_WEIGHT_WIDTH        4	

// Intermediate value.
`define DATA_INTER_WIDTH        24	
`define BUS128_DATA_INTER_NUM   5
`define INT_INTER_WIDTH         8	

// Mult LANTANCY
`define MULT_LANTANCY 3
`define DIV_LANTANCY  51 //this should be lantency in vivado plus 1

// PS CONFIG
`define PS_CONFIG_LEN 11

`define CONV_GROUP_NUM 64
`define WEIGHT_DEPTH 589824
`define ACT_DEPTH 401408
`define WEIGHT_RAMf_WIDTH 2304
`define DDR_OFFSET 32'h8000_0000


//PINGPONG
`define PING                    0
`define PONG                    1

// Read Source
`define DDR                     0
`define PS                      1
