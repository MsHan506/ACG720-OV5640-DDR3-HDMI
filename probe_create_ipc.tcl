open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
foreach args {{-name foo} {-name foo -type ddr3} {-name foo -module_name foo} {-name foo -dir .}} {
  puts "=== $args ==="
  if {[catch {eval create_ipc $args} msg]} {puts $msg} else {puts $msg}
}
exit
