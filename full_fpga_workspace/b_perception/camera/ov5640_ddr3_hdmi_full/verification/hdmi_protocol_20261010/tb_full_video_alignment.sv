`timescale 1ns/1ps

// Checks the complete registered video path that feeds true_hdmi_720p60_tx.
// The HDMI core generates its own raster, so its active interval must match
// the delayed DE accompanying boxed_video_* at the core input.
module tb_full_video_alignment;
  reg pixel_clk = 0;
  always #6.734 pixel_clk = ~pixel_clk;

  reg stream_reset_n = 0;
  reg [4:0] hdmi_start_delay = 0;
  wire hdmi_reset = !hdmi_start_delay[4];

  wire data_req;
  wire [11:0] pixel_x, pixel_y;
  wire video_hs, video_vs, video_de;
  wire [7:0] video_r, video_g, video_b;
  wire osd_hs, osd_vs, osd_de;
  wire [7:0] osd_r, osd_g, osd_b;
  wire boxed_hs, boxed_vs, boxed_de;
  wire [7:0] boxed_r, boxed_g, boxed_b;

  logic [10:0] hdmi_x = 0;
  logic [9:0] hdmi_y = 0;
  integer checked = 0;
  integer failures = 0;

  disp_driver u_disp (
    .ClkDisp(pixel_clk), .Rst_n(stream_reset_n), .Data(24'h5aa55a),
    .DataReq(data_req), .H_Addr(pixel_x), .V_Addr(pixel_y),
    .Disp_HS(video_hs), .Disp_VS(video_vs), .Disp_Red(video_r),
    .Disp_Green(video_g), .Disp_Blue(video_b), .Frame_Begin(),
    .Disp_DE(video_de), .Disp_PCLK()
  );

  sensor_osd_overlay u_osd (
    .data_clk(pixel_clk), .data_rst_n(stream_reset_n),
    .pixel_clk(pixel_clk), .video_de(video_de), .hsync_in(video_hs),
    .vsync_in(video_vs), .pixel_x(pixel_x), .pixel_y(pixel_y),
    .red_in(video_r), .green_in(video_g), .blue_in(video_b),
    .distance_mm(16'd0), .roll_cdeg(16'sd0), .pitch_cdeg(16'sd0),
    .yaw_cdeg(16'sd0), .drive_unlocked(1'b0), .motion_state(2'd0),
    .show_encoder_counts(1'b0), .left_rpm(32'sd0), .right_rpm(32'sd0),
    .red_out(osd_r), .green_out(osd_g), .blue_out(osd_b),
    .video_de_out(osd_de), .hsync_out(osd_hs), .vsync_out(osd_vs)
  );

  target_box_overlay u_box (
    .pixel_clk(pixel_clk), .rst_n(stream_reset_n), .target_valid(1'b0),
    .bbox_left(12'd0), .bbox_right(12'd0), .bbox_top(12'd0),
    .bbox_bottom(12'd0), .pixel_x(pixel_x), .pixel_y(pixel_y),
    .video_de(osd_de), .hsync_in(osd_hs), .vsync_in(osd_vs),
    .red_in(osd_r), .green_in(osd_g), .blue_in(osd_b),
    .video_de_out(boxed_de), .hsync_out(boxed_hs), .vsync_out(boxed_vs),
    .red_out(boxed_r), .green_out(boxed_g), .blue_out(boxed_b)
  );

  always @(posedge pixel_clk or negedge stream_reset_n) begin
    if (!stream_reset_n)
      hdmi_start_delay <= 0;
    else
      hdmi_start_delay <= {hdmi_start_delay[3:0], 1'b1};
  end

  always @(posedge pixel_clk) begin
    if (hdmi_reset) begin
      hdmi_x <= 0;
      hdmi_y <= 0;
    end else begin
      hdmi_x <= hdmi_x == 1649 ? 0 : hdmi_x + 1'b1;
      if (hdmi_x == 1649)
        hdmi_y <= hdmi_y == 749 ? 0 : hdmi_y + 1'b1;
    end

    #0.001;
    if (!hdmi_reset && hdmi_y < 2) begin
      checked = checked + 1;
      if (boxed_de !== ((hdmi_x < 1280) && (hdmi_y < 720))) begin
        if (failures < 8)
          $display("FAIL x=%0d y=%0d boxed_de=%b", hdmi_x, hdmi_y, boxed_de);
        failures = failures + 1;
      end
      if (checked == 3300) begin
        $display("RESULT checked=%0d failures=%0d", checked, failures);
        if (failures) $fatal(1, "full video alignment failed");
        $finish;
      end
    end
  end

  initial begin
    repeat (4) @(negedge pixel_clk);
    stream_reset_n = 1;
    #100000;
    $fatal(1, "timeout");
  end
endmodule
