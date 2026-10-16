`timescale 1ns/1ps

module target_box_overlay(
    input wire pixel_clk,
    input wire rst_n,
    input wire target_valid,
    input wire [11:0] bbox_left,bbox_right,bbox_top,bbox_bottom,
    input wire [11:0] pixel_x,pixel_y,
    input wire video_de,
    input wire hsync_in,vsync_in,
    input wire [7:0] red_in,green_in,blue_in,
    output reg video_de_out,hsync_out,vsync_out,
    output reg [7:0] red_out,green_out,blue_out
);
    wire on_vertical = (pixel_x>=bbox_left && pixel_x<=bbox_left+2) ||
                       (pixel_x<=bbox_right && pixel_x+2>=bbox_right);
    wire on_horizontal = (pixel_y>=bbox_top && pixel_y<=bbox_top+2) ||
                         (pixel_y<=bbox_bottom && pixel_y+2>=bbox_bottom);
    wire in_y = pixel_y>=bbox_top && pixel_y<=bbox_bottom;
    wire in_x = pixel_x>=bbox_left && pixel_x<=bbox_right;
    wire box_pixel = target_valid && video_de &&
                     ((on_vertical&&in_y)||(on_horizontal&&in_x));
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            red_out<=0; green_out<=0; blue_out<=0;
            video_de_out<=0; hsync_out<=0; vsync_out<=0;
        end else begin
            red_out<=box_pixel?8'hff:red_in;
            green_out<=box_pixel?8'hff:green_in;
            blue_out<=box_pixel?8'h00:blue_in;
            video_de_out<=video_de;
            hsync_out<=hsync_in;
            vsync_out<=vsync_in;
        end
    end
endmodule

