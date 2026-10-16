`timescale 1ns/1ps

module advanced_features_tb;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    integer failures=0;

    task tick;
        begin @(posedge clk); #1; end
    endtask
    task check;
        input condition;
        input [8*80-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL %0s",message);
                failures=failures+1;
            end
        end
    endtask

    reg command_valid=0;
    reg [7:0] command=0;
    wire remote_start,remote_stop;
    wire [2:0] drive_mode;
    remote_drive_commands remote (
        .clk(clk),.rst_n(rst_n),.command_valid(command_valid),.command(command),
        .start_pulse(remote_start),.stop_pulse(remote_stop),.drive_mode(drive_mode));

    reg ramp_enable=0;
    reg signed [31:0] ramp_target_l=0,ramp_target_r=0;
    reg ramp_target_ld=0,ramp_target_rd=0;
    wire signed [31:0] ramp_l,ramp_r;
    wire ramp_ld,ramp_rd;
    dual_rpm_command_ramp #(.CLK_FREQ(1000),.UPDATE_MS(1),
        .ACCEL_STEP_RPM(6),.DECEL_STEP_RPM(6)) ramp (
        .clk(clk),.rst_n(rst_n),.enable(ramp_enable),
        .target_left_rpm(ramp_target_l),.target_right_rpm(ramp_target_r),
        .target_left_dir(ramp_target_ld),.target_right_dir(ramp_target_rd),
        .left_rpm(ramp_l),.right_rpm(ramp_r),.left_dir(ramp_ld),.right_dir(ramp_rd));

    reg pixel_valid=0,frame_sync=0;
    reg [11:0] pixel_x=0,pixel_y=0;
    reg [7:0] red=0,green=0,blue=0;
    wire target_valid;
    wire [11:0] target_x,target_y,box_l,box_r,box_t,box_b;
    wire [23:0] target_pixels;
    wire frame_toggle;
    red_target_detector #(.MIN_PIXELS(3)) detector (
        .pixel_clk(clk),.rst_n(rst_n),.frame_sync(frame_sync),
        .pixel_valid(pixel_valid),.pixel_x(pixel_x),.pixel_y(pixel_y),
        .red(red),.green(green),.blue(blue),.target_valid(target_valid),
        .target_center_x(target_x),.target_center_y(target_y),
        .bbox_left(box_l),.bbox_right(box_r),.bbox_top(box_t),.bbox_bottom(box_b),
        .target_pixel_count(target_pixels),.frame_toggle(frame_toggle));

    reg fast_update=0;
    reg signed [31:0] fast_target=0,fast_actual=0;
    wire [9:0] fast_duty_pi,fast_duty;
    wire signed [31:0] fast_error,fast_integral;
    PI_controller_fast fast_pi (
        .clk(clk),.rst_n(rst_n),.target_rpm(fast_target),
        .actual_rpm(fast_actual),.update_en(fast_update),
        .duty_pi(fast_duty_pi),.duty(fast_duty),.error(fast_error),
        .integral(fast_integral));

    reg follow_enable=0;
    reg [15:0] follow_distance=1000;
    reg follow_distance_valid=1;
    wire signed [31:0] follow_l,follow_r;
    wire follow_ld,follow_rd;
    wire [2:0] follow_state;
    target_follow_controller follow (
        .enable(follow_enable),.target_valid(target_valid),
        .target_center_x(target_x),.distance_mm(follow_distance),
        .distance_valid(follow_distance_valid),.left_target_rpm(follow_l),
        .right_target_rpm(follow_r),.left_dir(follow_ld),.right_dir(follow_rd),
        .follow_state(follow_state));

    reg route_enable=0,route_distance_valid=0,route_imu_valid=0;
    reg [15:0] route_distance=1000;
    reg signed [15:0] route_yaw=0;
    reg signed [31:0] route_lcount=0,route_rcount=0;
    wire signed [31:0] route_l,route_r;
    wire route_ld,route_rd;
    wire [3:0] route_state;
    wire route_complete;
    waypoint_navigation_controller #(.CLK_FREQ(1000),.LEG1_COUNTS(10),
        .LEG2_COUNTS(10),.BYPASS_COUNTS(4),.BRAKE_TIME_MS(2)) route (
        .clk(clk),.rst_n(rst_n),.enable(route_enable),
        .distance_mm(route_distance),.distance_valid(route_distance_valid),
        .yaw_cdeg(route_yaw),.imu_valid(route_imu_valid),
        .left_count(route_lcount),.right_count(route_rcount),
        .left_target_rpm(route_l),.right_target_rpm(route_r),
        .left_dir(route_ld),.right_dir(route_rd),.nav_state(route_state),
        .route_complete(route_complete));

    initial begin
        repeat(2) tick; rst_n=1; tick;

        command=8'h18; command_valid=1; tick;
        check(drive_mode==3'd1 && remote_start,"remote 2 selects forward and starts");
        command_valid=0; tick;
        command=8'h1c; command_valid=1; tick;
        check(remote_stop,"remote 5 emits stop");
        command_valid=0; tick;

        ramp_enable=1; ramp_target_l=6; ramp_target_r=6; tick;
        check(ramp_l==6 && ramp_r==6,"RPM ramp accelerates to requested target");
        ramp_target_ld=1; ramp_target_rd=1; tick;
        check(ramp_l==0 && ramp_r==0 && !ramp_ld && !ramp_rd,
              "RPM ramp reaches zero before reversing direction");
        tick;
        check(ramp_ld && ramp_rd,"RPM ramp changes direction only at zero speed");

        fast_target=60; fast_actual=40; fast_update=1; tick;
        fast_update=0; tick;
        check(fast_error==20 && fast_duty>=120,
              "timing-oriented PI produces bounded positive motor duty");
        fast_target=0; fast_update=1; tick; fast_update=0; tick;
        check(fast_duty==0 && fast_integral==0,
              "timing-oriented PI clears output and integral at stop");

        // A saturated green channel must not wrap and look red.
        pixel_valid=1; red=250; green=250; blue=0; pixel_x=1; pixel_y=1; tick;
        red=200; green=20; blue=20;
        pixel_x=620; pixel_y=200; tick;
        pixel_x=640; pixel_y=220; tick;
        pixel_x=660; pixel_y=240; tick;
        pixel_valid=0; tick;
        frame_sync=1; tick; frame_sync=0; tick;
        check(target_valid && target_pixels==3,"red target detector counts qualified pixels");
        check(target_x==640 && target_y==220,"red target detector reports bounding-box centre");

        follow_enable=1; follow_distance=1000; #1;
        check(follow_state==3 && follow_l>0 && follow_r>0,
              "centred red target commands approach");
        follow_distance=300; #1;
        check(follow_state==4 && follow_l==0 && follow_r==0,
              "target follow stops at safe range");

        route_enable=1; route_imu_valid=1; tick;
        route_imu_valid=0; tick;
        check(route_state==2 && route_l>0 && route_r>0,"route locks initial heading and drives");
        route_lcount=4; route_rcount=4; tick;
        route_distance=300; route_distance_valid=1; tick;
        check(route_state==3 && route_l==0 && route_r==0,"route brakes for obstacle");
        repeat(2) tick;
        check(route_state==4,"route enters avoidance turn after brake dwell");
        route_yaw=9000; route_distance=700; tick;
        check(route_state==5,"route turns to bypass heading when path clears");
        route_lcount=8; route_rcount=8; tick;
        check(route_state==6,"route advances measured bypass distance");
        route_yaw=0; tick;
        check(route_state==2,"route restores original heading after bypass");
        route_distance_valid=0; route_lcount=14; route_rcount=14; tick;
        check(route_state==7,"route resumes only the saved remaining leg distance");

        if(failures==0) $display("PASS remote modes, closed-loop ramp, red target follow, and route navigation");
        else $fatal(1,"%0d advanced feature checks failed",failures);
        $finish;
    end
endmodule
