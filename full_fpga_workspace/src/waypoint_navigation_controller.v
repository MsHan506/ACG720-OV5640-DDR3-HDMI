`timescale 1ns/1ps

// A deterministic two-leg route for a known competition field.  Navigation is
// encoder-distance plus IMU-heading based; distances are expressed in measured
// quadrature counts so the physical course can be calibrated without changing
// the control architecture.
module waypoint_navigation_controller #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer LEG1_COUNTS = 2960,
    parameter integer LEG2_COUNTS = 2960,
    parameter integer BYPASS_COUNTS = 740,
    parameter integer DRIVE_RPM = 55,
    parameter integer TURN_RPM = 40,
    parameter integer STOP_DISTANCE_MM = 350,
    parameter integer CLEAR_DISTANCE_MM = 500,
    parameter integer HEADING_TOL_CDEG = 500,
    parameter integer BRAKE_TIME_MS = 250
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    input  wire [15:0] distance_mm,
    input  wire distance_valid,
    input  wire signed [15:0] yaw_cdeg,
    input  wire imu_valid,
    input  wire signed [31:0] left_count,
    input  wire signed [31:0] right_count,
    output reg signed [31:0] left_target_rpm,
    output reg signed [31:0] right_target_rpm,
    output reg left_dir,
    output reg right_dir,
    output reg [3:0] nav_state,
    output reg route_complete
);
    localparam ST_IDLE=0, ST_ALIGN=1, ST_DRIVE=2, ST_BRAKE=3,
               ST_AVOID_TURN=4, ST_BYPASS=5, ST_RESTORE=6,
               ST_NEXT=7, ST_DONE=8;
    localparam integer BRAKE_CYCLES=(CLK_FREQ/1000)*BRAKE_TIME_MS;

    reg signed [15:0] origin_yaw;
    reg signed [15:0] leg_heading;
    reg signed [15:0] avoid_heading;
    reg [1:0] leg_index;
    reg signed [31:0] start_left_count, start_right_count;
    reg [31:0] drive_goal_counts;
    reg [31:0] brake_counter;
    reg yaw_seen;

    wire signed [31:0] left_delta = left_count-start_left_count;
    wire signed [31:0] right_delta = right_count-start_right_count;
    wire [31:0] left_distance = left_delta[31] ? -left_delta : left_delta;
    wire [31:0] right_distance = right_delta[31] ? -right_delta : right_delta;
    wire [31:0] travel_counts = (left_distance+right_distance)>>1;
    wire [31:0] leg_goal = (leg_index==0) ? LEG1_COUNTS : LEG2_COUNTS;

    function signed [15:0] wrapped_error;
        input signed [15:0] target;
        input signed [15:0] actual;
        reg signed [16:0] raw;
        begin
            raw = target-actual;
            if (raw > 17'sd18000) raw = raw-17'sd36000;
            else if (raw < -17'sd18000) raw = raw+17'sd36000;
            wrapped_error = raw[15:0];
        end
    endfunction
    function [15:0] abs16;
        input signed [15:0] value;
        begin abs16 = value[15] ? -value : value; end
    endfunction

    wire signed [15:0] leg_error = wrapped_error(leg_heading,yaw_cdeg);
    wire signed [15:0] avoid_error = wrapped_error(avoid_heading,yaw_cdeg);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nav_state<=ST_IDLE; route_complete<=0; leg_index<=0;
            origin_yaw<=0; leg_heading<=0; avoid_heading<=0;
            start_left_count<=0; start_right_count<=0;
            drive_goal_counts<=LEG1_COUNTS;
            brake_counter<=0; yaw_seen<=0;
        end else begin
            if (imu_valid) yaw_seen<=1;
            if (!enable) begin
                nav_state<=ST_IDLE; route_complete<=0; leg_index<=0;
                brake_counter<=0; yaw_seen<=0;
            end else case(nav_state)
                ST_IDLE: if (imu_valid || yaw_seen) begin
                    origin_yaw<=yaw_cdeg; leg_heading<=yaw_cdeg;
                    leg_index<=0; nav_state<=ST_ALIGN;
                end
                ST_ALIGN: if (abs16(leg_error)<=HEADING_TOL_CDEG) begin
                    start_left_count<=left_count;
                    start_right_count<=right_count;
                    drive_goal_counts<=leg_goal;
                    nav_state<=ST_DRIVE;
                end
                ST_DRIVE: begin
                    if (travel_counts>=drive_goal_counts) begin
                        nav_state<=ST_NEXT;
                    end else if (distance_valid && distance_mm<=STOP_DISTANCE_MM) begin
                        drive_goal_counts<=drive_goal_counts-travel_counts;
                        brake_counter<=0; nav_state<=ST_BRAKE;
                    end
                end
                ST_BRAKE: begin
                    if (brake_counter>=BRAKE_CYCLES-1) begin
                        brake_counter<=0;
                        avoid_heading<=leg_heading+16'sd9000;
                        nav_state<=ST_AVOID_TURN;
                    end else brake_counter<=brake_counter+1'b1;
                end
                ST_AVOID_TURN: if (abs16(avoid_error)<=HEADING_TOL_CDEG &&
                                      (!distance_valid || distance_mm>=CLEAR_DISTANCE_MM)) begin
                    start_left_count<=left_count;
                    start_right_count<=right_count;
                    nav_state<=ST_BYPASS;
                end
                ST_BYPASS: if (travel_counts>=BYPASS_COUNTS) nav_state<=ST_RESTORE;
                ST_RESTORE: if (abs16(leg_error)<=HEADING_TOL_CDEG) begin
                    start_left_count<=left_count;
                    start_right_count<=right_count;
                    nav_state<=ST_DRIVE;
                end
                ST_NEXT: begin
                    if (leg_index==0) begin
                        leg_index<=1;
                        leg_heading<=origin_yaw+16'sd9000;
                        nav_state<=ST_ALIGN;
                    end else begin nav_state<=ST_DONE; route_complete<=1; end
                end
                ST_DONE: route_complete<=1;
                default: nav_state<=ST_IDLE;
            endcase
        end
    end

    always @(*) begin
        left_target_rpm=0; right_target_rpm=0; left_dir=0; right_dir=0;
        case(nav_state)
            ST_ALIGN,ST_RESTORE: begin
                left_target_rpm=TURN_RPM; right_target_rpm=TURN_RPM;
                if (leg_error>0) begin left_dir=0; right_dir=1; end
                else begin left_dir=1; right_dir=0; end
            end
            ST_DRIVE: begin
                left_target_rpm=DRIVE_RPM; right_target_rpm=DRIVE_RPM;
                if (leg_error>300) right_target_rpm=DRIVE_RPM-12;
                else if (leg_error<-300) left_target_rpm=DRIVE_RPM-12;
            end
            ST_AVOID_TURN: begin
                left_target_rpm=TURN_RPM; right_target_rpm=TURN_RPM;
                if (avoid_error>0) begin left_dir=0; right_dir=1; end
                else begin left_dir=1; right_dir=0; end
            end
            ST_BYPASS: begin
                left_target_rpm=DRIVE_RPM-10;
                right_target_rpm=DRIVE_RPM-10;
            end
            default: begin end
        endcase
    end
endmodule

