// True-HDMI diagnostic transmitter: standard CEA VIC 4 timing, fixed bars,
// data islands, TERC4, BCH ECC and an AVI InfoFrame once per video frame.
module true_hdmi_720p60_tx #(
    parameter bit DVI_OUTPUT = 1'b0
) (
    input  wire       pixel_clk,
    input  wire       serial_clk_x5,
    input  wire       reset,
    input  wire       use_test_pattern,
    input  wire [23:0] rgb_in,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire [10:0] debug_h_count,
    output wire [9:0]  debug_v_count,
    output wire        debug_hsync,
    output wire        debug_vsync,
    output wire        debug_de,
    output wire [2:0]  debug_mode
);
    logic [10:0] cx;
    logic [9:0] cy;
    logic [10:0] frame_width;
    logic [9:0] frame_height;
    logic [10:0] screen_width;
    logic [9:0] screen_height;
    logic [23:0] rgb;
    logic [15:0] silent_audio [1:0];
    logic [2:0] tmds_single;
    logic tmds_clock_single;

    always_comb begin
        silent_audio[0] = 16'd0;
        silent_audio[1] = 16'd0;
        if (!use_test_pattern)
            rgb = (cx < 11'd1280 && cy < 10'd720) ? rgb_in : 24'h000000;
        else if (cy >= 10'd720)
            rgb = 24'h000000;
        else if (cx < 11'd160) rgb = 24'hFFFFFF;
        else if (cx < 11'd320) rgb = 24'hFFFF00;
        else if (cx < 11'd480) rgb = 24'h00FFFF;
        else if (cx < 11'd640) rgb = 24'h00FF00;
        else if (cx < 11'd800) rgb = 24'hFF00FF;
        else if (cx < 11'd960) rgb = 24'hFF0000;
        else if (cx < 11'd1120) rgb = 24'h0000FF;
        else if (cx < 11'd1280) rgb = 24'h000000;
        else rgb = 24'h000000;
    end

    hdmi #(
        .VIDEO_ID_CODE(4),
        .IT_CONTENT(1'b0),
        .DVI_OUTPUT(DVI_OUTPUT),
        .VIDEO_REFRESH_RATE(60.0),
        .AUDIO_RATE(48000),
        .AUDIO_BIT_WIDTH(16),
        .VENDOR_NAME("OPENAI  "),
        .PRODUCT_DESCRIPTION("GW5AT HDMI TEST ")
    ) u_hdmi (
        .clk_pixel_x5(serial_clk_x5),
        .clk_pixel(pixel_clk),
        .clk_audio(pixel_clk),
        .reset(reset),
        .rgb(rgb),
        .audio_sample_word(silent_audio),
        .tmds(tmds_single),
        .tmds_clock(tmds_clock_single),
        .cx(cx), .cy(cy),
        .frame_width(frame_width), .frame_height(frame_height),
        .screen_width(screen_width), .screen_height(screen_height),
        .debug_hsync(debug_hsync), .debug_vsync(debug_vsync),
        .debug_de(debug_de), .debug_mode(debug_mode)
    );

    assign debug_h_count = cx;
    assign debug_v_count = cy;

    TLVDS_OBUF u_clk_buf (.I(tmds_clock_single), .O(tmds_clk_p), .OB(tmds_clk_n));
    genvar ch;
    generate
        for (ch = 0; ch < 3; ch = ch + 1) begin : g_tmds_buf
            TLVDS_OBUF u_data_buf (.I(tmds_single[ch]),
                                  .O(tmds_data_p[ch]),
                                  .OB(tmds_data_n[ch]));
        end
    endgenerate
endmodule

