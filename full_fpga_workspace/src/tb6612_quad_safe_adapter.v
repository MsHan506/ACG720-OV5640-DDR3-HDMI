`timescale 1ns/1ps

// Safe output adapter for a four-motor board made from two TB6612FNG ICs.
module tb6612_quad_safe_adapter #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer DEADTIME_US = 2000,
    parameter integer M1_REVERSED = 0,
    parameter integer M2_REVERSED = 0,
    parameter integer M3_REVERSED = 0,
    parameter integer M4_REVERSED = 0
)(
    input wire clk, input wire rst_n, input wire enable,
    input wire m1_pwm_in, input wire m1_in1_in, input wire m1_in2_in,
    input wire m2_pwm_in, input wire m2_in1_in, input wire m2_in2_in,
    input wire m3_pwm_in, input wire m3_in1_in, input wire m3_in2_in,
    input wire m4_pwm_in, input wire m4_in1_in, input wire m4_in2_in,
    output wire driver_stby,
    output wire m1_pwm, output wire m1_in1, output wire m1_in2,
    output wire m2_pwm, output wire m2_in1, output wire m2_in2,
    output wire m3_pwm, output wire m3_in1, output wire m3_in2,
    output wire m4_pwm, output wire m4_in1, output wire m4_in2
);
    localparam integer DEADTIME_CYCLES_RAW =
        (CLK_FREQ / 1_000_000) * DEADTIME_US;
    localparam integer DEADTIME_CYCLES =
        (DEADTIME_CYCLES_RAW < 1) ? 1 : DEADTIME_CYCLES_RAW;
    reg [7:0] latched_direction;
    reg active;
    reg [31:0] deadtime_counter;
    wire m1_req_in1 = M1_REVERSED ? m1_in2_in : m1_in1_in;
    wire m1_req_in2 = M1_REVERSED ? m1_in1_in : m1_in2_in;
    wire m2_req_in1 = M2_REVERSED ? m2_in2_in : m2_in1_in;
    wire m2_req_in2 = M2_REVERSED ? m2_in1_in : m2_in2_in;
    wire m3_req_in1 = M3_REVERSED ? m3_in2_in : m3_in1_in;
    wire m3_req_in2 = M3_REVERSED ? m3_in1_in : m3_in2_in;
    wire m4_req_in1 = M4_REVERSED ? m4_in2_in : m4_in1_in;
    wire m4_req_in2 = M4_REVERSED ? m4_in1_in : m4_in2_in;
    wire [7:0] requested_direction = {
        m4_req_in1, m4_req_in2, m3_req_in1, m3_req_in2,
        m2_req_in1, m2_req_in2, m1_req_in1, m1_req_in2
    };
    wire direction_changed = (requested_direction != latched_direction);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_direction <= 8'd0;
            active <= 1'b0;
            deadtime_counter <= 32'd0;
        end else if (!enable) begin
            active <= 1'b0;
            deadtime_counter <= DEADTIME_CYCLES - 1;
            latched_direction <= requested_direction;
        end else if (active && direction_changed) begin
            active <= 1'b0;
            deadtime_counter <= DEADTIME_CYCLES - 1;
            latched_direction <= requested_direction;
        end else if (!active) begin
            if (direction_changed) begin
                deadtime_counter <= DEADTIME_CYCLES - 1;
                latched_direction <= requested_direction;
            end else if (deadtime_counter != 0) begin
                deadtime_counter <= deadtime_counter - 1'b1;
            end else begin
                active <= 1'b1;
            end
        end
    end

    assign driver_stby = enable && active;
    assign m1_pwm = driver_stby ? m1_pwm_in : 1'b0;
    assign m2_pwm = driver_stby ? m2_pwm_in : 1'b0;
    assign m3_pwm = driver_stby ? m3_pwm_in : 1'b0;
    assign m4_pwm = driver_stby ? m4_pwm_in : 1'b0;
    assign m1_in1 = driver_stby ? latched_direction[1] : 1'b0;
    assign m1_in2 = driver_stby ? latched_direction[0] : 1'b0;
    assign m2_in1 = driver_stby ? latched_direction[3] : 1'b0;
    assign m2_in2 = driver_stby ? latched_direction[2] : 1'b0;
    assign m3_in1 = driver_stby ? latched_direction[5] : 1'b0;
    assign m3_in2 = driver_stby ? latched_direction[4] : 1'b0;
    assign m4_in1 = driver_stby ? latched_direction[7] : 1'b0;
    assign m4_in2 = driver_stby ? latched_direction[6] : 1'b0;
endmodule
