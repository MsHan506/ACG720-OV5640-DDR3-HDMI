`timescale 1ns/1ps

// Pin-independent car control core.  Board-specific pin binding is deliberately
// kept outside this module so an unknown motor driver cannot be energized by a
// guessed constraint file.
module car_control_core #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer PWM_FREQ = 20_000,
    // Placeholder only. Override with the measured quadrature counts for one
    // wheel revolution before closed-loop driving on real hardware.
    parameter integer COUNTS_PER_REV = 1456,
    parameter integer SAMPLE_TIME_MS = 10,
    parameter integer STOP_DISTANCE_MM = 300,
    parameter integer CLEAR_DISTANCE_MM = 450,
    parameter integer FORWARD_RPM = 180,
    parameter integer TURN_RPM = 140,
    parameter integer MOTOR_KP = 100,
    parameter integer MOTOR_KI = 10,
    parameter integer MOTOR_DEAD_ZONE = 0,
    parameter integer COMMISSIONING_UNLOCK = 0,
    parameter integer CH1_REVERSED = 0,
    parameter integer CH2_REVERSED = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire drive_enable,
    input  wire [15:0] front_distance_mm,
    input  wire distance_valid,
    input  wire left_enc_a,
    input  wire left_enc_b,
    input  wire right_enc_a,
    input  wire right_enc_b,
    output wire left_pwm,
    output wire left_in1,
    output wire left_in2,
    output wire right_pwm,
    output wire right_in1,
    output wire right_in2,
    output wire driver_stby,
    output wire signed [31:0] left_actual_rpm,
    output wire signed [31:0] right_actual_rpm,
    output wire [1:0] motion_state
);
    wire effective_enable = drive_enable && (COMMISSIONING_UNLOCK != 0);
    wire signed [31:0] left_target_raw;
    wire signed [31:0] right_target_raw;
    wire signed [31:0] left_target_sync;
    wire signed [31:0] right_target_sync;
    wire left_dir;
    wire right_dir;
    wire signed [31:0] left_actual_magnitude =
        left_actual_rpm[31] ? -left_actual_rpm : left_actual_rpm;
    wire signed [31:0] right_actual_magnitude =
        right_actual_rpm[31] ? -right_actual_rpm : right_actual_rpm;

    autonomous_motion_controller #(
        .CLK_FREQ(CLK_FREQ),
        .STOP_DISTANCE_MM(STOP_DISTANCE_MM),
        .CLEAR_DISTANCE_MM(CLEAR_DISTANCE_MM),
        .FORWARD_RPM(FORWARD_RPM),
        .TURN_RPM(TURN_RPM)
    ) u_motion (
        .clk(clk), .rst_n(rst_n), .enable(effective_enable),
        .distance_mm(front_distance_mm), .distance_valid(distance_valid),
        .left_target_rpm(left_target_raw),
        .right_target_rpm(right_target_raw),
        .left_dir(left_dir), .right_dir(right_dir),
        .motion_state(motion_state)
    );

    wheel_sync_control u_sync (
        .clk(clk), .rst_n(rst_n), .sync_enable(effective_enable),
        .left_target_rpm(left_target_raw),
        .right_target_rpm(right_target_raw),
        .left_actual_rpm(left_actual_magnitude),
        .right_actual_rpm(right_actual_magnitude),
        .left_target_sync_rpm(left_target_sync),
        .right_target_sync_rpm(right_target_sync),
        .sync_error(), .correction()
    );

    wire raw_left_pwm, raw_left_in1, raw_left_in2;
    wire raw_right_pwm, raw_right_in1, raw_right_in2;
    dual_motor_control #(
        .CLK_FREQ(CLK_FREQ), .PWM_FREQ(PWM_FREQ),
        .COUNTS_PER_REV(COUNTS_PER_REV),
        .SAMPLE_TIME_MS(SAMPLE_TIME_MS),
        .KP(MOTOR_KP), .KI(MOTOR_KI),
        .DEAD_ZONE(MOTOR_DEAD_ZONE)
    ) u_motors (
        .clk(clk), .rst_n(rst_n),
        .left_target_rpm(left_target_sync),
        .right_target_rpm(right_target_sync),
        .left_dir(left_dir), .right_dir(right_dir),
        .left_enc_a(left_enc_a), .left_enc_b(left_enc_b),
        .right_enc_a(right_enc_a), .right_enc_b(right_enc_b),
        .left_pwm(raw_left_pwm), .left_in1(raw_left_in1),
        .left_in2(raw_left_in2), .right_pwm(raw_right_pwm),
        .right_in1(raw_right_in1), .right_in2(raw_right_in2),
        .left_encoder_count(), .right_encoder_count(),
        .left_actual_rpm(left_actual_rpm),
        .right_actual_rpm(right_actual_rpm),
        .left_duty(), .right_duty(), .left_error(), .right_error()
    );

    tb6612_dual_safe_adapter #(
        .CLK_FREQ(CLK_FREQ), .DEADTIME_US(2000),
        .CH1_REVERSED(CH1_REVERSED), .CH2_REVERSED(CH2_REVERSED)
    ) u_driver_adapter (
        .clk(clk), .rst_n(rst_n), .enable(effective_enable),
        .ch1_pwm_in(raw_left_pwm), .ch1_in1_in(raw_left_in1),
        .ch1_in2_in(raw_left_in2), .ch2_pwm_in(raw_right_pwm),
        .ch2_in1_in(raw_right_in1), .ch2_in2_in(raw_right_in2),
        .driver_stby(driver_stby), .ch1_pwm(left_pwm),
        .ch1_in1(left_in1), .ch1_in2(left_in2),
        .ch2_pwm(right_pwm), .ch2_in1(right_in1),
        .ch2_in2(right_in2));
endmodule
