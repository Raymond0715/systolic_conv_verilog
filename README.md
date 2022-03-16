# HARDWARE
# 1 烂笔头

VCS: 专业仿真工具

## 1.1 位宽

注意: 修改 block ram 的同时, 要修改地址位宽.

改位宽需要修改配置的IP:
- data_weight_sync.v:

  - weight_ram

  - act_ram_4

- conv_sum.v: ram_xxx_512

- data_mux.v: fifo_wxx_d512_fwft

- Data_Manager.v: 修改补零个数以及改位宽

- weight_mux.v:

  - fifo_wxx_d512_fwft

  - 修改状态机中 DDR 进 FIFO 的代码

- post_process.v:

  - step5_out 修改补零个数以及改位宽

  - fifo_wxx_d512_fwft


## 1.2 仿真设置备忘录

记录仿真相关设置.

- `SIM_CTRL.vh`

- `Top_PL.v`:

  - `config` 模块相关配置, 在 `configtask` 中, `scene` 和 `SIM_CTRL.vh` 中对应.

  - `reorder` 和 `post_process` 模拟输入数据生成


## 1.3 优化备忘录

记录目前基于 Verilog 设计中仍可以优化的地方.

- **DDR 中 128 bit 中数据好像排反了**

  - Verilog 逻辑修改

  - 生成用于仿真的数据的 python 代码需要修改

- 改位宽后, 修改 DDR 读写并行度, 减少数据传输时间

- 输入8通道需要优化，输入四通道即可

- **当输出通道小于64时, 不仅会浪费计算资源, 还会导致大量冗余激活值数据调度的出现, 极大降低性能表现.**

- 对于 YOLO 模型, 可以减少片上内存用于缓存分块数据的空间, 降低 BRAM 的使用.

- 对于 YOLO 模型, 移植到中控 FPGA 上时, 需要减少并行度以满足片上硬件资源的约束.

- Max Pooling 模块 **必须** 要单独做成模块单独调用, 处在和巻积并列的层级结构中. 因为 YOLO 的结构有单独调用 Max Pooling 的情况出现.

- **需要** 上采样模块.

- PL 接收数据时若 PS 的数据包中有无效数据也会被 PL 计算逻辑接受

- weight 写 DDR 和读 DDR 尺寸一致，不能设置成不同的尺寸(一定程度上已经通过添加 `init_weight` 状态解决).

- 截位宽

  - 溢出

  - 动态截位宽

- 添加累加溢出的判断, 适度增加中间结果缓存的位宽.

- 去掉 config.v，将配置过程在PS侧完成

- 合并 activation DMA 和 weight DMA

- 感觉 config.v 中配置状态跳转和每个模块中配置状态逻辑有缺陷，当配置信息不连续时极端情况下可能会有逻辑问题。

- vivado 的 FIFO IP 的配置中, Programmable Flags 中 Full Threshold Assert Value 有什么影响


# 2 FPGA 设计

## 2.1 PS 配置寄存器定义

| 地址 |   位宽   | 说明                                                         |
|:----:|:--------:|:-------------------------------------------------------------|
|0x000 | [ 0:  0] | conf_33. Choose $3 \times 3$ convolution or $1 \times 1$ convolution.
|      |          | 0 indicate $3 \times 3$ convolution.
|      |          | 1 indicate $1 \times 1$ convolution.
|      | [ 1:  1] | act source.
|      |          | 0 indicate DDR source.
|      |          | 1 indicate SDK source.
|      | [ 2:  2] | weight or bias source
|      |          | 0 indicate DDR source.
|      |          | 1 indicate SDK source.
|      | [ 3:  3] | ReLU mode.
|      |          | 0 indicate ReLU.
|      |          | 1 indicate LeakyReLU.
|      | [ 4:  4] | ReLU switch
|      |          | 0 indicate ReLU off.
|      |          | 1 indicate ReLU on.
|      | [ 5:  5] | bias switch
|      |          | 0 indicate bias calculation off.
|      |          | 1 indicate bias calculation on.
|      | [ 6:  6] | sampling switch
|      |          | 0 indicate sampling off.
|      |          | 1 indicate sampling on.
|      | [ 7:  7] | bitintercept switch. Useless for now.
|      | [16:  8] | img_h, which is also img_w
|      | [17: 17] | Output sink.
|      |          | 0 indicate DDR is output sink.
|      |          | 1 indicate SDK is output sink.
|      | [18: 18] | Initial weight.
|      |          | 0 indicate it is calculate state.
|      |          | 1 indicate it is initial weight state.
|      | [19: 19] | finish.
|      |          | 0 indicate configuration state not finish.
|      |          | 1 indicate configuration state finish.
|      | [20: 20] | reset.
|      |          | 1 indicate reset.
|      |          | 0 indicate not to reset.
|0x020 | [11:  0] | input channel
|      | [23: 12] | output channel
|0x040 |          | Act write address. Only useful when act source is SDK.
|0x060 |          | Act read address.
|0x080 |          | Weight write address. Only useful when act source is SDK.
|0x0a0 |          | Weight read address.
|0x0c0 |          | Weight write length.
|0x0e0 |          | Bias write address.
|0x100 |          | Bias read address.
|0x120 |          | Bias write length.
|0x140 |          | DDR write address.


## 2.2 数据存储格式

input/weight file data format

```
inputs:
  |
  └── Store as 32 bits binary. Datawidth is 12 bits.

weights: bias + weight
  |
  ├── bias: Store as 32 bits binary. Datawidth is 24 bits.
  │
  └── weights: Store as 16 bits binary. Datawidth is 12 bits.
  ```

## 2.3 移位

### 2.3.1 计算参数

当激活值位宽为 8 位, 整数部分为 3 位; 权重位宽为 4 位时; 计算结果为16位, 整数部分为7位. 巻积16位计算结果按照整数部分4位量化可以和硬件计算结果保持一致.

移位映射: shift code: `lx` 左移 x 位, `rx` 右移 x 位. 最高位符号位, 0 为正, 1为负.

| `l3`| `l2`| `l1`|  `0`| `r1`| `r2`| `r3`| `r4`|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|000|001|010|011|100|101|110|111|


### 2.3.2 原理简介

For the shift network, the weight part is represented by the original code plus the sign bit, and the activation value part is represented by the complement code
- The activation value is represented by the complement

- The weight part is currently shifted to the right uniformly, and the sign indicates whether to take the complement or not, which means, the sign bit and the value bit represent operations at different positions

- For example, $z = Shift(w, x) = ax\times 2^b$, a and b are weights, which a indicates if sign is $+1$ or $-1$, b indicates shift bits, and $b <= 0$; $x$ indicates activation and calculate with $a$ in complement form.


## 2.4 Verilog 设计中的数据流排布

```
conv_group_0 ──┬── conv_33_1 ──┬── convolution 1   w7   w8   w9
               │               │
               │               ├── convolution 2   w4   w5   w6
               │               │
               │               └── convolution 3   w1   w2   w3
               │
               ├── conv_33_2 ──┬── convolution 1  w16  w17  w18
               │               │
               │               ├── convolution 2  w13  w14  w15
               │               │
               │               └── convolution 3  w10  w11  w12
               │
               ├── conv_33_3 ──┬── convolution 1  w25  w26  w27
               │               │
               │               ├── convolution 2  w22  w23  w24
               │               │
               │               └── convolution 3  w19  w20  w21
               │
               └── conv_33_4 ──┬── convolution 1  w34  w35  w36
                               │
                               ├── convolution 2  w31  w32  w33
                               │
                               └── convolution 3  w28  w29  w30

...

conv_group_63 ──┬── conv_33_1 ──┬── convolution 1
                │               │
                │               ├── convolution 2
                │               │
                │               └── convolution 3
                │
                ├── conv_33_2 ──┬── convolution 1
                │               │
                │               ├── convolution 2
                │               │
                │               └── convolution 3
                │
                ├── conv_33_3 ──┬── convolution 1
                │               │
                │               ├── convolution 2
                │               │
                │               └── convolution 3
                │
                └── conv_33_4 ──┬── convolution 1
                                │
                                ├── convolution 2
                                │
                                └── convolution 3
```


## 2.5 Pseudocode

### 2.5.1 Activation data schedule

下述所示, 为权重分块模式下输入数据调度伪代码
```python
# Weight Tiling
# index: full_repeat_cnt
# range: out_full_repeat_num
for w_tile
  for img_h

    # index: dout_repeat_cnt
    # range: act_repeat_num
    # `64` represent parallelism degree
    for w_tile_o_ch / 64

      # index: act_raddr
      # range: act_line_len
      # `4` represent input parallelism degree
      for img_ch / 4; for img_w
          act_raddr++
          act_out_1
          act_out_2
          act_out_3
          act_out_4

      act_raddr = act_offset

    # act_line_len =  raddr_per_line = 0x1a0
    act_offset += raddr_per_line

  act_offset = 0
```

### 2.5.2 PE cluster schedule

简述 PE 阵列计算方法. 其中, 对权重分块做如下说明;

- DDR 位宽为 128 bits.

- 在一组 128 bits 中储存 BUS128_DATA_WEIGHT_NUM 个位宽为 DATA_WEIGHT_WIDTH bits 的数据.

- DDR 中一个地址存储一个 byte 的数据, 即相邻两组 128 bits 的数据, 地址变化为 0x10.

- weight_size_ddr, index_weight_ddr, TILE_WEIGHT_DDR_SIZE 均为 以 128 bits 为单位的索引，即当 weight_size_ddr + 1 时，对应 DDR 中地址加 0x10.

- weight_tile_ddr_size: 每个分块 (tiling) 所需的以 128 bits 为单位的 DDR 存储空间. 计算方式为剩余需要处理的权重个数和一个分块 (tiling) 所能容纳的数据个数的最小值.

- weight_size_ddr: 初始化为以 128 bits 为单位的, 一个 tiling weight 对应的片上所需存储空间. 每完成一个分块 (tiling) 的计算后, 减去分块消耗的 weight 数据 (即得到剩余未处理的 weight 数据个数). 需要注意的是, 由于在当前设计中 weight 的基地址永远是0. 所以用 `weight_size_ddr - index_weight_ddr` 的方式代替上述计算. 当基地址不为 0 时, 这里要有优化.

- index_weight_ddr: 每个 weight 分块读取时的基地址, 以 128 bits 为单位.

下述所示, 为 PE 阵列计算调度伪代码.
```python
# 完整权重数据和激活值数据的分块个数, 以定点数 (浮点数) 个数为单位.
OYT = ceil(input_size / (double)TILE_ACT_SIZE);
OFT = ceil(kernel_size / (double)TILE_WEIGHT_SIZE);

# 每个分块中, 需要按输入通道复用算子的次数.
IN_F = nInputPlane / IN_PARAL;

# 加载分块 weight (tiling_weight) 数据的循环
for oft = 1: OFT
  UpdateWeight           # Update weight for next tile. Load from DDR.
  ResetAct               # Repeat activation in tile.

  # 加载分块 act (tiling_act) 数据的循环
  for oyt = 1: OYT
    ResetWeight         # Repeat weight in tile
    UpdateAct           # Update activation for next tile. Load from DDR.

    # 每个 tiling_act 中包含激活值行数的循环.
    for oy = 1: OY
      ResetWeight       # Repeat weight in tile
      UpdateAct         # Update activation in row

      # 每个 tiling_weight 中输出通道的循环.
      for of = 1: OF
        UpdateWeight    # Update weight in output channels
        ResetAct        # Repeat activation data in tile

        # 每个分块中输入通道的循环.
        for in_f = 1: IN_F
          UpdateWeight  # Update weight in input channels
          UpdateAct     # Update activation in input channels
          Calculation   # 64*4*3*3 PE cluster
```


### 2.5.3 Output data schedule

下述所示, 为输出数据调度伪代码
```python
# row_tile_num * row_in_tile = total_row_num
for row_tile_num

  # output_ch_tile_num * output_ch_in_tile = total_output_ch_num
  for output_ch_tile_num                       # --> `total_cnt` in verilog

    for row_in_tile                            # --> `line_cnt` in verilog

      # `output_pe_paral` represents output parallelism degree of PE.
      for output_ch_in_tile / output_pe_paral
        for column
          # - Output of PE cluster will be stored in x FIFO at once.
          # - In verilog, there are 8 fifo, which data width is 128 bits.
          # - At same time, PE cluster output bandwidth is 64 output channels,
          #   which data width is 16 bits.
          StorePixel2Fifo1
          StorePixel2Fifo2
          ...
          StorePixel2Fifox
```


# 3 SDK 读 SD 卡编译标识符

REMEMBER to set `Software Platfoem Inferred Flags` as
```sh
-Wl,--start-group,-lxilffs,-lxil,-lgcc,-lc,--end-group
```


# 4 `Petalinux`

常用命令:

- Command to convert raw video format
  ```sh
  $ ffmpeg -i test.webm -c:v rawvideo -pix_fmt yuyv422 test.yuv
  ```

- Command for compiling
  ```sh
  $ CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ cmake -G"Eclipse CDT4 - Unix Makefiles" -DCMAKE_ECLIPSE_EXECUTABLE=${XILINX_SDX}/eclipse/lnx64.o/eclipse ../src

  # deprecate
  $ CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ \
    cmake -G"Eclipse CDT4 - Unix Makefiles" -DCMAKE_ECLIPSE_EXECUTABLE=${XILINX_SDX}/eclipse/lnx64.o/eclipse \
    -DUSER_INTERFACE=GUI ../src
  ```

- Command for GStreamer
  ```sh
  # src: YUYV file
  $ gst-launch-1.0 filesrc location=/media/test.yuv \
  ! rawvideoparse width=1920 height=1080 format=GST_VIDEO_FORMAT_YUY2 \
  ! queue ! queue ! capsfilter ! fpsdisplaysink

  # src: jpg image
  $ gst-launch-1.0 filesrc location=./test.jpg ! jpegdec ! imagefreeze ! fpsdisplaysink

  # src: video
  # success
  $ startx /usr/bin/gst-launch-1.0 v4l2src device="/dev/video2" ! \
  video/x-raw,width=640,height=360,format=YUY2,framerate=30/1 ! \
  videoconvert ! fpsdisplaysink sync=false

  # fail
  $ gst-launch-1.0 -v v4l2src device="/dev/video2" \
  ! video/x-raw,width=640,height=480,format=BGR,framerate=30/1 \
  ! fpsdisplaysink

  # fail
  $ gst-launch-1.0 v4l2src ! image/jpeg, width=1920, height=1080, framerate=30/1 ! \
  jpegdec ! omxh264enc control-rate=variable target-bitrate=1000000 ! h264parse ! \
  fpsdisplaysink

  # src: test src
  $ gst-launch-1.0 videotestsrc pattern=snow \
  ! video/x-raw,width=1920,height=1080 ! fpsdisplaysink

  $ gst-launch-1.0 videotestsrc \
  ! video/x-raw,width=1920,height=1080,framerate=60/1 ! fpsdisplaysink
  ```

- Check memory
  ```sh
  $ ps -o pid,user,%mem,command ax | grep test
  ```

- Run application
  ```sh
  $ startx ./test_gst
  ```

- Test led with petalinux
  ```sh
  # Select the device-tree
  $ cd $TRD_HOME/petalinux/bsp/project-spec/meta-user/recipes-bsp/device-tree/files
  $ cp zcu102-base-test-led.dtsi system-user.dtsi

  # import the hdf file generated by Vivado and build
  $ cd $TRD_HOME/petalinux/bsp
  $ petalinux-config \
  --get-hw-description=/media/project/test/fpga/test_dma/test_dma.sdk \
  --silentconfig
  $ petalinux-build

  # Create a boot image.
  $ cd $TRD_HOME/petalinux/bsp/images/linux
  $ petalinux-package --boot --bif=../../project-spec/boot/dm6.bif --force

  # Copy the generated boot image and Linux image to the SD card directory.
  $ cp BOOT.BIN image.ub $TRD_HOME/sd_card/test_led
  ```

- petalinux configure
  ```sh
  $ petalinux-config -c kernel
  $ petalinux-config -c rootfs
  # (add some apps in [Filesystem Package] and [Apps] menu)
  ```

- petalinux project
  ```sh
  # Create new project
  $ petalinux-create --type project --template zynqMP --name dma_test

  # For error "Failed to open PetaLinux lib: librdi_commonxillic.so"
  $ echo "/opt/Xilinx/petalinux/tools/lib" > /etc/ld.so.conf.d/petalinux.so.conf
  $ ldconfig
  ```
