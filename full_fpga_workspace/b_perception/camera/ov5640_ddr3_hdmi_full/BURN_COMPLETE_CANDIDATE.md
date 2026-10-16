# 完整版候选码流烧录与验收

> 2026-10-10 更新：下文保留为历史版本记录，不是当前烧录指引。新文件与剩余问题见 [本次检查结果](C:/chatgpt/fpga/deliverables/hdmi_fix_20261010/CHECKS.md)。当前完整候选是 `C:\chatgpt\fpga\deliverables\hdmi_fix_20261010\b_full_hdmi_protocol_fixed_20261010.fs`；它仍有全工程时序待处理项，尚未实物验收。先使用同目录的独立彩条诊断版验证 RK3588。

## 唯一需要烧录的文件

`impl/pnr/b_full_rk3588_complete_candidate.fs`

该文件面向 `ACG720-GW5AT60 / GW5AT-60B`，包含摄像头、DDR3、720p60 真
HDMI、传感器 OSD、红色目标框、TFmini-S、WT901、避障、遥控、编码器闭环、
双电机、路径点导航、目标跟随，以及 RK3588 双向 UART 命令/遥测。

## 烧录方式

在 Gowin Programmer 中选择：

- Access Mode：`External Flash Mode 5AT`
- Operation：`exFlash Erase, Program, Verify`
- FS File：上面的 `b_full_rk3588_complete_candidate.fs`

出现 `Program and Verify Flash successfully` 和 `Finished` 后断电，拔掉下载线，
再由车载电源重新上电。不要使用 `SRAM Program` 做脱机验收。

## 上电安全顺序

1. 先把车轮架空，确认电机电源、FPGA 电源以及所有 GND 共地。
2. 接好摄像头、TFmini-S、WT901、电机驱动、编码器和 HDMI。
3. 接 RK3588 UART 时只能使用 3.3 V TTL，并交叉连接：FPGA `M15/TX` 到
   RK3588 `RX`，FPGA `J21/RX` 到 RK3588 `TX`，再连接 GND。
4. 上电后先确认显示和传感器数值，再按绿色开始键或遥控启动。

## RK3588 HDMI 验收

```sh
v4l2-ctl -d /dev/video40 --query-dv-timings
v4l2-ctl -d /dev/video40 --get-fmt-video
v4l2-ctl -d /dev/video40 --stream-mmap=4 --stream-count=100 --stream-poll
```

目标结果是连续多次识别 `1280x720`、约 `74250000 Hz`、progressive，且不再
出现 `No locks available`。代码编译、布局布线和仿真通过不等于这一项已经在
实物上测得；必须以 RK3588 的上述输出为最终证据。

## 回退文件

如果完整版候选影响车辆基本运动，可烧回已验证能跑车的
`impl/pnr/b_full_ai_tasks_candidate.fs`。该回退文件使用旧 DVI 输出，不能作为
RK3588 HDMI RX 锁定验收文件。
