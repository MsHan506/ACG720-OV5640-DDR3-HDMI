create_clock -name clk50M -period 20.000 [get_ports {clk50M}]
create_generated_clock -name serial_clk_x5 -source [get_ports {clk50M}] -multiply_by 297 -divide_by 40 [get_pins {u_hdmi_pll/pll_inst/CLKOUT0}]
create_generated_clock -name pixel_clk -source [get_pins {u_hdmi_pll/pll_inst/CLKOUT0}] -edges {1 7 11} [get_pins {u_pixel_clkdiv/CLKOUT}]
