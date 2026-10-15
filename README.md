# OV5640 + DDR3 + HDMI + 传感器完整工程

顶层为 `b_full_top`。图像固定走 HDMI1，传感器遥测固定走外接 USB-TTL；两条链路互不依赖。当前完整顶层固定为 `HDMI_TRUE_MODE=1`、`HDMI_TEST_PATTERN=0`，通过自定义 True-HDMI（含 AVI InfoFrame）发送实际摄像头与 OSD 画面。遥测 V3 使用 `sensor_uart_tx` / D15 / GPIO0_13、115200 8N1、固定 28 字节帧和 CRC16。

`rk3588_gowin_dvi_link_test.gprj` 是官方 Gowin DVI 彩条对照工程，`rk3588_custom_dvi_link_test.gprj` 是自定义 TMDS/DVI 彩条对照工程；两者都不代表完整顶层当前加载的 HDMI 模式。

当前可烧录文件：`impl/pnr/b_full_hdmi_sensor_usbttl_v3.fs`。

排查摄像头硬件用的厂家原始码流：`reference/vendor_camera_only.fs`。它不含 TFmini-S、WT901 和电脑遥测。

当前工具结果：综合、布局布线和码流生成成功；Setup/Hold 违例端点均为 0。摄像头 PCLK 仍有通用布线 PR1014 警告，所以 HDMI 最终判据仍是 RK3588 稳定锁定和连续取流。

当前码流是低速自主避障 + 红外启停版。上电默认锁车；S3 或遥控播放/暂停启动，S4、S0 或遥控 CH− 停止。两路输出采用用户实测过的 20% 低速工作点，左右方向已按“先前实际为后退”的更正同时反相。首次验证必须悬空四轮，完整步骤见仓库根目录 `MORNING_HANDOFF.md`。

WT901 输入同时由 9600 与 115200 baud 两个接收器监听，并以通过校验的姿态帧驱动滤波和显示。对应双速率仿真已加入 `b_perception/tb/tb_perception_hub_dualbaud.v`。
