# FPGA → RK3588：固定 720p60 彩条链路测试单

> 本文保留为厂商 DVI 诊断方案的历史记录。2026-10-10 的 HDMI 修订、生成文件和验收步骤见 [新交付检查单](C:/chatgpt/fpga/deliverables/hdmi_fix_20261010/CHECKS.md)。不要把 DVI 测试通过当作带 AVI 的 HDMI 测试通过。

## 目的

先彻底绕过摄像头、DDR、帧缓存、OSD和运动控制，仅验证：

```text
50 MHz参考时钟 → PLL/CLKDIV → 固定720p60时序 → 彩条
→ 高云DVI_TX TMDS编码/串行化 → HDMI接口 → RK3588 HDMI RX
```

本步骤的成功标准是RK3588连续识别出`1280×720p60 progressive`。诊断版是DVI视频模式，不发送AVI InfoFrame；出现`wait avi_pkt_recv failed`可以记录，但不能把它与基础TMDS不锁定混为一谈。

## 烧录文件

```text
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\impl\pnr\rk3588_gowin_dvi_720p60.fs
```

Gowin Programmer选择：

```text
exFlash Erase, Program, Verify
```

烧录完成后完全断电，再重新上电，避免旧SRAM配置继续运行。

SHA256：

```text
D3B3C6241C8B8B28C5108F38F18A24CA1641CDC7132492DFD7D7A44945F417F1
```

## 工程和代码路径

```text
工程：
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\rk3588_gowin_dvi_link_test.gprj

顶层及视频时序：
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\src\rk3588_gowin_dvi_link_test_top.v

PLL：
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\src\pll_60b\camera_pll_60b.v

高云DVI/TMDS发送IP：
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\src\dvi_tx\dvi_tx.v

管脚约束：
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\src\rk3588_hdmi_link_test.cst

时钟约束：
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\src\rk3588_gowin_dvi_link_test.sdc

构建脚本：
C:\chatgpt\fpga\b_perception\camera\ov5640_ddr3_hdmi_full\build_rk3588_gowin_dvi_link_test.tcl
```

## 固定视频时序代码

当前计数器范围严格为`0..total-1`：

```verilog
always @(posedge pixel_clk) begin
    if (!tx_enable) begin
        h_count <= 11'd0;
        v_count <= 10'd0;
    end else if (h_count == 11'd1649) begin
        h_count <= 11'd0;
        if (v_count == 10'd749)
            v_count <= 10'd0;
        else
            v_count <= v_count + 1'b1;
    end else begin
        h_count <= h_count + 1'b1;
    end
end

wire video_de = (h_count < 11'd1280) && (v_count < 10'd720);
wire video_hs = (h_count >= 11'd1390) && (h_count < 11'd1430);
wire video_vs = (v_count >= 10'd725) && (v_count < 10'd730);
```

时序参数：

| 项目 | 数值 |
|---|---:|
| Pixel Clock | 74.25 MHz |
| 水平有效区 | 1280 |
| 水平前肩 | 110 |
| 水平同步 | 40 |
| 水平后肩 | 220 |
| 水平总长度 | 1650 |
| 垂直有效区 | 720 |
| 垂直前肩 | 5 |
| 垂直同步 | 5 |
| 垂直后肩 | 20 |
| 垂直总长度 | 750 |
| HSync/VSync | 正极性 |
| 扫描方式 | Progressive |

帧率：

```text
74,250,000 / 1650 / 750 = 60 Hz
```

## HDMI/DVI发送代码

```verilog
DVI_TX_Top u_gowin_dvi_tx (
    .I_rst_n(1'b1),
    .I_serial_clk(serial_clk_x5),
    .I_rgb_clk(pixel_clk),
    .I_rgb_vs(video_vs),
    .I_rgb_hs(video_hs),
    .I_rgb_de(video_de),
    .I_rgb_r(rgb[23:16]),
    .I_rgb_g(rgb[15:8]),
    .I_rgb_b(rgb[7:0]),
    .O_tmds_clk_p(tmds_clk_p),
    .O_tmds_clk_n(tmds_clk_n),
    .O_tmds_data_p(tmds_data_p),
    .O_tmds_data_n(tmds_data_n)
);
```

`I_rst_n`固定为1是有意设计：高云IP会把该复位直接扇出到OSER10。此前从74.25 MHz域解除该复位时，布局布线报告出现约`-2.99 ns` recovery违例。当前版本使用器件GSR初始化，视频计数器则保持在`(0,0)`，直到PLL连续稳定约14 ms后才开始运行。当前构建报告为0个setup/hold违规端点。

## PLL配置

```text
输入：50 MHz
PLLA VCO：928.125 MHz
CLKOUT0：371.25 MHz
CLKDIV /5：74.25 MHz
TMDS每通道位速率：742.5 Mbps
```

主要参数：

```verilog
FCLKIN         = "50"
IDIV_SEL       = 2
MDIV_SEL       = 37
MDIV_FRAC_SEL  = 1
ODIV0_SEL      = 2
ODIV0_FRAC_SEL = 4
CLKFB_SEL      = "INTERNAL"
```

## 需要提供的ILA波形

以下是**期望波形/验收条件**，不是已经测得的波形。请用Gowin Analyzer/ILA实际抓取并回传截图或导出的波形文件。

探针：

```text
pixel_clk
pll_locked
tx_enable
h_count[10:0]
v_count[9:0]
video_de
video_hs
video_vs
```

建议分三次触发，不要求一次保存整帧：

### 波形A：一行水平时序

触发条件：

```text
v_count = 0，h_count接近1270
```

期望：

```text
h_count 0..1279    DE=1
h_count 1280..1389 DE=0，水平前肩
h_count 1390..1429 HSYNC=1，共40个pixel_clk
h_count 1430..1649 HSYNC=0，水平后肩
h_count 1649后回到0，v_count加1
```

### 波形B：垂直同步

触发条件：

```text
h_count = 0，v_count接近718
```

期望：

```text
v_count 0..719   垂直有效区
v_count 720..724 垂直前肩
v_count 725..729 VSYNC=1，共5个完整行周期
v_count 730..749 垂直后肩
v_count 749结束后回到0
```

VSYNC不得隔帧偏移半行，不得出现奇偶场交替，不得在帧中途清零。

### 波形C：PLL和发送使能

触发条件：上电后开始采集。

期望：

```text
pll_locked稳定变为1
等待约14 ms后tx_enable由0变1
运行期间pll_locked不得掉为0
tx_enable不得周期性变化
```

由于片内ILA无法合理保存60秒的全速像素数据，长时间稳定性应使用粘滞故障位或低速抽样监测；水平/垂直边界则用上述局部触发波形验证。

## TMDS管脚示波器检查

如果有带宽足够的示波器，请检查：

```text
TMDS Clock差分频率：约74.25 MHz
TMDS Data每通道位速率：约742.5 Mbps
时钟必须连续，不能每帧或每几秒中断
三路数据和时钟差分对P/N不得接反
```

普通低带宽示波器不能可靠判断742.5 Mbps眼图，只能用于确认时钟存在、频率大致正确以及是否周期性中断。

## 实机测试和必须回传的证据

1. FPGA HDMI直接接显示器，记录：稳定彩条、花屏、黑屏或无信号。
2. FPGA HDMI接RK3588 HDMI RX，执行10次：

```bash
for i in $(seq 1 10); do
    v4l2-ctl -d /dev/video40 --query-dv-timings
    sleep 1
done
```

3. 同时提供：

```bash
dmesg | grep -i -E 'hdmirx|signal|lock|avi|tmds' | tail -n 120
```

4. 回传以下材料：

```text
- 直接显示器照片或视频
- 10次query-dv-timings完整文本
- 内核日志
- ILA波形A、B、C
- 如有条件，TMDS时钟测量截图
```

## 结果判定

| 结果 | 结论 |
|---|---|
| 显示器和RK3588均不锁定 | 继续查PLL、TMDS串行化、管脚/电气信号 |
| 显示器稳定、RK3588不锁定 | 重点查RK3588容差、TMDS相位/信号质量和接收兼容性 |
| RK3588稳定识别1280×720，但报AVI缺失 | 基础TMDS链路通过，下一步恢复AVI InfoFrame/Data Island |
| 只偶尔锁定或几秒后掉锁 | 检查PLL掉锁、串行字边界、时钟中断和TMDS信号完整性 |

