// Video-only HDMI packet selector for the RK3588 lock diagnostic build.
// Sends one CEA-861 AVI InfoFrame per video frame and Null Packets for all
// remaining packet slots. Audio packets are intentionally disabled.
module packet_picker #(
    parameter int VIDEO_ID_CODE = 4,
    parameter real VIDEO_RATE = 0,
    parameter bit IT_CONTENT = 1'b0,
    parameter int AUDIO_BIT_WIDTH = 16,
    parameter int AUDIO_RATE = 48000,
    parameter bit [8*8-1:0] VENDOR_NAME = 0,
    parameter bit [8*16-1:0] PRODUCT_DESCRIPTION = 0,
    parameter bit [7:0] SOURCE_DEVICE_INFORMATION = 0
) (
    input  logic clk_pixel,
    input  logic clk_audio,
    input  logic reset,
    input  logic video_field_end,
    input  logic packet_enable,
    input  logic [4:0] packet_pixel_counter,
    input  logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word [1:0],
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
    logic [23:0] avi_header;
    logic [55:0] avi_sub [3:0];
    logic avi_sent;
    logic select_avi;

    // RGB, 16:9 picture aspect ratio, VIC 4 (1280x720p60), no repetition.
    auxiliary_video_information_info_frame #(
        .VIDEO_FORMAT(2'b00),
        .PICTURE_ASPECT_RATIO(2'b10),
        .IT_CONTENT(IT_CONTENT),
        .VIDEO_ID_CODE(VIDEO_ID_CODE),
        .PIXEL_REPETITION(4'b0000)
    ) u_avi (
        .header(avi_header),
        .sub(avi_sub)
    );

    always_ff @(posedge clk_pixel) begin
        if (reset || video_field_end) begin
            avi_sent <= 1'b0;
            select_avi <= 1'b0;
        end else if (packet_enable) begin
            select_avi <= !avi_sent;
            if (!avi_sent)
                avi_sent <= 1'b1;
        end
    end

    always_comb begin
        if (select_avi) begin
            header = avi_header;
            sub[0] = avi_sub[0];
            sub[1] = avi_sub[1];
            sub[2] = avi_sub[2];
            sub[3] = avi_sub[3];
        end else begin
            // HDMI Null Packet: HB0=0; sink ignores HB1/HB2 and packet body.
            header = 24'h000000;
            sub[0] = 56'h00000000000000;
            sub[1] = 56'h00000000000000;
            sub[2] = 56'h00000000000000;
            sub[3] = 56'h00000000000000;
        end
    end

endmodule
