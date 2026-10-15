open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
foreach name {ddr3 DDR3 ddr3_memory_interface DDR3_Memory_Interface DDR3_Memory_Interface_Top memory_interface Memory_Interface} {
  puts "=== $name ==="
  if {[catch {create_ipc -name $name -module_name probe_$name -dir C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ip_probe -force} msg]} {puts $msg} else {puts $msg}
}
exit
