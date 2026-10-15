create_clock -name clk50M -period 20.000 [get_ports {clk50M}]
# PLLA: 50 MHz * 297/40 = 371.25 MHz. Preserve its source relationship.
create_generated_clock -name serial_clk_x5 -source [get_ports {clk50M}] -multiply_by 297 -divide_by 40 [get_pins {u_hdmi_pll/pll_inst/CLKOUT0}]
# CLKDIV /5 functional model: rise at FCLK edge 1, fall after 3 cycles,
# next rise after 5 cycles (60/40 duty). Do not declare an unrelated base clock.
create_generated_clock -name pixel_clk -source [get_pins {u_hdmi_pll/pll_inst/CLKOUT0}] -edges {1 7 11} [get_pins {u_pixel_clkdiv/CLKOUT}]

# Intentional CDC into the first stage of the 50 MHz diagnostic synchronizer.
# The second stage remains fully timed.
set_false_path -to [get_pins {tx_enable_meta_50_s1/D}]
