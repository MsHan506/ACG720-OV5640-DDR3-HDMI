`timescale 1ns/1ps

// Four independent speed loops. Motors 1/2 form the left side and motors 3/4
// form the right side; each motor keeps its own PWM output.
module quad_motor_control #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer PWM_FREQ = 20_000,
    parameter integer COUNTS_PER_REV = 1456,
    parameter integer SAMPLE_TIME_MS = 10
)(
    input wire clk, input wire rst_n,
    input wire signed [31:0] left_target_rpm,
    input wire signed [31:0] right_target_rpm,
    input wire left_dir, input wire right_dir,
    input wire enc1_a, input wire enc1_b,
    input wire enc2_a, input wire enc2_b,
    input wire enc3_a, input wire enc3_b,
    input wire enc4_a, input wire enc4_b,
    output wire m1_pwm, output wire m1_in1, output wire m1_in2,
    output wire m2_pwm, output wire m2_in1, output wire m2_in2,
    output wire m3_pwm, output wire m3_in1, output wire m3_in2,
    output wire m4_pwm, output wire m4_in1, output wire m4_in2,
    output wire signed [31:0] rpm1, output wire signed [31:0] rpm2,
    output wire signed [31:0] rpm3, output wire signed [31:0] rpm4
);
    single_motor_control #(.CLK_FREQ(CLK_FREQ), .PWM_FREQ(PWM_FREQ),
        .COUNTS_PER_REV(COUNTS_PER_REV), .SAMPLE_TIME_MS(SAMPLE_TIME_MS)) u_m1 (
        .clk(clk), .rst_n(rst_n), .target_rpm(left_target_rpm), .dir(left_dir),
        .enc_a(enc1_a), .enc_b(enc1_b), .pwm_out(m1_pwm), .in1(m1_in1),
        .in2(m1_in2), .encoder_count(), .actual_rpm(rpm1), .duty(),
        .duty_pi(), .error(), .integral());
    single_motor_control #(.CLK_FREQ(CLK_FREQ), .PWM_FREQ(PWM_FREQ),
        .COUNTS_PER_REV(COUNTS_PER_REV), .SAMPLE_TIME_MS(SAMPLE_TIME_MS)) u_m2 (
        .clk(clk), .rst_n(rst_n), .target_rpm(left_target_rpm), .dir(left_dir),
        .enc_a(enc2_a), .enc_b(enc2_b), .pwm_out(m2_pwm), .in1(m2_in1),
        .in2(m2_in2), .encoder_count(), .actual_rpm(rpm2), .duty(),
        .duty_pi(), .error(), .integral());
    single_motor_control #(.CLK_FREQ(CLK_FREQ), .PWM_FREQ(PWM_FREQ),
        .COUNTS_PER_REV(COUNTS_PER_REV), .SAMPLE_TIME_MS(SAMPLE_TIME_MS)) u_m3 (
        .clk(clk), .rst_n(rst_n), .target_rpm(right_target_rpm), .dir(right_dir),
        .enc_a(enc3_a), .enc_b(enc3_b), .pwm_out(m3_pwm), .in1(m3_in1),
        .in2(m3_in2), .encoder_count(), .actual_rpm(rpm3), .duty(),
        .duty_pi(), .error(), .integral());
    single_motor_control #(.CLK_FREQ(CLK_FREQ), .PWM_FREQ(PWM_FREQ),
        .COUNTS_PER_REV(COUNTS_PER_REV), .SAMPLE_TIME_MS(SAMPLE_TIME_MS)) u_m4 (
        .clk(clk), .rst_n(rst_n), .target_rpm(right_target_rpm), .dir(right_dir),
        .enc_a(enc4_a), .enc_b(enc4_b), .pwm_out(m4_pwm), .in1(m4_in1),
        .in2(m4_in2), .encoder_count(), .actual_rpm(rpm4), .duty(),
        .duty_pi(), .error(), .integral());
endmodule
