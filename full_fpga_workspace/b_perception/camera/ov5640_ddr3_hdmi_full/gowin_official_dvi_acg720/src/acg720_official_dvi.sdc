// Official reference constraint: 50 MHz board input.
create_clock -name I_clk -period 20.000 -waveform {0 10} [get_ports {I_clk}] -add

// GW5AT board-port STA additions.  These describe, but do not alter, the
// official reference's 371.25 MHz serial and /5 74.25 MHz pixel clocks.
create_generated_clock -name serial_clk -source [get_ports {I_clk}] -multiply_by 297 -divide_by 40 [get_pins {u_tmds_pll/pll_inst/CLKOUT0}]
create_generated_clock -name pix_clk -source [get_pins {u_tmds_pll/pll_inst/CLKOUT0}] -edges {1 7 11} [get_pins {u_clkdiv/CLKOUT}]
