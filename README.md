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

## 1.2 优化备忘录

记录目前基于 Verilog 设计中仍可以优化的地方.

- **DDR 中 128 bit 中数据好像排反了**

  - Verilog 逻辑修改

  - 生成用于仿真的数据的 python 代码

- 改位宽后, 修改 DDR 读写并行度, 减少数据传输时间

- 输入8通道需要优化，输入四通道即可

- PL 接收数据时若 PS 的数据包中有无效数据也会被 PL 计算逻辑接受

- weight 写 DDR 和读 DDR 尺寸一致，不能设置成不同的尺寸

- 截位宽

  - 溢出

  - 动态截位宽

- 添加累加溢出的判断

- 去掉 config.v，将配置过程在PS侧完成

- merge activation DMA and weight DMA

- 感觉 config.v 中配置状态跳转和每个模块中配置状态逻辑有缺陷，当配置信息不连续时
极端情况下可能会有逻辑问题。

- vivado 的 FIFO IP 的配置中, Programmable Flags 中 Full Threshold Assert Value 有什么影响

## 1.3 FPGA 设计

### 1.3.1 PS 配置寄存器定义

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


### 1.3.2 数据存储格式

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

### 1.3.3 移位

#### 1.3.3.1 计算参数备忘

当激活值位宽为 8 位, 整数部分为 3 位; 权重位宽为 4 位时; 计算结果为16位, 整数部分为7位. 巻积16位计算结果按照整数部分4位量化可以和硬件计算结果保持一致.

移位映射: shift code: `lx` 左移 x 位, `rx` 右移 x 位. 最高位符号位, 0 为正, 1为负.

| `l3`| `l2`| `l1`|  `0`| `r1`| `r2`| `r3`| `r4`|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|000|001|010|011|100|101|110|111|


#### 1.3.3.2 原理简介

For the shift network, the weight part is represented by the original code plus the sign bit, and the activation value part is represented by the complement code
- The activation value is represented by the complement

- The weight part is currently shifted to the right uniformly, and the sign indicates whether to take the complement or not, which means, the sign bit and the value bit represent operations at different positions

- For example, $z = Shift(w, x) = ax\times 2^b$, a and b are weights, which a indicates if sign is $+1$ or $-1$, b indicates shift bits, and $b <= 0$; $x$ indicates activation and calculate with $a$ in complement form.


### 1.3.4 Verilog 设计中的数据流排布

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


## 1.4 SDK 读 SD 卡编译标识符

REMEMBER to set `Software Platfoem Inferred Flags` as
```
-Wl,--start-group,-lxilffs,-lxil,-lgcc,-lc,--end-group
```


## 1.5 Hardware Utilization (VGG)

VGG 硬件资源使用情况.

- BRAM

  | 类型        | 数量 | 大小 (Bytes) |
  | ----------- | ---- | ------------ |
  | act_ram     | $16$ | $25088$      |
  | weight_ram  | 256  | 1152         |
  | partial_ram | 256  | 224          |

- DRAM: 25 MB


# 2 `Petalinux`

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



# 3 Architecture

## 3.1 AlexNet Architecture

| Layer | Input layer                      | Output layer                     | Operation                                        |
| ----- | -------------------------------- | -------------------------------- | ------------------------------------------------ |
| 1     | $3 \times 224 \times 224, 150528$ | $64 \times 54 \times 54,186624$  | $conv: 64 \times 3 \times 11 \times 11, step: 4$ |
| 2     | $64 \times 54 \times 54,186624$  | $64 \times 26 \times 26,43264$   | $mp:3,step:2$                                    |
| 3     | $64 \times 26 \times 26,43264$   | $192 \times 26 \times 26,129792$ | $conv:192 \times 64 \times 5 \times 5$           |
| 4     | $192 \times 26 \times 26,129792$ | $192 \times 12 \times 12,27648$  | $mp:3,step:2$                                    |
| 5     | $192 \times 12 \times 12,27648$  | $384 \times 12 \times 12,55296$  | $conv:384 \times 192 \times 3 \times 3$          |
| 6     | $384 \times 12 \times 12,55296$  | $384 \times 12 \times 12,55296$  | $conv:384 \times 384 \times 3 \times 3$          |
| 7     | $384 \times 12 \times 12,55296$  | $256 \times 12 \times 12,36864$  | $conv:256 \times 384 \times 3 \times 3$          |
| 8     | $256 \times 12 \times 12,36864$  | $256 \times 5 \times 5,6400$     | $mp:3,step:2$                                    |
| 9     | $256 \times 5 \times 5,6400$     | $4096 \times 1 \times 1,4096$    | $conv:4096 \times 256 \times 5 \times 5$         |
| 10    | $4096 \times 1 \times 1, 4096$   | $4096 \times 1 \times 1, 4096$   | $conv:4096 \times 4096 \times 1 \times 1$        |
| 11    | $4096 \times 1 \times 1,4096$    | $1000 \times 1 \times 1,1000$    | $conv:1000 \times 4096 \times 1 \times 1$        |



## 3.2 VGG-16 Architecture

- Convolution part

| Layer | Input Layer(3.5M/8bits)              | Output Layer(3.5M/8bits)             | Operation (7M/4bits)                |
| ----- | ------------------------------------ | ------------------------------------ | ---------------------------------------- |
| 1     | $3 \times 224 \times 224, 150528$     | $64 \times 224 \times 224, 3211264$   | $conv: 64 \times 3 \times 3 \times 3$    |
| 2     | $64 \times 224 \times 224, 3211264$   | $64 \times 224 \times 224, 3211264$   | $conv: 64 \times 64 \times 3 \times 3$   |
| 3     | $64 \times 224 \times 224, 3211264$   | $64 \times 112 \times 112, 802816$   | $mp:2,step:2$                            |
| 4     | $64 \times 112 \times 112, 802816$   | $128 \times 112 \times 112, 1605632$ | $conv: 128 \times 64 \times 3 \times 3$  |
| 5     | $128 \times 112 \times 112, 1605632$ | $128 \times 112 \times 112, 1605632$ | $conv: 128 \times 128 \times 3 \times 3$ |
| 6     | $128 \times 112 \times 112, 1605632$ | $128 \times 56 \times 56, 401408$    | $mp:2,step:2$                            |
| 7     | $128 \times 56 \times 56, 401408$    | $256 \times 56 \times 56, 802816$    | $conv: 256 \times 128 \times 3 \times 3$ |
| 8     | $256 \times 56 \times 56, 802816$    | $256 \times 56 \times 56, 802816$    | $conv: 256 \times 256 \times 3 \times 3$ |
| 9     | $256 \times 56 \times 56, 802816$    | $256 \times 56 \times 56, 802816$    | $conv: 256 \times 256 \times 3 \times 3$ |
| 10    | $256 \times 56 \times 56, 802816$    | $256 \times 28 \times 28, 200704$    | $mp:2,step:2$                            |
| 11    | $256 \times 28 \times 28, 200704$    | $512 \times 28 \times 28, 401408$    | $conv: 512 \times 256 \times 3 \times 3$ |
| 12    | $512 \times 28 \times 28, 401408$    | $512 \times 28 \times 28, 401408$    | $conv: 512 \times 512 \times 3 \times 3$ |
| 13    | $512 \times 28 \times 28, 401408$    | $512 \times 28 \times 28, 401408$    | $conv: 512 \times 512 \times 3 \times 3$ |
| 14    | $512 \times 28 \times 28, 401408$    | $512 \times 14 \times 14, 100352$    | $mp:2,step:2$                            |
| 15    | $512 \times 14 \times 14, 100352$    | $512 \times 14 \times 14, 100352$    | $conv: 512 \times 512 \times 3 \times 3$ |
| 16    | $512 \times 14 \times 14, 100352$    | $512 \times 14 \times 14, 100352$    | $conv: 512 \times 512 \times 3 \times 3$ |
| 17    | $512 \times 14 \times 14, 100352$    | $512 \times 14 \times 14, 100352$    | $conv: 512 \times 512 \times 3 \times 3$ |
| 18 | $512 \times 14 \times 14, 100352$ | $512 \times 7 \times 7, 25088$ | $mp:2,step:2$ |
| 19 | $512 \times 7 \times 7, 25088$ | $4096 \times 1 \times 1, 4096$ | $conv: 4096 \times 512 \times 7 \times 7$ |
| 20 | $4096 \times 1 \times 1, 4096$ | $4096 \times 1 \times 1, 4096$ | $conv: 4096 \times 4096 \times 1 \times 1$ |
| 21 | $4096 \times 1 \times 1, 4096$ | $1000 \times 1 \times 1, 1000$ | $conv: 1000 \times 4096 \times 1 \times 1$ |

- Address:
  - Activation offset `0x81c0ed80`
  
  - Activation output first address: 
  
    $Activation\_offset + ACT\_SIZE + 56 \times 256 \times sizeof(real\_act)$
  
  - Last write address `0x823b6d60`
  
  - First word of last line `0x823afd80`, `0x823b6a00`



## 3.3 YOLOv3 tiny

| Layer   | Input Layer                                                | Output Layer                       | Operation                                        | ram cost           |
| ------- | ---------------------------------------------------------- | ---------------------------------- | ------------------------------------------------ | ------------------ |
| 1       | $3 \times 416 \times 416, 519168$                          | $16 \times 416 \times 416,2768896$ | $conv:3 \times 16 \times 3 \times 3,432$         | 519168, **432**    |
| 2       | $16 \times 416 \times 416,2768896$                         | $16 \times 208 \times 208,692224$  | $mp:2,step:2$                                    |                    |
| 3       | $16 \times 208 \times 208,692224$                          | $32 \times 208 \times 208,1384448$ | $conv:16 \times 32 \times 3 \times 3,4608$       | 692224, **4608**   |
| 4       | $32 \times 208 \times 208,1384448$                         | $32 \times 104 \times 104,346112$  | $mp:2,step:2$                                    |                    |
| 5       | $32 \times 104 \times 104,346112$                          | $64 \times 104 \times 104,692224$  | $conv:32 \times 64 \times 3 \times 3,18432$      | 3461112, **18432** |
| 6       | $64 \times 104 \times 104,692224$                          | $64 \times 52 \times 52,173056$    | $mp:2,step:2$                                    |                    |
| 7       | $64 \times 52 \times 52,173056$                            | $128 \times 52 \times 52,346112$   | $conv:64 \times 128 \times 3 \times 3,73728$     | 173056, **73728**  |
| 8       | $128 \times 52 \times 52,346112$                           | $128 \times 26 \times 26,86528$    | $mp:2,step:2$                                    |                    |
| 9       | $128 \times 26 \times 26,86528$                            | $256 \times 26 \times 26,173056$   | $conv:128 \times 256 \times 3 \times 3,294912$   | **86528**, 294912  |
| bench 1 |                                                            |                                    |                                                  |                    |
| 10      | $256 \times 26 \times 26,173056$                           | $256 \times 13 \times 13,43264$    | $mp:2,step:2$                                    |                    |
| 11      | $256 \times 13 \times 13,43264$                            | $512 \times 13 \times 13,86528$    | $conv:256 \times 512 \times 3 \times 3,1179648$  | **43264**, 1179648 |
| 12      | $512 \times 13 \times 13,86528$                            | $512 \times 13 \times 13,86528$    | $mp:2,step:1$                                    |                    |
| 13      | $512 \times 13 \times 13,86528$                            | $1024 \times 13 \times 13,173056$  | $conv:512 \times 1024 \times 3 \times 3,4718592$ | **86528**, 4718592 |
| 14      | $1024 \times 13 \times 13,173056$                          | $256 \times 13 \times 13,43264$    | $conv:1024 \times 256 \times 1 \times 1,262400$  | **173056**, 262400 |
| 15      | $256 \times 13 \times 13,43264$                            | $512 \times 13 \times 13,86528$    | $conv:256 \times 512 \times 3 \times 3,1179648$  | **43264**, 1179648 |
| 16      | $512 \times 13 \times 13,86528$                            | $255 \times 13 \times 13,43095$    | $conv:512 \times 255 \times 1 \times 1,130560$   | **86528**, 130560  |
| bench 2 |                                                            |                                    |                                                  |                    |
| 15      | $256 \times 13 \times 13,43264$                            | $128 \times 13 \times 13,21632$    | $conv:256 \times 128 \times 1 \times 1,32768$    | 43264, **32768**   |
| 16      | $128 \times 13 \times 13,21632$                            | $128 \times 26 \times 26,86528$    | $upsample$                                       |                    |
| 17      | $128 \times 26 \times 26 + 256 \times 26 \times 26,259584$ | $384 \times 26 \times 26,259584$   | $concat$                                         |                    |
| 18      | $384 \times 26 \times 26,259584$                           | $256 \times 26 \times 26,173056$   | $conv:384 \times 256 \times 3 \times 3,884736$   | **259584**, 884736 |
| 19      | $256 \times 26 \times 26,173056$                           | $255 \times 26 \times 26,172380$   | $conv:256 \times 255 \times 1 \times 1,65280$    | 173056, **65280**  |

Total weight number:
$8845744=432+4608+18432+73728+294912+1179648+4718592+262400+1179648+130560+32768+884736+65280$




Number of data:

| time    | DDR                                                                                                                           |
| ----    | ------------------------------------------------------------------------------------------------------------------------------|
| 1       | 0 ~ 519167 (in),       692224 ~ 3461119 (out)                                                                                 |
| 2       | 0 ~ 692223 (out),      692224 ~ 3461119 (in)                                                                                  |
| 3       | 0 ~ 692223 (in),       692224 ~ 2076671 (out)                                                                                 |
| 4       | 0 ~ 346111 (out),      692224 ~ 2076671 (in)                                                                                  |
| 5       | 0 ~ 346111 (in),       692224 ~ 1384447 (out)                                                                                 |
| 6       | 0 ~ 173055 (out),      692224 ~ 1384447 (in)                                                                                  |
| 7       | 0 ~ 173055 (in),       692224 ~ 1038335 (out)                                                                                 |
| 8       | 0 ~ 86527  (out),      692224 ~ 1038335 (in)                                                                                  |
| 9       | 0 ~ 86527  (in),       692224 ~ 865279  (out)                                                                                 |
| bench 1 |                                                                                                                               |
| 10      | 0 ~ 43263  (out),      692224 ~ 865279  (in)                                                                                  |
| 11      | 0 ~ 43263  (in),       173056 ~ 259583  (out), 692224 ~ 865279 (preserve)                                                     |
| 12      | 0 ~ 86527  (out),      173056 ~ 259583  (in),  692224 ~ 865279 (preserve)                                                     |
| 13      | 0 ~ 86527  (in),       173056 ~ 346111  (out), 692224 ~ 865279 (preserve)                                                     |
| 14      | 0 ~ 43263  (out),      173056 ~ 346111  (in),  692224 ~ 865279 (preserve)                                                     |
| 15      | 0 ~ 43263  (in),       173056 ~ 259583  (out), 692224 ~ 865279 (preserve)                                                     |
| 16      | 0 ~ 43263  (preserve), 173056 ~ 259583  (in),  692224 ~ 865279 (preserve), 3461120 ~ 3504214 (fout)                           |
| bench 2 |                                                                                                                               |
| 17      | 0 ~ 43263  (in),       43264 ~ 64895    (out), 692224 ~ 865279 (preserve), 3461120 ~ 3504214 (fout)                           |
| 18      | 43264 ~ 64895 (in),    605696 ~ 692223  (out), 692224 ~ 865279 (preserve), 3461120 ~ 3504214 (fout)                           |
| 19      | 0 ~ 173055 (out),      605696 ~ 865279  (in),                              3461120 ~ 3504214 (fout)                           |
| 20      | 0 ~ 173055 (in),                                                           3461120 ~ 3504214 (fout), 3504215 ~ 3676594 (fout) |
