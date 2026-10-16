# ACG720-GW5AT60 LED 冒烟测试

用途：第一次上板时，仅验证 FPGA 下载和板载 LED2，不连接小车电池、电机驱动或传感器。

- 器件：`GW5AT-LV60PG484AC1/I0`（`GW5AT-60B`）
- 下载方式：仅使用 SRAM 临时下载
- 时钟：板载 50 MHz，`Y18`
- LED2：`L21`（60B 的 `M22/N22` 是 SSPI 专用配置脚，首次测试不占用）
- 预期现象：LED2 持续闪烁；开发板断电后恢复原有 Flash 程序

禁止在首次测试中选择外部 Flash 擦除或烧写操作。

## 实测记录

- 日期：2026-09-30
- 板卡：小梅哥 ACG720-GW5AT60
- Programmer 识别：`GW5AT-60B`
- 下载方式：`SRAM Mode` / `SRAM Program`
- 结果：Programmer 显示 `Finished.`，板载 D2 持续闪烁
- 断电重启：原有数码管演示程序恢复，证明本次未改写外部 Flash
