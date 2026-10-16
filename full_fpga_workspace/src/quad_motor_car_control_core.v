`timescale 1ns/1ps

// Four-motor autonomous wrapper for the photographed dual-TB6612FNG board.
// COMMISSIONING_UNLOCK defaults to zero, so accidental instantiation cannot
// move the car before connector and voltage checks are complete.
module quad_motor_car_control_core #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer PWM_FREQ = 20_000,
    parameter integer ENCODER_COUNTS_PER_REV = 1456,
    parameter integer SAMPLE_TIME_MS = 10,
    parameter integer COMMISSIONING_UNLOCK = 0,
    parameter integer M1_REVERSED = 0,
    parameter integer M2_REVERSED = 0,
    parameter integer M3_REVERSED = 0,
    parameter integer M4_REVERSED = 0
)(
    input wire clk, input wire rst_n, input wire drive_enable,
    input wire [15:0] front_distance_mm, input wire distance_valid,
    input wire enc1_a, input wire enc1_b,
    input wire enc2_a, input wire enc2_b,
    input wire enc3_a, input wire enc3_b,
    input wire enc4_a, input wire enc4_b,
    output wire driver_stby,
    output wire m1_pwm, output wire m1_in1, output wire m1_in2,
    output wire m2_pwm, output wire m2_in1, output wire m2_in2,
    output wire m3_pwm, output wire m3_in1, output wire m3_in2,
    output wire m4_pwm, output wire m4_in1, output wire m4_in2,
    output wire signed [31:0] left_actual_rpm,
    output wire signed [31:0] right_actual_rpm,
    output wire [1:0] motion_state
);
    wire effective_enable = drive_enable && (COMMISSIONING_UNLOCK != 0);
    wire signed [31:0] left_target_raw, right_target_raw;
    wire signed [31:0] left_target_sync, right_target_sync;
    wire left_dir, right_dir;
    wire signed [31:0] rpm1, rpm2, rpm3, rpm4;
    wire signed [31:0] rpm1_mag = rpm1[31] ? -rpm1 : rpm1;
    wire signed [31:0] rpm2_mag = rpm2[31] ? -rpm2 : rpm2;
    wire signed [31:0] rpm3_mag = rpm3[31] ? -rpm3 : rpm3;
    wire signed [31:0] rpm4_mag = rpm4[31] ? -rpm4 : rpm4;
    assign left_actual_rpm = (rpm1_mag + rpm2_mag) >>> 1;
    assign right_actual_rpm = (rpm3_mag + rpm4_mag) >>> 1;

    autonomous_motion_controller #(.CLK_FREQ(CLK_FREQ)) u_motion (
        .clk(clk), .rst_n(rst_n), .enable(effective_enable),
        .distance_mm(front_distance_mm), .distance_valid(distance_valid),
        .left_target_rpm(left_target_raw),
        .right_target_rpm(right_target_raw),
        .left_dir(left_dir), .right_dir(right_dir),
        .motion_state(motion_state));
    wheel_sync_control u_sync (
        .clk(clk), .rst_n(rst_n), .sync_enable(effective_enable),
        .left_target_rpm(left_target_raw), .right_target_rpm(right_target_raw),
        .left_actual_rpm(left_actual_rpm), .right_actual_rpm(right_actual_rpm),
        .left_target_sync_rpm(left_target_sync),
        .right_target_sync_rpm(right_target_sync),
        .sync_error(), .correction());

    wire raw_m1_pwm, raw_m1_in1, raw_m1_in2;
    wire raw_m2_pwm, raw_m2_in1, raw_m2_in2;
    wire raw_m3_pwm, raw_m3_in1, raw_m3_in2;
    wire raw_m4_pwm, raw_m4_in1, raw_m4_in2;
    quad_motor_control #(.CLK_FREQ(CLK_FREQ), .PWM_FREQ(PWM_FREQ),
        .COUNTS_PER_REV(ENCODER_COUNTS_PER_REV),
        .SAMPLE_TIME_MS(SAMPLE_TIME_MS)) u_motors (
        .clk(clk), .rst_n(rst_n), .left_target_rpm(left_target_sync),
        .right_target_rpm(right_target_sync), .left_dir(left_dir),
        .right_dir(right_dir), .enc1_a(enc1_a), .enc1_b(enc1_b),
        .enc2_a(enc2_a), .enc2_b(enc2_b), .enc3_a(enc3_a),
        .enc3_b(enc3_b), .enc4_a(enc4_a), .enc4_b(enc4_b),
        .m1_pwm(raw_m1_pwm), .m1_in1(raw_m1_in1), .m1_in2(raw_m1_in2),
        .m2_pwm(raw_m2_pwm), .m2_in1(raw_m2_in1), .m2_in2(raw_m2_in2),
        .m3_pwm(raw_m3_pwm), .m3_in1(raw_m3_in1), .m3_in2(raw_m3_in2),
        .m4_pwm(raw_m4_pwm), .m4_in1(raw_m4_in1), .m4_in2(raw_m4_in2),
        .rpm1(rpm1), .rpm2(rpm2), .rpm3(rpm3), .rpm4(rpm4));

    tb6612_quad_safe_adapter #(
        .CLK_FREQ(CLK_FREQ), .DEADTIME_US(2000),
        .M1_REVERSED(M1_REVERSED), .M2_REVERSED(M2_REVERSED),
        .M3_REVERSED(M3_REVERSED), .M4_REVERSED(M4_REVERSED))
    u_driver_adapter (
        .clk(clk), .rst_n(rst_n), .enable(effective_enable),
        .m1_pwm_in(raw_m1_pwm), .m1_in1_in(raw_m1_in1), .m1_in2_in(raw_m1_in2),
        .m2_pwm_in(raw_m2_pwm), .m2_in1_in(raw_m2_in1), .m2_in2_in(raw_m2_in2),
        .m3_pwm_in(raw_m3_pwm), .m3_in1_in(raw_m3_in1), .m3_in2_in(raw_m3_in2),
        .m4_pwm_in(raw_m4_pwm), .m4_in1_in(raw_m4_in1), .m4_in2_in(raw_m4_in2),
        .driver_stby(driver_stby),
        .m1_pwm(m1_pwm), .m1_in1(m1_in1), .m1_in2(m1_in2),
        .m2_pwm(m2_pwm), .m2_in1(m2_in1), .m2_in2(m2_in2),
        .m3_pwm(m3_pwm), .m3_in1(m3_in1), .m3_in2(m3_in2),
        .m4_pwm(m4_pwm), .m4_in1(m4_in1), .m4_in2(m4_in2));
endmodule
