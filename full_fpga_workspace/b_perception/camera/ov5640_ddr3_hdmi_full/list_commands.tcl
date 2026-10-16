open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
puts "read_ipc"
if {[catch {read_ipc C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/camera_pll/camera_pll.ipc} msg]} {puts $msg} else {puts $msg}
puts "get_ips"
foreach args {{} {*} {camera_pll}} {
  if {[catch {eval get_ips $args} msg]} {puts $msg} else {puts $msg}
}
exit
