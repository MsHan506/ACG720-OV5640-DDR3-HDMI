`timescale 1ns/1ps

// Shapes open-loop motor commands without weakening the external safety gate.
// Stop is immediate.  Starts ramp up gradually, and a direction change must
// ramp all the way to zero before the new direction is applied.
module safe_motor_command_ramp #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer UPDATE_MS = 10,
    parameter [9:0] ACCEL_STEP = 10'd10,
    parameter [9:0] DECEL_STEP = 10'd20
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire [9:0] target_duty,
    input  wire       target_left_dir,
    input  wire       target_right_dir,
    output reg  [9:0] duty,
    output reg        left_dir,
    output reg        right_dir
);
    localparam integer UPDATE_CYCLES_RAW =
        (CLK_FREQ / 1000) * UPDATE_MS;
    localparam integer UPDATE_CYCLES =
        (UPDATE_CYCLES_RAW < 1) ? 1 : UPDATE_CYCLES_RAW;

    reg [31:0] update_counter;
    wire direction_change =
        (left_dir != target_left_dir) ||
        (right_dir != target_right_dir);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            update_counter <= 32'd0;
            duty <= 10'd0;
            left_dir <= 1'b0;
            right_dir <= 1'b0;
        end else if (!enable) begin
            // Emergency/normal stop must never wait for the ramp interval.
            update_counter <= 32'd0;
            duty <= 10'd0;
        end else if (update_counter >= UPDATE_CYCLES - 1) begin
            update_counter <= 32'd0;

            if (direction_change) begin
                // Never reverse a powered motor.  First ramp completely down.
                if (duty > DECEL_STEP)
                    duty <= duty - DECEL_STEP;
                else if (duty != 0)
                    duty <= 10'd0;
                else begin
                    left_dir <= target_left_dir;
                    right_dir <= target_right_dir;
                end
            end else if (duty < target_duty) begin
                if ((target_duty - duty) <= ACCEL_STEP)
                    duty <= target_duty;
                else
                    duty <= duty + ACCEL_STEP;
            end else if (duty > target_duty) begin
                if ((duty - target_duty) <= DECEL_STEP)
                    duty <= target_duty;
                else
                    duty <= duty - DECEL_STEP;
            end
        end else begin
            update_counter <= update_counter + 1'b1;
        end
    end
endmodule
