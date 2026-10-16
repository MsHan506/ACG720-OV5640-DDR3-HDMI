`timescale 1ns/1ps

module manual_motion_commands #(
    parameter integer DRIVE_RPM = 60,
    parameter integer TURN_RPM = 45
)(
    input  wire [2:0] mode,
    output reg signed [31:0] left_target_rpm,
    output reg signed [31:0] right_target_rpm,
    output reg left_dir,
    output reg right_dir,
    output reg [1:0] display_state
);
    localparam [2:0] MODE_AUTO    = 3'd0;
    localparam [2:0] MODE_FORWARD = 3'd1;
    localparam [2:0] MODE_REVERSE = 3'd2;
    localparam [2:0] MODE_LEFT    = 3'd3;
    localparam [2:0] MODE_RIGHT   = 3'd4;

    always @(*) begin
        left_target_rpm = 0;
        right_target_rpm = 0;
        left_dir = 0;
        right_dir = 0;
        display_state = 0;
        case (mode)
            MODE_FORWARD: begin
                left_target_rpm = DRIVE_RPM;
                right_target_rpm = DRIVE_RPM;
                display_state = 1;
            end
            MODE_REVERSE: begin
                left_target_rpm = DRIVE_RPM;
                right_target_rpm = DRIVE_RPM;
                left_dir = 1;
                right_dir = 1;
                display_state = 1;
            end
            MODE_LEFT: begin
                left_target_rpm = TURN_RPM;
                right_target_rpm = TURN_RPM;
                left_dir = 1;
                right_dir = 0;
                display_state = 2;
            end
            MODE_RIGHT: begin
                left_target_rpm = TURN_RPM;
                right_target_rpm = TURN_RPM;
                left_dir = 0;
                right_dir = 1;
                display_state = 2;
            end
            default: begin end
        endcase
    end
endmodule

