`timescale 1ns/1ps

module target_follow_controller #(
    parameter integer IMAGE_WIDTH=1280,
    parameter integer STOP_DISTANCE_MM=450,
    parameter integer APPROACH_RPM=45,
    parameter integer TURN_RPM=35
)(
    input wire enable,
    input wire target_valid,
    input wire [11:0] target_center_x,
    input wire [15:0] distance_mm,
    input wire distance_valid,
    output reg signed [31:0] left_target_rpm,
    output reg signed [31:0] right_target_rpm,
    output reg left_dir,right_dir,
    output reg [2:0] follow_state
);
    localparam SEARCH=0,LEFT=1,RIGHT=2,APPROACH=3,ARRIVED=4;
    localparam integer LEFT_BOUND=IMAGE_WIDTH/2-120;
    localparam integer RIGHT_BOUND=IMAGE_WIDTH/2+120;
    always @(*) begin
        left_target_rpm=0; right_target_rpm=0; left_dir=0; right_dir=0;
        follow_state=ARRIVED;
        if (enable) begin
            if (!target_valid) begin
                follow_state=SEARCH;
                left_target_rpm=TURN_RPM; right_target_rpm=TURN_RPM;
                left_dir=0; right_dir=1;
            end else if (target_center_x<LEFT_BOUND) begin
                follow_state=LEFT;
                left_target_rpm=TURN_RPM; right_target_rpm=TURN_RPM;
                left_dir=1; right_dir=0;
            end else if (target_center_x>RIGHT_BOUND) begin
                follow_state=RIGHT;
                left_target_rpm=TURN_RPM; right_target_rpm=TURN_RPM;
                left_dir=0; right_dir=1;
            end else if (!distance_valid || distance_mm>STOP_DISTANCE_MM) begin
                follow_state=APPROACH;
                left_target_rpm=APPROACH_RPM;
                right_target_rpm=APPROACH_RPM;
            end
        end
    end
endmodule

