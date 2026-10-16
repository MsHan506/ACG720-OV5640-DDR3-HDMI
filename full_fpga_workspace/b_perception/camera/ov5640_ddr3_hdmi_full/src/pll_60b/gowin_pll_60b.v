// GW5AT-60B PLLA wrapper: 50 MHz -> 200 MHz and 50 MHz.
// DDR3 IPUG281 requires memory_clk on CLKOUT2 for GW5A devices.  PLLA has
// no ENCLK2 pin, so expose its mDRP interface for the vendor pll_stop adapter.
module Gowin_PLL (
    lock, clkout0, clkout1, clkout2, mdrdo,
    clkin, reset, mdclk, mdopc, mdainc, mdwdi
);
    output lock;
    output clkout0;
    output clkout1;
    output clkout2;
    output [7:0] mdrdo;
    input  clkin;
    input  reset;
    input mdclk;
    input [1:0] mdopc;
    input mdainc;
    input [7:0] mdwdi;

    wire clkout3_unused, clkout4_unused;
    wire clkout5_unused, clkout6_unused, clkfbout_unused;
    wire gnd = 1'b0;

    PLLA pll_inst (
        .LOCK(lock),
        .CLKOUT0(clkout0), .CLKOUT1(clkout1),
        .CLKOUT2(clkout2), .CLKOUT3(clkout3_unused),
        .CLKOUT4(clkout4_unused), .CLKOUT5(clkout5_unused),
        .CLKOUT6(clkout6_unused), .CLKFBOUT(clkfbout_unused),
        .MDRDO(mdrdo), .CLKIN(clkin), .CLKFB(gnd),
        .RESET(reset), .PLLPWD(gnd), .RESET_I(gnd), .RESET_O(gnd),
        .PSSEL(3'b000), .PSDIR(gnd), .PSPULSE(gnd),
        .SSCPOL(gnd), .SSCON(gnd), .SSCMDSEL(7'b0000000),
        .SSCMDSEL_FRAC(3'b000), .MDCLK(mdclk), .MDOPC(mdopc),
        .MDAINC(mdainc), .MDWDI(mdwdi)
    );

    defparam pll_inst.FCLKIN = "50";
    defparam pll_inst.IDIV_SEL = 1;
    defparam pll_inst.FBDIV_SEL = 1;
    defparam pll_inst.CLKFB_SEL = "INTERNAL";
    defparam pll_inst.MDIV_SEL = 16;
    defparam pll_inst.MDIV_FRAC_SEL = 0;
    defparam pll_inst.ODIV0_SEL = 4;
    defparam pll_inst.ODIV0_FRAC_SEL = 0;
    defparam pll_inst.ODIV1_SEL = 16;
    defparam pll_inst.ODIV2_SEL = 4;
    defparam pll_inst.ODIV3_SEL = 8;
    defparam pll_inst.ODIV4_SEL = 8;
    defparam pll_inst.ODIV5_SEL = 8;
    defparam pll_inst.ODIV6_SEL = 8;
    defparam pll_inst.CLKOUT0_EN = "FALSE";
    defparam pll_inst.CLKOUT1_EN = "TRUE";
    defparam pll_inst.CLKOUT2_EN = "TRUE";
    defparam pll_inst.CLKOUT3_EN = "FALSE";
    defparam pll_inst.CLKOUT4_EN = "FALSE";
    defparam pll_inst.CLKOUT5_EN = "FALSE";
    defparam pll_inst.CLKOUT6_EN = "FALSE";
endmodule
