open_project C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/ov5640_ddr3_hdmi.gprj
create_ipc -name ddr3 -module_name DDR3_Memory_Interface_Top -file_name ddr3_memory_interface_60b -dir C:/chatgpt/fpga/b_perception/camera/ov5640_ddr3_hdmi_full/src/ddr3_60b -force
set ip [get_ips DDR3_Memory_Interface_Top]
set_property -dict {
  CONFIG.User_Interface {Controller}
  CONFIG.Memory_Type {Components}
  CONFIG.Memory_Clock {200}
  CONFIG.CLK_Ratio {1:4}
  CONFIG.Dq_Width {16}
  CONFIG.Dram_Width {16}
  CONFIG.Ecc {false}
  CONFIG.Rank_Address {1}
  CONFIG.Bank_Address {3}
  CONFIG.Row_Address {14}
  CONFIG.Column_Address {10}
  CONFIG.SIM {false}
  CONFIG.Burst_Mode {8}
  CONFIG.Burst_Type {SEQ}
  CONFIG.CAS_Latency {5}
  CONFIG.CW_Latency {5}
  CONFIG.Additive_Latency {0}
  CONFIG.Wrire_Recovery {6}
  CONFIG.Rtt_Nom {40}
  CONFIG.Rtt_Wr {OFF}
  CONFIG.Addr_Cmd_Mode {1T}
  CONFIG.OUTPUT_DRV {LOW}
  CONFIG.User_Refresh {false}
  CONFIG.tRTP_Period {7500}
  CONFIG.tRP_Period {12500}
  CONFIG.tWTR_Period {7500}
  CONFIG.tRC_Period {55000}
  CONFIG.tRAS_Period {37500}
  CONFIG.tRCD_Period {12500}
  CONFIG.tFAW_Period {40000}
  CONFIG.tRRD_Period {7500}
  CONFIG.tCKE_Period {75000}
  CONFIG.tREFI_Period {7800000}
  CONFIG.tRFC_Period {160000}
  CONFIG.tDLLK {512}
  CONFIG.Debug_Parameter_Enable {false}
  CONFIG.Debug_Port_Enable {false}
} $ip
generate_target $ip
exit
