//`define SIM
`define FSDB_DUMP
`define PRINT
// Define `DEBUG` will enable ila in verilog design. Remember to avoid conflict
// with ila in block design
//`define DEBUG
`define ILA
//`define FSDB_DUMP_2D
`define FRAME_NUM 1
`define INIT_TRANS2SUM
`define INIT_RO2DDRW
//`define POST_DATAGEN

`define SCENE1
    //1: 56*56*256
    //2: 28*28*512
    //3: 224*224*64
    //4: 1*1*4096
    //5: 13*13*1024*256


`ifdef SCENE1
    `define IMG_H            56
    `define IMG_W            56
    `define I_CH             256
    `define O_CH             256

    `define IMG_LEN  256*56*56
    `define IMG_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/56_256_shift/img_56_256_process_shift_sim.txt"

    `define WEI_LEN  256*256*9+256*2
    `define WEI_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/56_256_shift/bias_weight_56_256_shift_sim.txt"

    `define REORDER_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/56_256_shift/Conv_sum_all_ref.txt"
    `define REORDER_LEN 56*57*256/64

    // `define BIAS_DIR "/home/dlisa/Desktop/Project/systolic_conv_v/mat/PostTestData/RefTxt/56_256/Bias.txt"
    // `define POST_DIR "/home/dlisa/Desktop/Project/systolic_conv_v/mat/PostTestData/RefTxt/56_256/Reorder_out_ref.txt"
`endif


`ifdef SCENE2
    `define IMG_H            28
    `define IMG_W            28
    `define I_CH             512
    `define O_CH             512

    `define IMG_LEN  512*28*28
    `define IMG_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/28_512/img_28_512_process_bus128.txt"

    `define WEI_LEN  512*512*9+512*2
    `define WEI_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/28_512/weight_bias_28_512_process_bus128.txt"

    // `define BIAS_DIR "/home/dlisa/Desktop/Project/systolic_conv_v/mat/PostTestData/RefTxt/28_512/Bias.txt"
    // `define POST_DIR "/home/dlisa/Desktop/Project/systolic_conv_v/mat/PostTestData/RefTxt/28_512/Reorder_ref.txt"

    `define REORDER_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/28_512/Conv_sum_all_ref.txt"
    `define REORDER_LEN 28*29*512/64
`endif


`ifdef SCENE3
    `define IMG_H            224
    `define IMG_W            224
    `define I_CH             64
    `define O_CH             64

    `define IMG_LEN  64*224*224
    `define IMG_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/224_64/img_224_64_process_bus128.txt"

    `define WEI_LEN  64*64*9+64*2
    `define WEI_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/224_64/weight_bias_224_64_process_bus128.txt"

    `define REORDER_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/224_64/Conv_sum_all_ref.txt"
    `define REORDER_LEN 224*225*64/64
`endif


`ifdef SCENE4
    `define IMG_H            1
    `define IMG_W            1
    `define I_CH             4096
    `define O_CH             4096

    `define IMG_LEN  1*1*4096
    `define IMG_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/1_4096/img_1_4096_process_bus128.txt"

    `define WEI_LEN  4096*4096*1+4096*2
    `define WEI_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/1_4096/weight_bias_1_4096_process_bus128.txt"

    `define REORDER_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/1_4096/Conv_sum_all_ref.txt"
    `define REORDER_LEN 1*1*4096/64
`endif


`ifdef SCENE5
    `define IMG_H            13
    `define IMG_W            13
    `define I_CH             1024
    `define O_CH             256

    `define IMG_LEN  13*13*1024
    `define IMG_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/13_1024_256/img_13_1024_process_bus128.txt"

    `define WEI_LEN  1024*256*1+256*2
    `define WEI_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/13_1024_256/weight_bias_13_1024_256_process_bus128.txt"

    `define REORDER_DIR "/media/raymond/project/fpga/fpga_systolic_conv_sim/data/13_1024_256/Conv_sum_all_ref.txt"
    `define REORDER_LEN 13*13*256/64
`endif

