# RK3588 HDMI RX 稳定锁定测试

> 2026-10-10 更新：下文是旧测试版本，不能代表当前源码。请按 [新交付检查单](C:/chatgpt/fpga/deliverables/hdmi_fix_20261010/CHECKS.md) 使用 `C:\chatgpt\fpga\deliverables\hdmi_fix_20261010\rk3588_hdmi_protocol_fixed_20261010.fs`，哈希见同目录 `manifest.json`。旧文件仍保留，不应混用。

## 本次码流

烧录文件：`impl/pnr/rk3588_hdmi_link_test_720p60.fs`

旧文件当前实测 SHA-256：`C54C81C98D6C82548C367057D32F65CFBB1E6486A564349989061E3F10A1532C`。此前记录的 `6F5D...07CF2` 与现存文件不一致，不能再用作身份验证。

这是独立诊断码流，不是小车完整版。它只包含：

- ACG720-GW5AT60 的 50 MHz 输入；
- 单级 PLL 产生 371.25 MHz；
- 专用 `CLKDIV / 5` 产生 74.25 MHz；
- 自由运行的 CEA VIC 4、1280x720p60 时序；
- FPGA 内部固定彩条；
- HDMI Data Island、TERC4、BCH 和 AVI InfoFrame；
- 4 个 OSER10 和 HDMI1 TMDS 差分输出。

它不包含摄像头、DDR、帧缓存、电机、编码器、ToF、IMU 或遥控逻辑。因此即使没有摄像头帧，HDMI 时钟、HSYNC、VSYNC 和 DE 也会连续运行。

## 已完成的静态验证

Gowin V1.9.12.03 已完成综合、布局布线和码流生成。实现报告显示：

- `pixel_clk`：74.250 MHz，约束周期 13.468 ns；
- `serial_clk_x5`：371.250 MHz，约束周期 2.694 ns；
- setup violated endpoints：0；
- hold violated endpoints：0；
- pixel 域实际 Fmax：231.783 MHz；
- 4 个 OSER10；
- TMDS 管脚实现为 LVDS25。

原实现把像素域的 TX reset 直接接到 371.25 MHz OSER10，报告出现 4 个 recovery 违例，最差为 -2.827 ns。本测试版让 OSER10 连续运行，只在编码器上游复位，消除了该跨域复位和全部负裕量。

## 安全烧录

此诊断码流没有电机控制输出。烧录前必须：

1. 断开电机电池或将电机驱动板 STBY 硬件拉低；
2. 将车轮架空；
3. FPGA、RK3588 和显示器按原方式单独供电。

Programmer 选择 `exFlash Erase, Program, Verify`，烧录上述 `.fs` 后将 FPGA 完全断电再重新上电。

## 验收

先执行 60 秒日志观察：

```sh
sudo timeout 60 dmesg -w | grep -Ei "hdmirx|signal|avi|hdmi"
```

另开终端连续查询十次：

```sh
for i in $(seq 1 10); do
  echo "===== $i ====="
  v4l2-ctl -d /dev/video40 --query-dv-timings
  sleep 1
done
```

十次均应识别 1280x720、约 74250000 Hz、progressive；60 秒内不得再次出现 `signal not lock`。

如果该最小码流仍失锁，摄像头和 DDR 已被排除，下一步只检查 PLL 实际输出、OSER10 位序/相位、TMDS 电气质量和 HDMI packet 周期。

## Gowin Analyzer 观察点

源码已经对以下信号保留命名，供板上 Analyzer/ILA 采集：

- `pll_locked`
- `tx_reset`
- `tx_enable`
- `h_count[10:0]`
- `v_count[9:0]`
- `hsync`
- `vsync`
- `de`
- `hdmi_mode[2:0]`
- `pll_drop_seen`（TX 启动后 PLL 曾掉锁的粘滞标志）

连续保存 60 秒全速 ILA 数据会超过片上采样存储容量，因此采用“短窗口触发 + `pll_drop_seen` 粘滞标志 + RK3588 60 秒日志”进行等效长期检查。重新按复位键会清除该粘滞标志。

本板当前已验证的 60B 约束没有 FPGA HPD 端口，因此该版本不能采集 HPD，也没有用未经同步的 HPD 控制 TX。需要官方 60B 原理图确认 HPD 确实接入 FPGA 后，才能把它加入 Analyzer。
