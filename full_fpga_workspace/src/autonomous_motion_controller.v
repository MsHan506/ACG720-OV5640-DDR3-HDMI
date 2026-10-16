`timescale 1ns/1ps

module autonomous_motion_controller #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer STOP_DISTANCE_MM = 300,
    parameter integer CLEAR_DISTANCE_MM = 450,
    parameter integer FORWARD_RPM = 180,
    parameter integer TURN_RPM = 140,
    parameter integer TURN_TIME_MS = 600,
    parameter integer BRAKE_TIME_MS = 200,
    parameter integer SENSOR_WATCHDOG_MS = 500
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [15:0] distance_mm,
    input  wire        distance_valid,
    output reg signed [31:0] left_target_rpm,
    output reg signed [31:0] right_target_rpm,
    output reg         left_dir,
    output reg         right_dir,
    output reg  [1:0]  motion_state
);
    localparam [1:0] STATE_STOP    = 2'd0;
    localparam [1:0] STATE_FORWARD = 2'd1;
    localparam [1:0] STATE_TURN    = 2'd2;
    localparam [1:0] STATE_BRAKE   = 2'd3;

    localparam integer TURN_CYCLES = (CLK_FREQ / 1000) * TURN_TIME_MS;
    localparam integer WATCHDOG_CYCLES =
        (CLK_FREQ / 1000) * SENSOR_WATCHDOG_MS;
    localparam integer BRAKE_CYCLES =
        (CLK_FREQ / 1000) * BRAKE_TIME_MS;

    reg [31:0] turn_counter;
    reg [31:0] watchdog_counter;
    reg [31:0] brake_counter;
    reg [15:0] last_distance_mm;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            motion_state <= STATE_STOP;
            turn_counter <= 32'd0;
            watchdog_counter <= 32'd0;
            brake_counter <= 32'd0;
            last_distance_mm <= 16'd0;
        end else begin
            if (distance_valid) begin
                last_distance_mm <= distance_mm;
                watchdog_counter <= 32'd0;
            end else if (watchdog_counter < WATCHDOG_CYCLES) begin
                watchdog_counter <= watchdog_counter + 1'b1;
            end

            if (!enable) begin
                motion_state <= STATE_STOP;
                turn_counter <= 32'd0;
                brake_counter <= 32'd0;
            end else if (!distance_valid &&
                         watchdog_counter >= WATCHDOG_CYCLES - 1) begin
                // A missing range stream is treated as unsafe: stop the car.
                motion_state <= STATE_STOP;
                turn_counter <= 32'd0;
            end else begin
                case (motion_state)
                    STATE_STOP: begin
                        turn_counter <= 32'd0;
                        if (distance_valid) begin
                            if (distance_mm <= STOP_DISTANCE_MM)
                                motion_state <= STATE_BRAKE;
                            else
                                motion_state <= STATE_FORWARD;
                        end
                    end

                    STATE_FORWARD: begin
                        turn_counter <= 32'd0;
                        if (distance_valid &&
                            distance_mm <= STOP_DISTANCE_MM)
                            motion_state <= STATE_BRAKE;
                    end

                    STATE_BRAKE: begin
                        // Explicit stationary interval before reversing one
                        // wheel: required automatic stop plus safe reversal.
                        if (brake_counter >= BRAKE_CYCLES - 1) begin
                            brake_counter <= 32'd0;
                            motion_state <= STATE_TURN;
                        end else begin
                            brake_counter <= brake_counter + 1'b1;
                        end
                    end

                    STATE_TURN: begin
                        if (turn_counter >= TURN_CYCLES - 1) begin
                            turn_counter <= 32'd0;
                            if (last_distance_mm >= CLEAR_DISTANCE_MM)
                                motion_state <= STATE_FORWARD;
                        end else begin
                            turn_counter <= turn_counter + 1'b1;
                        end
                    end

                    default: begin
                        motion_state <= STATE_STOP;
                        turn_counter <= 32'd0;
                    end
                endcase
            end
        end
    end

    always @(*) begin
        left_target_rpm = 32'sd0;
        right_target_rpm = 32'sd0;
        left_dir = 1'b0;
        right_dir = 1'b0;

        case (motion_state)
            STATE_FORWARD: begin
                left_target_rpm = FORWARD_RPM;
                right_target_rpm = FORWARD_RPM;
            end
            STATE_TURN: begin
                left_target_rpm = TURN_RPM;
                right_target_rpm = TURN_RPM;
                // Opposite wheel directions make an in-place turn.  Swap these
                // two polarity values if the physical motor mounting is reversed.
                left_dir = 1'b0;
                right_dir = 1'b1;
            end
            default: begin
                left_target_rpm = 32'sd0;
                right_target_rpm = 32'sd0;
            end
        endcase
    end
endmodule
