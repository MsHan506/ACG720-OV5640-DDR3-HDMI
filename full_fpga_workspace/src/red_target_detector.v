`timescale 1ns/1ps

// Frame-rate red-region detector.  Bounding-box centre avoids a costly divider
// and is adequate for left/centre/right tracking on FPGA fabric.
module red_target_detector #(
    parameter integer MIN_PIXELS = 600
)(
    input  wire pixel_clk,
    input  wire rst_n,
    input  wire frame_sync,
    input  wire pixel_valid,
    input  wire [11:0] pixel_x,
    input  wire [11:0] pixel_y,
    input  wire [7:0] red,
    input  wire [7:0] green,
    input  wire [7:0] blue,
    output reg target_valid,
    output reg [11:0] target_center_x,
    output reg [11:0] target_center_y,
    output reg [11:0] bbox_left,
    output reg [11:0] bbox_right,
    output reg [11:0] bbox_top,
    output reg [11:0] bbox_bottom,
    output reg [23:0] target_pixel_count,
    output reg frame_toggle
);
    reg frame_sync_d;
    reg [23:0] count_work;
    reg [11:0] min_x,max_x,min_y,max_y;
    reg red_sample;
    reg [11:0] sample_x,sample_y;
    wire new_frame = frame_sync && !frame_sync_d;
    // Extend each colour channel before adding the margin.  Keeping this at
    // nine bits prevents bright green/blue values from wrapping at 255 and
    // being misclassified as red.
    wire is_red = pixel_valid && red>=8'd140 &&
                  {1'b0,red}>{1'b0,green}+9'd35 &&
                  {1'b0,red}>{1'b0,blue}+9'd35;

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_sync_d<=0; count_work<=0;
            red_sample<=0; sample_x<=0; sample_y<=0;
            min_x<=12'hfff; min_y<=12'hfff; max_x<=0; max_y<=0;
            target_valid<=0; target_center_x<=0; target_center_y<=0;
            bbox_left<=0; bbox_right<=0; bbox_top<=0; bbox_bottom<=0;
            target_pixel_count<=0; frame_toggle<=0;
        end else begin
            frame_sync_d<=frame_sync;
            red_sample<=is_red;
            sample_x<=pixel_x;
            sample_y<=pixel_y;
            if (new_frame) begin
                target_valid<=count_work>=MIN_PIXELS;
                target_pixel_count<=count_work;
                if (count_work>=MIN_PIXELS) begin
                    bbox_left<=min_x; bbox_right<=max_x;
                    bbox_top<=min_y; bbox_bottom<=max_y;
                    target_center_x<=(min_x+max_x)>>1;
                    target_center_y<=(min_y+max_y)>>1;
                end
                frame_toggle<=~frame_toggle;
                count_work<=0;
                min_x<=12'hfff; min_y<=12'hfff; max_x<=0; max_y<=0;
            end else if (red_sample) begin
                count_work<=count_work+1'b1;
                if (sample_x<min_x) min_x<=sample_x;
                if (sample_x>max_x) max_x<=sample_x;
                if (sample_y<min_y) min_y<=sample_y;
                if (sample_y>max_y) max_y<=sample_y;
            end
        end
    end
endmodule

