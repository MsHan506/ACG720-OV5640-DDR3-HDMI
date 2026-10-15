// Minimal 1280x720p60 link test using Gowin's generated DVI_TX IP.
//
// This build deliberately contains no camera, DDR, frame buffer, overlays,
// motors, HDMI data islands or AVI InfoFrames.  It is used to distinguish a
// basic TMDS/clock/pin problem from a packet-capable HDMI-core problem.
module rk3588_gowin_dvi_link_test_top (
    input  wire       clk50M,
    input  wire       reset_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire [3:0] led
);
    wire serial_clk_x5;
    wire pixel_clk;
    wire pll_locked;

    // Exact CEA-861 720p60 clocks: 74.25 MHz pixel, 371.25 MHz DDR serial.
    camera_pll u_hdmi_pll (
        .clkout0(serial_clk_x5),
        .clkout1(),
        .lock(pll_locked),
        .clkin(clk50M)
    );

    CLKDIV u_pixel_clkdiv (
        .RESETN(1'b1),
        .HCLKIN(serial_clk_x5),
        .CLKOUT(pixel_clk),
        .CALIB(1'b1)
    );
    defparam u_pixel_clkdiv.DIV_MODE = "5";

    // Release the vendor TX only after the PLL has remained locked for about
    // 14 ms.  No camera or HPD signal can reset this free-running source.
    reg pll_lock_meta = 1'b0;
    reg pll_lock_sync = 1'b0;
    reg [19:0] lock_high_count = 20'd0;
    reg tx_enable = 1'b0;
    always @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            pll_lock_meta   <= 1'b0;
            pll_lock_sync   <= 1'b0;
            lock_high_count <= 20'd0;
            tx_enable       <= 1'b0;
        end else begin
            pll_lock_meta <= pll_locked;
            pll_lock_sync <= pll_lock_meta;
            if (!tx_enable) begin
                if (!pll_lock_sync)
                    lock_high_count <= 20'd0;
                else begin
                    lock_high_count <= lock_high_count + 1'b1;
                    if (&lock_high_count)
                        tx_enable <= 1'b1;
                end
            end
        end
    end

    // CEA VIC 4: 1280 active + 110 FP + 40 sync + 220 BP = 1650.
    //            720 active +   5 FP +  5 sync +  20 BP =  750.
    reg [10:0] h_count = 11'd0;
    reg [9:0]  v_count = 10'd0;
    always @(posedge pixel_clk) begin
        if (!tx_enable) begin
            h_count <= 11'd0;
            v_count <= 10'd0;
        end else if (h_count == 11'd1649) begin
            h_count <= 11'd0;
            if (v_count == 10'd749)
                v_count <= 10'd0;
            else
                v_count <= v_count + 1'b1;
        end else begin
            h_count <= h_count + 1'b1;
        end
    end

    wire video_de = (h_count < 11'd1280) && (v_count < 10'd720);
    wire video_hs = (h_count >= 11'd1390) && (h_count < 11'd1430);
    // Progressive VSYNC changes only at complete-line boundaries.  There is
    // no half-line offset and no alternating odd/even-field state.
    wire video_vs = (v_count >= 10'd725) && (v_count < 10'd730);

    reg [23:0] rgb;
    always @* begin
        if (!video_de)             rgb = 24'h000000;
        else if (h_count < 160)    rgb = 24'hFFFFFF;
        else if (h_count < 320)    rgb = 24'hFFFF00;
        else if (h_count < 480)    rgb = 24'h00FFFF;
        else if (h_count < 640)    rgb = 24'h00FF00;
        else if (h_count < 800)    rgb = 24'hFF00FF;
        else if (h_count < 960)    rgb = 24'hFF0000;
        else if (h_count < 1120)   rgb = 24'h0000FF;
        else                       rgb = 24'h000000;
    end

    DVI_TX_Top u_gowin_dvi_tx (
        // The vendor IP fans this signal directly into OSER10 RESET.  A
        // pixel-domain release creates an impossible recovery path to the
        // 371.25-MHz DDR serializer and made word alignment power-up
        // dependent.  Keep the local reset inactive and use device GSR for
        // deterministic initialization; the raster remains held at (0,0)
        // above until the PLL has been stable for the full qualification
        // interval.
        .I_rst_n(1'b1),
        .I_serial_clk(serial_clk_x5),
        .I_rgb_clk(pixel_clk),
        .I_rgb_vs(video_vs),
        .I_rgb_hs(video_hs),
        .I_rgb_de(video_de),
        .I_rgb_r(rgb[23:16]),
        .I_rgb_g(rgb[15:8]),
        .I_rgb_b(rgb[7:0]),
        .O_tmds_clk_p(tmds_clk_p),
        .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_data_p),
        .O_tmds_data_n(tmds_data_n)
    );

    reg [25:0] heartbeat = 26'd0;
    reg pll_drop_seen = 1'b0;
    always @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            heartbeat <= 26'd0;
            pll_drop_seen <= 1'b0;
        end else begin
            if (tx_enable)
                heartbeat <= heartbeat + 1'b1;
            if (tx_enable && !pll_lock_sync)
                pll_drop_seen <= 1'b1;
        end
    end

    assign led[0] = pll_locked;
    assign led[1] = tx_enable;
    assign led[2] = heartbeat[25];
    assign led[3] = pll_drop_seen;
endmodule
