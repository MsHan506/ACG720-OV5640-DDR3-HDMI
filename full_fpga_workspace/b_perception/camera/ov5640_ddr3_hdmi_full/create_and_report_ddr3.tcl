open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
create_ipc -name ddr3 -module_name ddr3_60b_new -dir C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ip_new -force
set ip [get_ips ddr3_60b_new]
puts "IP=$ip"
puts "LIST=[list_property $ip]"
puts "REPORT=[report_property $ip]"
exit
