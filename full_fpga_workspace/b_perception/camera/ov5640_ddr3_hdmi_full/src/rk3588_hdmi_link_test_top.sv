// Minimal RK3588 HDMI-RX link test for ACG720-GW5AT60.
//
// This top intentionally contains no camera, DDR, frame buffer, motor or
// sensor logic.  Its timing generator is free-running and its pixel source is
// an internal fixed colour-bar pattern.
module rk3588_hdmi_link_test_top #(
    parameter bit CUSTOM_DVI_OUTPUT = 1'b0
) (
    input  wire       clk50M,
    input  wire       reset_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire [3:0] led
);
    (* syn_keep = 1 *) wire serial_clk_x5;
    (* syn_keep = 1 *) wire pixel_clk;
    (* syn_keep = 1 *) wire pll_locked;

    // One PLL only: do not cascade the HDMI PLL behind the system/DDR PLL.
    // 50 MHz -> 371.25 MHz, then the dedicated CLKDIV generates 74.25 MHz.
    camera_pll u_hdmi_pll (
        .clkout0(serial_clk_x5),
        .clkout1(),
        .lock(pll_locked),
        .clkin(clk50M)
    );

    CLKDIV u_pixel_clkdiv (
        // Start the /5 divider together with the OSER10 counters at device
        // configuration.  Resetting only CLKDIV after FCLK has started makes
        // the TMDS 10-bit word phase power-cycle dependent.
        .RESETN(1'b1),
        .HCLKIN(serial_clk_x5),
        .CLKOUT(pixel_clk),
        .CALIB(1'b1)
    );
    defparam u_pixel_clkdiv.DIV_MODE = "5";

    // Synchronize LOCK into the pixel domain and require about 14 ms of
    // continuous lock before starting TX.  There is deliberately no HPD in
    // this build because the board's verified 60B constraints expose no HPD
    // FPGA pin.  Consequently an HPD glitch cannot reset this transmitter.
    (* syn_keep = 1 *) reg pll_lock_meta = 1'b0;
    (* syn_keep = 1 *) reg pll_lock_sync = 1'b0;
    (* syn_keep = 1 *) reg [19:0] lock_high_count = 20'd0;
    (* syn_keep = 1 *) reg tx_enable = 1'b0;
    always @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            pll_lock_meta  <= 1'b0;
            pll_lock_sync  <= 1'b0;
            lock_high_count <= 20'd0;
            tx_enable      <= 1'b0;
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

    (* syn_keep = 1 *) wire tx_reset = !tx_enable;
    (* syn_keep = 1 *) wire [10:0] h_count;
    (* syn_keep = 1 *) wire [9:0]  v_count;
    (* syn_keep = 1 *) wire hsync;
    (* syn_keep = 1 *) wire vsync;
    (* syn_keep = 1 *) wire de;
    (* syn_keep = 1 *) wire [2:0] hdmi_mode;

    true_hdmi_720p60_tx #(
        .DVI_OUTPUT(CUSTOM_DVI_OUTPUT)
    ) u_tx (
        .pixel_clk(pixel_clk),
        .serial_clk_x5(serial_clk_x5),
        .reset(tx_reset),
        .use_test_pattern(1'b1),
        .rgb_in(24'h000000),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p),
        .tmds_data_n(tmds_data_n),
        .debug_h_count(h_count),
        .debug_v_count(v_count),
        .debug_hsync(hsync),
        .debug_vsync(vsync),
        .debug_de(de),
        .debug_mode(hdmi_mode)
    );

    // Board-visible diagnostics. LED polarity is intentionally unchanged
    // from the vendor examples; transitions matter more than lit polarity.
    reg [25:0] heartbeat = 26'd0;
    always @(posedge pixel_clk)
        if (tx_enable)
            heartbeat <= heartbeat + 1'b1;
        else
            heartbeat <= 26'd0;

    // A 60-second full-rate ILA capture would require impractical on-chip
    // memory.  Record any post-start PLL unlock as a sticky hardware fault so
    // a short Analyzer capture and an LED inspection can still cover a long
    // soak test without losing a transient event.
    (* syn_keep = 1 *) reg tx_enable_meta_50 = 1'b0;
    (* syn_keep = 1 *) reg tx_enable_sync_50 = 1'b0;
    (* syn_keep = 1 *) reg pll_lock_meta_50 = 1'b0;
    (* syn_keep = 1 *) reg pll_lock_sync_50 = 1'b0;
    (* syn_keep = 1 *) reg pll_drop_seen = 1'b0;
    always @(posedge clk50M or negedge reset_n) begin
        if (!reset_n) begin
            tx_enable_meta_50 <= 1'b0;
            tx_enable_sync_50 <= 1'b0;
            pll_lock_meta_50 <= 1'b0;
            pll_lock_sync_50 <= 1'b0;
            pll_drop_seen <= 1'b0;
        end else begin
            tx_enable_meta_50 <= tx_enable;
            tx_enable_sync_50 <= tx_enable_meta_50;
            pll_lock_meta_50 <= pll_locked;
            pll_lock_sync_50 <= pll_lock_meta_50;
            if (tx_enable_sync_50 && !pll_lock_sync_50)
                pll_drop_seen <= 1'b1;
        end
    end

    assign led[0] = pll_locked;
    assign led[1] = tx_enable;
    assign led[2] = heartbeat[25];
    assign led[3] = pll_drop_seen;
endmodule
