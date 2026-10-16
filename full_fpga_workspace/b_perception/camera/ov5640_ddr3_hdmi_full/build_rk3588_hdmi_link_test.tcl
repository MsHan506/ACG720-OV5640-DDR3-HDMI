open_project ./rk3588_hdmi_link_test.gprj
set_option -verilog_std sysv2017
set_option -top_module rk3588_hdmi_link_test_top
set_option -output_base_name rk3588_hdmi_link_test_720p60
set_option -use_sspi_as_gpio 1
run all
