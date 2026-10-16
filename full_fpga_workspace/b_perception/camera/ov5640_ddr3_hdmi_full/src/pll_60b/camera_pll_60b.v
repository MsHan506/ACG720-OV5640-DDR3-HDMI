// GW5AT-60B PLLA wrapper for standards-compliant 720p60 DVI.
// 50 MHz / 2 * 37.125 = 928.125 MHz VCO.
// CLKOUT0 = 928.125 / 2.5 = 371.25 MHz (5x pixel clock).
// CLKOUT1 = 928.125 / 37  = 25.084 MHz (OV5640 XCLK; within its valid range).
module camera_pll (clkout0, clkout1, lock, clkin);
    output clkout0;
    output clkout1;
    output lock;
    input  clkin;

    wire clkout2_unused, clkout3_unused, clkout4_unused;
    wire clkout5_unused, clkout6_unused, clkfbout_unused;
    wire [7:0] mdrdo_unused;
    wire gnd = 1'b0;

    PLLA pll_inst (
        .LOCK(lock),
        .CLKOUT0(clkout0), .CLKOUT1(clkout1),
        .CLKOUT2(clkout2_unused), .CLKOUT3(clkout3_unused),
        .CLKOUT4(clkout4_unused), .CLKOUT5(clkout5_unused),
        .CLKOUT6(clkout6_unused), .CLKFBOUT(clkfbout_unused),
        .MDRDO(mdrdo_unused), .CLKIN(clkin), .CLKFB(gnd),
        .RESET(gnd), .PLLPWD(gnd), .RESET_I(gnd), .RESET_O(gnd),
        .PSSEL(3'b000), .PSDIR(gnd), .PSPULSE(gnd),
        .SSCPOL(gnd), .SSCON(gnd), .SSCMDSEL(7'b0000000),
        .SSCMDSEL_FRAC(3'b000), .MDCLK(gnd), .MDOPC(2'b00),
        .MDAINC(gnd), .MDWDI(8'b00000000)
    );

    defparam pll_inst.FCLKIN = "50";
    defparam pll_inst.IDIV_SEL = 2;
    defparam pll_inst.FBDIV_SEL = 1;
    defparam pll_inst.CLKFB_SEL = "INTERNAL";
    defparam pll_inst.MDIV_SEL = 37;
    defparam pll_inst.MDIV_FRAC_SEL = 1;
    defparam pll_inst.ODIV0_SEL = 2;
    defparam pll_inst.ODIV0_FRAC_SEL = 4;
    defparam pll_inst.ODIV1_SEL = 37;
    defparam pll_inst.ODIV2_SEL = 8;
    defparam pll_inst.ODIV3_SEL = 8;
    defparam pll_inst.ODIV4_SEL = 8;
    defparam pll_inst.ODIV5_SEL = 8;
    defparam pll_inst.ODIV6_SEL = 8;
    defparam pll_inst.CLKOUT0_EN = "TRUE";
    defparam pll_inst.CLKOUT1_EN = "TRUE";
    defparam pll_inst.CLKOUT2_EN = "FALSE";
    defparam pll_inst.CLKOUT3_EN = "FALSE";
    defparam pll_inst.CLKOUT4_EN = "FALSE";
    defparam pll_inst.CLKOUT5_EN = "FALSE";
    defparam pll_inst.CLKOUT6_EN = "FALSE";
endmodule
