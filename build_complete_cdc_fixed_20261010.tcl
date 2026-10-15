open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
set_option -verilog_std sysv2017
set_option -top_module b_full_top
set_option -output_base_name b_full_cdc_fixed_20261010
set_option -use_sspi_as_gpio 1
set_option -correct_hold_violation 1
set_option -timing_driven 1
set_option -route_option 1
run all
