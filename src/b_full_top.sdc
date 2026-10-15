create_clock -name clk50M -period 20.000 [get_ports {clk50M}]
# Camera PCLK: conservative design limit, NOT a measurement of the camera.
create_clock -name camera_pclk -period 10.000 [get_ports {camera_pclk}]
# Explicit HDMI and DDR clock families.
create_generated_clock -name hdmi_serial_x5 -source [get_ports {clk50M}] -multiply_by 297 -divide_by 40 [get_pins {u_camera_display/camera_pll/pll_inst/CLKOUT0}]
create_generated_clock -name hdmi_pixel -source [get_pins {u_camera_display/camera_pll/pll_inst/CLKOUT0}] -edges {1 7 11} [get_pins {u_camera_display/u_clkdiv/CLKOUT}]
create_generated_clock -name ddr_memory -source [get_ports {clk50M}] -multiply_by 4 [get_pins {u_camera_display/Gowin_PLL/pll_inst/CLKOUT2}]
create_generated_clock -name ddr_reference -source [get_ports {clk50M}] -divide_by 1 [get_pins {u_camera_display/Gowin_PLL/pll_inst/CLKOUT1}]
create_generated_clock -name ddr_ui -source [get_pins {u_camera_display/Gowin_PLL/pll_inst/CLKOUT2}] -divide_by 4 [get_pins {u_camera_display/ddr3_ctrl_2port/DDR3_Memory_Interface_Top/gw3_top/u_ddr_phy_top/fclkdiv/CLKOUT}]

# Gowin's DDR3 1:4 reference design declares the continuous reference clock,
# HCLK memory clock and divided UI clock asynchronous.  Their crossings are
# implemented inside the vendor PHY/controller or by the explicit FIFOs and
# synchronizers below; treating their edges as phase-related creates false
# setup/hold/recovery failures inside the encrypted PHY.
set_clock_groups -asynchronous -group [get_clocks {clk50M}] -group [get_clocks {ddr_memory}]
set_clock_groups -asynchronous -group [get_clocks {clk50M}] -group [get_clocks {ddr_ui}]
set_clock_groups -asynchronous -group [get_clocks {ddr_memory}] -group [get_clocks {ddr_ui}]

# Only single-bit synchronizer FIRST-STAGE D pins are asynchronous exceptions.
# The second-stage paths remain timed. Bus paths remain bounded below.
set_false_path -to [get_pins {u_camera_display/u_sensor_osd/osd_ack_meta_s0/D u_camera_display/u_sensor_osd/osd_request_meta_s0/D}]
set_false_path -to [get_pins {u_camera_display/u_target_cdc/ack_meta_s0/D u_camera_display/u_target_cdc/request_meta_s0/D}]
set_false_path -to [get_pins {u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/rd_load_d0_s0/D u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/wr_load_d0_s0/D}]

# Mailbox bundled buses settle within 20 ns; hold until synchronized ACK.
# Cut only synchronous hold checks (no coincident-edge relationship for CDC).
set_max_delay -from [get_pins {u_camera_display/u_sensor_osd/osd_mailbox_*/Q}] 20.000
set_false_path -hold -from [get_pins {u_camera_display/u_sensor_osd/osd_mailbox_*/Q}]
set_max_delay -from [get_pins {u_camera_display/u_target_cdc/held_data_*/Q}] 20.000
set_false_path -hold -from [get_pins {u_camera_display/u_target_cdc/held_data_*/Q}]

# Vendor FIFO .vo: Gray pointers feed q1 -> q2. Bound each CDC bus below
# the shortest source period (10 ns camera, 13.468 ns HDMI, 20 ns DDR).
set_max_delay -to [get_pins {u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/wr_data_fifo/fifo_inst/Big.wq1_rptr_*/D u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/wr_data_fifo/fifo_inst/Big.rq1_wptr_*/D}] 9.000
set_false_path -hold -to [get_pins {u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/wr_data_fifo/fifo_inst/Big.wq1_rptr_*/D u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/wr_data_fifo/fifo_inst/Big.rq1_wptr_*/D}]
set_max_delay -to [get_pins {u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/rd_data_fifo/fifo_inst/Small.wq1_rptr_*/D u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/rd_data_fifo/fifo_inst/Small.rq1_wptr_*/D}] 9.000
set_false_path -hold -to [get_pins {u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/rd_data_fifo/fifo_inst/Small.wq1_rptr_*/D u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/rd_data_fifo/fifo_inst/Small.rq1_wptr_*/D}]

# Vendor DDR reset request: recalib_s[0] feeds ONLY recalib_s[1].
set_false_path -to [get_pins {u_camera_display/ddr3_ctrl_2port/DDR3_Memory_Interface_Top/gw3_top/u_ddr_phy_top/ddr_sync/recalib_s_0_s0/D}]
report_timing -setup -max_paths 300
report_timing -hold -max_paths 100
report_timing -recovery -max_paths 100
report_timing -removal -max_paths 100
# Vendor FIFO reset_r/reset_w are asynchronous-assert, synchronous-release
# two-stage chains. Only their PRESET inputs are exempt; the released reset
# paths to actual FIFO state/Gray pointer registers still undergo STA.
set_false_path -to [get_pins {u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/rd_data_fifo/fifo_inst/reset_r_*_s0/PRESET u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/rd_data_fifo/fifo_inst/reset_w_*_s0/PRESET}]
set_false_path -to [get_pins {u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/wr_data_fifo/fifo_inst/reset_r_*_s0/PRESET u_camera_display/ddr3_ctrl_2port/fifo_ddr3_adapter/wr_data_fifo/fifo_inst/reset_w_*_s0/PRESET}]
