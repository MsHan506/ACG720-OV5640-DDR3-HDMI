open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
read_ipc C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ip_probe/probe_ddr3/probe_ddr3.ipc
set ip [get_ips probe_ddr3]
puts "LIST"
puts [list_property $ip]
puts "REPORT"
puts [report_property $ip]
exit
