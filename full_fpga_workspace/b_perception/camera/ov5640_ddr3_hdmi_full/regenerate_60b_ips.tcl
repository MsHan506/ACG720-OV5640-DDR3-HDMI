open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj

foreach {ipc module_name} {
  C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/camera_pll/camera_pll.ipc camera_pll
  C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/gowin_pll/gowin_pll.ipc Gowin_PLL
  C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/rd_data_fifo/rd_data_fifo.ipc rd_data_fifo
  C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/wr_data_fifo/wr_data_fifo.ipc wr_data_fifo
  C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/ddr3_memory_interface/ddr3_memory_interface.ipc DDR3_Memory_Interface_Top
  C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/dvi_tx/dvi_tx.ipc DVI_TX_Top
} {
  puts "Regenerating $module_name"
  read_ipc $ipc
  generate_target [get_ips $module_name] -force
}
exit
