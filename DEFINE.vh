`include "SIM_CTRL.vh"

`define ACT_BOUND               256 // 2^`DATA_ACT_WIDTH

// Activation value.
`define DATA_ACT_WIDTH          8
`define BUS128_DATA_ACT_NUM     16

// Weight value.
`define DATA_WEIGHT_WIDTH       4
`define BUS128_DATA_WEIGHT_NUM  32

// Intermediate value.
`define DATA_INTER_WIDTH        16
`define BUS128_DATA_INTER_NUM   8

// Mult LANTANCY
//`define CONV_OP_LANTANCY        3
`define CONV_OP_LANTANCY        0
`define DIV_LANTANCY            51 //this should be lantency in vivado plus 1

`define TRUNC_UP_BIT            10
`define TRUNC_DOWN_BIT          4

`define POSITIVE_UP_BOUND       7'h7F
`define NEGATIVE_DOWN_BOUND     7'h00

// PS CONFIG
`define PS_CONFIG_LEN           11

`define CONV_GROUP_NUM          64
`define WEIGHT_DEPTH            589824
`define ACT_DEPTH               401408
`define WEIGHT_RAMf_WIDTH       2304
`define DDR_OFFSET              32'h8000_0000

//PINGPONG
`define PING                    0
`define PONG                    1

// Read Source
`define DDR                     0
`define PS                      1
