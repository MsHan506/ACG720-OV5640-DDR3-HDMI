`timescale 1ns/1ps
module tb_sensor_osd_overlay;
    reg data_clk = 0;
    reg pixel_clk = 0;
    reg rst_n = 0;
    reg de = 1;
    reg [11:0] x = 0;
    reg [11:0] y = 0;
    reg [15:0] distance = 16'd1234;
    reg signed [15:0] roll = -16'sd1234;
    reg signed [15:0] pitch = 16'sd567;
    reg signed [15:0] yaw = -16'sd18000;
    reg drive_unlocked = 1'b1;
    reg [1:0] motion_state = 2'd1;
    reg signed [31:0] left_rpm = -32'sd123;
    reg signed [31:0] right_rpm = 32'sd87;
    wire [7:0] r, g, b;
    wire de_out, hs_out, vs_out;

    always #10 data_clk = ~data_clk;
    always #7 pixel_clk = ~pixel_clk;

    sensor_osd_overlay dut (
        .data_clk(data_clk), .data_rst_n(rst_n), .pixel_clk(pixel_clk),
        .video_de(de), .hsync_in(1'b1), .vsync_in(1'b1),
        .pixel_x(x), .pixel_y(y),
        .red_in(8'h11), .green_in(8'h22), .blue_in(8'h33),
        .distance_mm(distance), .roll_cdeg(roll),
        .pitch_cdeg(pitch), .yaw_cdeg(yaw),
        .drive_unlocked(drive_unlocked), .motion_state(motion_state),
        .show_encoder_counts(1'b0),
        .left_rpm(left_rpm), .right_rpm(right_rpm),
        .red_out(r), .green_out(g), .blue_out(b),
        .video_de_out(de_out), .hsync_out(hs_out), .vsync_out(vs_out)
    );

    initial begin
        #40 rst_n = 1;
        #800;
        if (dut.distance_bcd !== 20'h01234) $fatal(1, "distance BCD wrong: %h", dut.distance_bcd);
        if (dut.roll_bcd !== 20'h01234 || dut.angle_sign[0] !== 1'b1)
            $fatal(1, "roll format wrong: %h sign=%b", dut.roll_bcd, dut.angle_sign[0]);
        if (dut.pitch_bcd !== 20'h00567 || dut.angle_sign[1] !== 1'b0)
            $fatal(1, "pitch format wrong");
        if (dut.yaw_bcd !== 20'h18000 || dut.angle_sign[2] !== 1'b1)
            $fatal(1, "yaw format wrong");
        if (dut.left_rpm_bcd !== 20'h00123 || dut.right_rpm_bcd !== 20'h00087)
            $fatal(1, "wheel-speed format wrong");
        if (!dut.drive_unlocked_sync || dut.motion_state_sync !== 2'd1)
            $fatal(1, "motion status synchronization wrong");

        // Top-left illuminated pixel of the letter D.
        x = 12'd23;
        y = 12'd23;
        #100;
        if (r !== 8'hF8 || g !== 8'hF8 || b !== 8'h40)
            $fatal(1, "text pixel wrong: %h %h %h", r, g, b);

        // Panel background pixel.
        x = 12'd17;
        y = 12'd17;
        #100;
        if (r !== 8'h08 || g !== 8'h18 || b !== 8'h28)
            $fatal(1, "panel pixel wrong");

        $display("PASS sensor OSD formatting and pixels");
        $finish;
    end
endmodule
