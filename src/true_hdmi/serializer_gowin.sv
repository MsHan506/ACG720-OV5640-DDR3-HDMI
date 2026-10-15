// Gowin GW5A 10:1 TMDS serializer. Input words are transmitted bit 0 first.
module serializer #(
    parameter int NUM_CHANNELS = 3,
    parameter real VIDEO_RATE = 74.25E6
) (
    input  logic clk_pixel,
    input  logic clk_pixel_x5,
    input  logic reset,
    input  logic [9:0] tmds_internal [NUM_CHANNELS-1:0],
    output logic [2:0] tmds,
    output logic tmds_clock
);
    // Earlier routed candidates violated OSER10 local-reset recovery at
    // 371.25 MHz; this implementation uses configuration-time GSR instead.
    // The companion CLKDIV is therefore also started by device
    // GSR (not released later by PLL LOCK), so its /5 phase and all OSER10
    // word counters begin together at configuration.  Upstream HDMI state is
    // still held in reset until PLL LOCK has been stable.
    wire oser_reset = 1'b0;

    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i = i + 1) begin : g_oser10
            OSER10 u_oser10 (
                .Q(tmds[i]),
                .D0(tmds_internal[i][0]), .D1(tmds_internal[i][1]),
                .D2(tmds_internal[i][2]), .D3(tmds_internal[i][3]),
                .D4(tmds_internal[i][4]), .D5(tmds_internal[i][5]),
                .D6(tmds_internal[i][6]), .D7(tmds_internal[i][7]),
                .D8(tmds_internal[i][8]), .D9(tmds_internal[i][9]),
                .PCLK(clk_pixel), .FCLK(clk_pixel_x5), .RESET(oser_reset)
            );
        end
    endgenerate

    // Serialize the forwarded clock through the same OSER10 resources as the
    // data channels.  Match the bit order used by Gowin's DVI_TX IP that was
    // verified on this exact board: D0..D4=0, D5..D9=1.  Reversing this word
    // shifts the forwarded clock by half a pixel relative to all data lanes.
    OSER10 u_clock_oser10 (
        .Q(tmds_clock),
        .D0(1'b0), .D1(1'b0), .D2(1'b0), .D3(1'b0), .D4(1'b0),
        .D5(1'b1), .D6(1'b1), .D7(1'b1), .D8(1'b1), .D9(1'b1),
        .PCLK(clk_pixel), .FCLK(clk_pixel_x5), .RESET(oser_reset)
    );
endmodule
