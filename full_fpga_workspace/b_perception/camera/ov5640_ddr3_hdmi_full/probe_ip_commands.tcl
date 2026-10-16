open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
foreach cmd {create_ipc read_ipc get_ips write_ip_tcl} {
  puts "=== $cmd ==="
  if {[catch {$cmd} msg]} {puts $msg} else {puts $msg}
}
exit
