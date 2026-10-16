# B 组感知工程（ACG720 / GW5AT-60B）

这份工程已实现 B 的第一阶段候选版本：

- TFmini-S UART 接收、校验、异常值剔除、4 点滑动平均；
- WT901 UART 接收、校验、欧拉角换算、低通滤波和航向角跨 ±180° 处理；
- WT901 自动兼容 9600 和 115200 baud，以合法校验帧作为选择依据；
- 通过外接 USB-TTL 每秒 20 次发送带序号、状态和 CRC16 的 V3 遥测帧；
- OV5640 初始化、RGB565 采集、DDR3 帧缓存、720p HDMI 显示；
- HDMI 左上角叠加距离、横滚、俯仰、航向、车辆模式和左右转速信息；
- 摄像头和两路传感器已合到同一个 `b_full_top` 顶层。

## 现在该做什么

1. 先只给开发板、摄像头和 HDMI 链路上电，烧录：
   `camera/ov5640_ddr3_hdmi_full/impl/pnr/b_full_hdmi_sensor_usbttl_v3.fs`。
2. 确认摄像头画面；再断电连接 TFmini-S 和 WT901。
3. 把 `sensor_uart_tx` 对应的 GPIO0_13 接到 USB-TTL 的 RXD，并与 FPGA 共地。
   USB-TTL 接 RK3588 后运行：`python3 tools/sensor_link_receiver_v3.py /dev/ttyUSB0`。
4. 按 `docs/上板验收.md` 做最后的实物验收。

不要带电插拔摄像头、传感器或 HDMI 排线。所有 UART 必须共地，FPGA UART 引脚只接受 3.3 V 逻辑。外接 CP2102 只连接 RXD 和 GND，不连接 VCC、5V、3V3 或 TXD。

## 接线

| 功能 | ACG720 信号/管脚 | 连接 |
|---|---|---|
| TFmini-S 数据 | `tof_uart_rx` / A13 / GPIO0_0 | TFmini-S TX |
| WT901 数据 | `imu_uart_rx` / A14 / GPIO0_1 | WT901 TX |
| RK3588 遥测 | `sensor_uart_tx` / D15 / GPIO0_13 | USB-TTL RXD |
| 地 | GND | 三个设备的 GND 全部相连 |

TFmini-S 本体按其铭牌/说明书使用 5 V 供电，但 UART TX 是 3.3 V 逻辑。WT901 型号较多，电源电压不要凭线色猜，按你手中模块丝印接 VCC/GND/TX；本工程不需要连接两个传感器的 RX。

## 电脑显示格式

串口为 115200、8N1。每帧固定 28 字节：

```text
A5 5A  01 10 15  payload(21 bytes)  CRC16(低,高)
```

负载包含序号、状态、距离、强度、三轴姿态、两路错误计数和 FPGA 运行时间。角度单位是 0.01°，距离单位是 mm。CRC 使用 CRC-16/CCITT-FALSE，详细偏移见 `docs/接口说明.md`。

## 交给 C 的接口

实例化 `rtl/integration/perception_hub.v` 后直接使用：

```text
front_distance_mm[15:0]  无符号，mm
distance_valid           新距离脉冲
roll_cdeg[15:0]          有符号，0.01°
pitch_cdeg[15:0]         有符号，0.01°
yaw_cdeg[15:0]           有符号，0.01°，范围约 -18000..18000
imu_valid                新姿态脉冲
```

目前只有一只 TFmini-S，所以真实可提供的是 `front_distance`；`left_distance` 和 `right_distance` 不能靠软件凭空产生。若以后增加两只同型号传感器，可以复用同一套 UART、解析和滤波模块。摄像头第一阶段交付是稳定 HDMI 画面，不包含 AI 识别结果。

## 已完成的验证

| 项目 | 结果 | 证据含义 |
|---|---|---|
| UART / TFmini-S / WT901 / 滤波回归 | 5/5 PASS | 人工构造协议帧的有限测试通过 |
| V3 遥测帧与 RK3588 解析器 | PASS | 两帧字节顺序、序号、CRC、重同步和字段解析通过 |
| 传感器独立工程综合与布局布线 | PASS | 成功生成 `b_sensor_demo.fs` |
| 传感器独立工程 50 MHz 时序 | PASS | Setup/Hold 违例端点均为 0；Fmax 78.826 MHz |
| 摄像头+传感器完整工程布局布线 | PASS | 成功生成 `b_full_hdmi_sensor_usbttl_v3.fs` |
| 完整工程 50 MHz 域 | PASS | Setup/Hold 违例端点均为 0；Fmax 52.764 MHz |
| HDMI 专用发送模块 | PASS（工具构建） | 完整顶层使用自定义 True-HDMI（含 AVI InfoFrame）和 Gowin OSER10；官方 Gowin DVI 与自定义 DVI 工程仅用于 RK3588 通道锁定对照 |
| 屏幕文字叠加仿真 | PASS | 有限测试验证文字格式、字符像素和视频同步延迟一致 |
| 真实距离与姿态 | 上板基础功能通过 | 用户已观察到屏幕距离随目标移动、三轴姿态随 WT901 转动而变化；这不等同于精度标定 |
| 真实 HDMI 图像与叠加 | 上板基础功能通过 | 用户提供的实屏照片显示摄像头画面与完整 OSD，随后确认姿态数据恢复正常 |

因此，传感器逻辑和显示叠加已有软件/工具验证，并完成一次真实上板基础功能观察。该观察证明当前接线和码流能够显示画面与变化中的传感器数值，但不代表已经完成长时间稳定性、测量精度或运动状态验收。当前报告中仍有厂家 DDR 核内部、摄像头异步 FIFO 和复位相关路径告警；若以后出现无图或闪屏，先烧录 `camera/ov5640_ddr3_hdmi_full/reference/vendor_camera_only.fs` 区分硬件链路与新增逻辑问题。

当前推荐码流是 `b_full_hdmi_sensor_usbttl_v3.fs`。它保留 HDMI 图像与 OSD，同时把传感器外发接口改为独立的 `sensor_uart_tx`。电机仍有默认锁止保护；首次验证必须悬空四轮，并先单独验证 HDMI 和 USB-TTL 两条链路。

## 工程目录

```text
rtl/                         B 自写、可复用的传感器 RTL
tb/                          自动仿真测试
constraints/                 传感器独立工程管脚与时序约束
tools/sensor_link_receiver_v3.py  RK3588/Linux 串口接收器
tools/monitor.py              指向 V3 接收器的兼容入口
camera/ov5640_ddr3_hdmi_full  基于 ACG720 官方例程的完整工程
docs/                         接口和上板验收说明
```

## 重新验证

仿真：

```powershell
cd b_perception\tb
.\run_tests.ps1
```

完整工程：

```powershell
cd C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full
& "C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe" build_data_transport_v3.tcl
```

## 来源说明

摄像头和 DDR3 基础链路来自 ACG720 厂家随板例程“OV5640 DDR3 HDMI”。本工程重新生成了适配 GW5AT-60B 的 DDR3 核，添加传感器顶层、滤波、遥测和屏幕文字；当前 `b_full_top` 将 `HDMI_TRUE_MODE` 固定为 1、`HDMI_TEST_PATTERN` 固定为 0，使用自定义 True-HDMI（含 AVI InfoFrame）和 Gowin OSER10 输出实际摄像头/OSD画面。仓库同时保留官方 Gowin DVI 彩条和自定义 DVI 彩条两个独立诊断工程，用于对照 RK3588 的 Ch0/Ch1/Ch2 锁定结果。传感器协议模块、滤波模块和 OSD 是本工程新增代码。厂家例程中 DDR/跨时钟相关的剩余告警如实保留，未伪装成已经通过实物验收。
