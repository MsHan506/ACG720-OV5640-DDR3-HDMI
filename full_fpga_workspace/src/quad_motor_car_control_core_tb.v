`timescale 1ns/1ps

module quad_motor_car_control_core_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg drive_enable = 1'b1;
    reg [15:0] distance = 16'd1000;
    reg distance_valid = 1'b0;
    wire locked_stby;
    wire locked_m1_pwm, locked_m2_pwm, locked_m3_pwm, locked_m4_pwm;
    wire unlocked_stby;
    wire unlocked_m1_in1, unlocked_m2_in1, unlocked_m3_in1, unlocked_m4_in1;
    wire [1:0] locked_state, unlocked_state;
    always #5 clk = ~clk;

    quad_motor_car_control_core #(
        .CLK_FREQ(1000), .PWM_FREQ(100), .ENCODER_COUNTS_PER_REV(100),
        .SAMPLE_TIME_MS(10), .COMMISSIONING_UNLOCK(0)
    ) locked (
        .clk(clk), .rst_n(rst_n), .drive_enable(drive_enable),
        .front_distance_mm(distance), .distance_valid(distance_valid),
        .enc1_a(1'b0), .enc1_b(1'b0), .enc2_a(1'b0), .enc2_b(1'b0),
        .enc3_a(1'b0), .enc3_b(1'b0), .enc4_a(1'b0), .enc4_b(1'b0),
        .driver_stby(locked_stby),
        .m1_pwm(locked_m1_pwm), .m1_in1(), .m1_in2(),
        .m2_pwm(locked_m2_pwm), .m2_in1(), .m2_in2(),
        .m3_pwm(locked_m3_pwm), .m3_in1(), .m3_in2(),
        .m4_pwm(locked_m4_pwm), .m4_in1(), .m4_in2(),
        .left_actual_rpm(), .right_actual_rpm(), .motion_state(locked_state));

    quad_motor_car_control_core #(
        .CLK_FREQ(1000), .PWM_FREQ(100), .ENCODER_COUNTS_PER_REV(100),
        .SAMPLE_TIME_MS(10), .COMMISSIONING_UNLOCK(1)
    ) unlocked (
        .clk(clk), .rst_n(rst_n), .drive_enable(drive_enable),
        .front_distance_mm(distance), .distance_valid(distance_valid),
        .enc1_a(1'b0), .enc1_b(1'b0), .enc2_a(1'b0), .enc2_b(1'b0),
        .enc3_a(1'b0), .enc3_b(1'b0), .enc4_a(1'b0), .enc4_b(1'b0),
        .driver_stby(unlocked_stby),
        .m1_pwm(), .m1_in1(unlocked_m1_in1), .m1_in2(),
        .m2_pwm(), .m2_in1(unlocked_m2_in1), .m2_in2(),
        .m3_pwm(), .m3_in1(unlocked_m3_in1), .m3_in2(),
        .m4_pwm(), .m4_in1(unlocked_m4_in1), .m4_in2(),
        .left_actual_rpm(), .right_actual_rpm(), .motion_state(unlocked_state));

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        distance_valid = 1'b1;
        @(negedge clk);
        distance_valid = 1'b0;
        repeat (20) @(posedge clk);
        if (locked_stby || locked_m1_pwm || locked_m2_pwm ||
            locked_m3_pwm || locked_m4_pwm || locked_state != 2'd0) begin
            $display("FAIL default commissioning lock allowed motion");
            $fatal(1);
        end
        if (!unlocked_stby || unlocked_state != 2'd1 ||
            !unlocked_m1_in1 || !unlocked_m2_in1 ||
            !unlocked_m3_in1 || !unlocked_m4_in1) begin
            $display("FAIL deliberately unlocked forward state");
            $fatal(1);
        end
        drive_enable = 1'b0;
        @(posedge clk);
        #1;
        if (unlocked_stby) begin
            $display("FAIL disable did not force driver standby");
            $fatal(1);
        end
        $display("PASS four-motor default lock and deliberate unlock");
        $finish;
    end
endmodule
