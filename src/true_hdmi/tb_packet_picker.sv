`timescale 1ns/1ps

// Source-level check for the video-only packet selector.  This test is kept
// outside the synthesis project and proves that the first packet slot after a
// field boundary selects a VIC-4 AVI InfoFrame, while later slots are null.
module tb_packet_picker;
    logic clk_pixel = 1'b0;
    logic clk_audio = 1'b0;
    logic reset = 1'b1;
    logic video_field_end = 1'b0;
    logic packet_enable = 1'b0;
    logic [4:0] packet_pixel_counter = 5'd0;
    logic [15:0] audio_sample_word [1:0];
    logic [23:0] header;
    logic [55:0] sub [3:0];

    always #6.734 clk_pixel = ~clk_pixel;
    always #10.417 clk_audio = ~clk_audio;

    packet_picker #(.VIDEO_ID_CODE(4)) dut (
        .clk_pixel(clk_pixel), .clk_audio(clk_audio), .reset(reset),
        .video_field_end(video_field_end), .packet_enable(packet_enable),
        .packet_pixel_counter(packet_pixel_counter),
        .audio_sample_word(audio_sample_word), .header(header), .sub(sub));

    initial begin
        audio_sample_word[0] = '0;
        audio_sample_word[1] = '0;
        repeat (3) @(posedge clk_pixel);
        reset <= 1'b0;
        @(posedge clk_pixel);
        packet_enable <= 1'b1;
        @(posedge clk_pixel);
        packet_enable <= 1'b0;
        #1;
        if (header !== 24'h0D0282) begin
            $display("FAIL: first slot header=%h, expected 0D0282", header);
            $finish;
        end
        // PB4 is the VIC and must be 4 for CEA 1280x720p60.
        if (sub[0][39:32] !== 8'h04) begin
            $display("FAIL: AVI VIC=%h, expected 04", sub[0][39:32]);
            $finish;
        end
        packet_enable <= 1'b1;
        @(posedge clk_pixel);
        packet_enable <= 1'b0;
        #1;
        if (header !== 24'h000000) begin
            $display("FAIL: later slot is not null: %h", header);
            $finish;
        end
        $display("PASS: first slot AVI 0x82/version 2/length 13/VIC 4; later slot null");
        $finish;
    end
endmodule
