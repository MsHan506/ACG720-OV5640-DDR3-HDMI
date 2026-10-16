`timescale 1ns / 1ps

// Complete B-role top level for the ACG720 board.
// The camera/display path is the board vendor's reference design.  The two
// UART sensors and the telemetry link run independently from the same 50 MHz
// board clock, so a camera fault cannot stop distance/attitude acquisition.
module b_full_top (
    input  wire        clk50M,
    input  wire        reset_n,
    input  wire        motor_start_n,
    input  wire        motor_stop_n,
    input  wire        ir_rx,

    input  wire        tof_uart_rx,
    input  wire        imu_uart_rx,
    output wire        sensor_uart_tx,

    input  wire        motor_e1a,
    input  wire        motor_e1b,
    input  wire        motor_e2a,
    input  wire        motor_e2b,
    output wire        motor_pwm1,
    output wire        motor_ain1,
    output wire        motor_ain2,
    output wire        motor_pwm2,
    output wire        motor_bin1,
    output wire        motor_bin2,
    output wire        motor_stby,

    output wire        camera_sclk,
    inout  wire        camera_sdat,
    input  wire        camera_vsync,
    input  wire        camera_href,
    input  wire        camera_pclk,
    output wire        camera_xclk,
    input  wire [7:0]  camera_data,
    output wire        camera_rst_n,
    output wire        camera_pwdn,

    output wire [8:0]  led,

    output wire        tmds_clk_p,
    output wire        tmds_clk_n,
    output wire [2:0]  tmds_data_p,
    output wire [2:0]  tmds_data_n,

    output wire [13:0] O_ddr_addr,
    output wire [2:0]  O_ddr_ba,
    output wire        O_ddr_cs_n,
    output wire        O_ddr_ras_n,
    output wire        O_ddr_cas_n,
    output wire        O_ddr_we_n,
    output wire        O_ddr_clk,
    output wire        O_ddr_clk_n,
    output wire        O_ddr_cke,
    output wire        O_ddr_odt,
    output wire        O_ddr_reset_n,
    output wire [1:0]  O_ddr_dqm,
    inout  wire [15:0] IO_ddr_dq,
    inout  wire [1:0]  IO_ddr_dqs,
    inout  wire [1:0]  IO_ddr_dqs_n
);
    wire [3:0] camera_status_led;
    wire [15:0] front_distance_mm;
    wire [15:0] tof_strength;
    wire signed [15:0] roll_cdeg;
    wire signed [15:0] pitch_cdeg;
    wire signed [15:0] yaw_cdeg;
    wire distance_valid;
    wire imu_valid;
    wire [15:0] tof_error_count;
    wire [15:0] imu_error_count;
    reg tof_seen;
    reg imu_seen;
    wire signed [31:0] motor_e1_rpm;
    wire signed [31:0] motor_e2_rpm;
    wire signed [31:0] motor_e1_count;
    wire signed [31:0] motor_e2_count;
    wire [1:0] motion_state;
    wire [1:0] display_motion_state;
    wire drive_enable;
    wire [7:0] ir_address;
    wire [7:0] ir_command;
    wire ir_command_valid;
    wire remote_start_pulse;
    wire remote_stop_pulse;
    wire [2:0] remote_drive_mode;
    wire [2:0] drive_mode;
    wire telemetry_frame_done;
    wire telemetry_frame_toggle;
    reg [31:0] range_age;
    reg range_fresh;
    localparam integer RANGE_FRESH_CYCLES = 25_000_000; // 500 ms @ 50 MHz
    // Forward/autonomous starts require clear space.  Reverse remains
    // available as an escape command when an obstacle is already close.
    wire start_allowed = range_fresh &&
        ((drive_mode==3'd2) || (front_distance_mm >= 16'd500));

    wire logical_left_pwm;
    wire logical_left_in1;
    wire logical_left_in2;
    wire logical_right_pwm;
    wire logical_right_in1;
    wire logical_right_in2;
    wire motion_left_dir;
    wire motion_right_dir;
    wire signed [31:0] motion_left_target;
    wire signed [31:0] motion_right_target;
    wire signed [31:0] manual_left_target;
    wire signed [31:0] manual_right_target;
    wire manual_left_dir,manual_right_dir;
    wire [1:0] manual_display_state;
    wire signed [31:0] route_left_target,route_right_target;
    wire route_left_dir,route_right_dir;
    wire [3:0] route_state;
    wire route_complete;
    wire signed [31:0] follow_left_target,follow_right_target;
    wire follow_left_dir,follow_right_dir;
    wire [2:0] follow_state;
    wire target_valid;
    wire [11:0] target_center_x,target_center_y;
    wire [23:0] target_pixel_count;
    wire target_valid_sync;
    wire [11:0] target_x_sync;
    reg signed [31:0] selected_left_target,selected_right_target;
    reg selected_left_dir,selected_right_dir;
    reg [1:0] selected_display_state;
    wire signed [31:0] shaped_left_target,shaped_right_target;
    wire shaped_left_dir,shaped_right_dir;
    wire raw_left_pwm;
    wire raw_right_pwm;
    wire raw_left_in1;
    wire raw_left_in2;
    wire raw_right_in1;
    wire raw_right_in2;
    wire drive_output_enable = drive_enable &&
        ((selected_left_target != 0) || (selected_right_target != 0));

    nec_ir_decoder #(.CLK_FREQ(50_000_000)) u_ir_decoder (
        .clk(clk50M), .rst_n(reset_n), .ir_rx(ir_rx),
        .command_valid(ir_command_valid), .address(ir_address),
        .command(ir_command));

    remote_drive_commands u_remote_commands (
        .clk(clk50M), .rst_n(reset_n),
        .command_valid(ir_command_valid), .command(ir_command),
        .start_pulse(remote_start_pulse), .stop_pulse(remote_stop_pulse),
        .drive_mode(remote_drive_mode));

    // RK3588 transport is output-only in this build. Local IR control remains
    // independent from HDMI and from the external USB-to-TTL telemetry link.
    assign drive_mode = remote_drive_mode;

    safe_start_stop_latch #(
        .CLK_FREQ(50_000_000), .DEBOUNCE_MS(20)
    ) u_drive_latch (
        .clk(clk50M), .rst_n(reset_n),
        .start_button_n(motor_start_n), .stop_button_n(motor_stop_n),
        .remote_start_pulse(remote_start_pulse),
        .remote_stop_pulse(remote_stop_pulse),
        .start_allowed(start_allowed), .enabled(drive_enable));

    autonomous_motion_controller #(
        .CLK_FREQ(50_000_000),
        .STOP_DISTANCE_MM(350), .CLEAR_DISTANCE_MM(500),
        .FORWARD_RPM(60), .TURN_RPM(45), .TURN_TIME_MS(600),
        .SENSOR_WATCHDOG_MS(500)
    ) u_motion (
        .clk(clk50M), .rst_n(reset_n), .enable(drive_enable),
        .distance_mm(front_distance_mm),
        .distance_valid(distance_valid),
        .left_target_rpm(motion_left_target),
        .right_target_rpm(motion_right_target),
        .left_dir(motion_left_dir), .right_dir(motion_right_dir),
        .motion_state(motion_state));

    manual_motion_commands u_manual_commands (
        .mode(drive_mode), .left_target_rpm(manual_left_target),
        .right_target_rpm(manual_right_target), .left_dir(manual_left_dir),
        .right_dir(manual_right_dir), .display_state(manual_display_state));

    waypoint_navigation_controller #(.CLK_FREQ(50_000_000)) u_route (
        .clk(clk50M), .rst_n(reset_n),
        .enable(drive_enable && drive_mode==3'd5),
        .distance_mm(front_distance_mm), .distance_valid(distance_valid),
        .yaw_cdeg(yaw_cdeg), .imu_valid(imu_valid),
        .left_count(motor_e2_count), .right_count(motor_e1_count),
        .left_target_rpm(route_left_target),
        .right_target_rpm(route_right_target),
        .left_dir(route_left_dir), .right_dir(route_right_dir),
        .nav_state(route_state), .route_complete(route_complete));

    target_follow_controller u_target_follow (
        .enable(drive_enable && drive_mode==3'd6),
        .target_valid(target_valid_sync), .target_center_x(target_x_sync),
        .distance_mm(front_distance_mm), .distance_valid(distance_valid),
        .left_target_rpm(follow_left_target),
        .right_target_rpm(follow_right_target),
        .left_dir(follow_left_dir), .right_dir(follow_right_dir),
        .follow_state(follow_state));

    // Coherent target coordinates arrive through the camera's CDC mailbox.

    always @(*) begin
        selected_left_target=0; selected_right_target=0;
        selected_left_dir=0; selected_right_dir=0;
        selected_display_state=0;
        case(drive_mode)
            3'd0: begin
                selected_left_target=motion_left_target;
                selected_right_target=motion_right_target;
                selected_left_dir=motion_left_dir;
                selected_right_dir=motion_right_dir;
                selected_display_state=motion_state;
            end
            3'd1,3'd2,3'd3,3'd4: begin
                selected_left_target=manual_left_target;
                selected_right_target=manual_right_target;
                selected_left_dir=manual_left_dir;
                selected_right_dir=manual_right_dir;
                selected_display_state=manual_display_state;
            end
            3'd5: begin
                selected_left_target=route_left_target;
                selected_right_target=route_right_target;
                selected_left_dir=route_left_dir;
                selected_right_dir=route_right_dir;
                selected_display_state=(route_state==4'd2 || route_state==4'd5)?2'd1:
                    ((route_state==4'd1 || route_state==4'd4 || route_state==4'd6)?2'd2:2'd0);
            end
            3'd6: begin
                selected_left_target=follow_left_target;
                selected_right_target=follow_right_target;
                selected_left_dir=follow_left_dir;
                selected_right_dir=follow_right_dir;
                selected_display_state=(follow_state==3'd3)?2'd1:
                    ((follow_state<=3'd2)?2'd2:2'd0);
            end
            default: begin end
        endcase
    end
    assign display_motion_state=selected_display_state;

    dual_rpm_command_ramp #(.CLK_FREQ(50_000_000)) u_rpm_ramp (
        .clk(clk50M), .rst_n(reset_n), .enable(drive_enable),
        .target_left_rpm(selected_left_target),
        .target_right_rpm(selected_right_target),
        .target_left_dir(selected_left_dir),
        .target_right_dir(selected_right_dir),
        .left_rpm(shaped_left_target), .right_rpm(shaped_right_target),
        .left_dir(shaped_left_dir), .right_dir(shaped_right_dir));

    dual_motor_control #(
        .CLK_FREQ(50_000_000), .PWM_FREQ(20_000),
        .COUNTS_PER_REV(1480), .SAMPLE_TIME_MS(20),
        // Power-of-two scaling implements P=1 and I=1/64 using shifts,
        // avoiding a long fabric divider in the 50 MHz feedback path.
        .KP(1024), .KI(16), .SCALE(1024),
        .OUT_MAX(260), .I_MAX(200000), .DEAD_ZONE(120), .DUTY_MAX(360),
        .FAST_PI(1)
    ) u_closed_loop_motors (
        .clk(clk50M), .rst_n(reset_n),
        .left_target_rpm(shaped_left_target),
        .right_target_rpm(shaped_right_target),
        .left_dir(shaped_left_dir), .right_dir(shaped_right_dir),
        .left_enc_a(motor_e2a), .left_enc_b(motor_e2b),
        .right_enc_a(motor_e1a), .right_enc_b(motor_e1b),
        .left_pwm(raw_left_pwm), .left_in1(raw_left_in1),
        .left_in2(raw_left_in2), .right_pwm(raw_right_pwm),
        .right_in1(raw_right_in1), .right_in2(raw_right_in2),
        .left_encoder_count(motor_e2_count),
        .right_encoder_count(motor_e1_count),
        .left_actual_rpm(motor_e2_rpm),
        .right_actual_rpm(motor_e1_rpm),
        .left_duty(), .right_duty(), .left_error(), .right_error());

    tb6612_dual_safe_adapter #(
        .CLK_FREQ(50_000_000), .DEADTIME_US(2000),
        // Ground observation corrected on 2026-10-02: electrical "forward"
        // drove both sides backward, so reverse both physical channels.
        .CH1_REVERSED(1), .CH2_REVERSED(1)
    ) u_driver_adapter (
        .clk(clk50M), .rst_n(reset_n), .enable(drive_output_enable),
        .ch1_pwm_in(raw_left_pwm), .ch1_in1_in(raw_left_in1),
        .ch1_in2_in(raw_left_in2), .ch2_pwm_in(raw_right_pwm),
        .ch2_in1_in(raw_right_in1), .ch2_in2_in(raw_right_in2),
        .driver_stby(motor_stby),
        .ch1_pwm(logical_left_pwm), .ch1_in1(logical_left_in1),
        .ch1_in2(logical_left_in2), .ch2_pwm(logical_right_pwm),
        .ch2_in1(logical_right_in1), .ch2_in2(logical_right_in2));

    assign motor_pwm2 = logical_left_pwm;
    assign motor_bin1 = logical_left_in1;
    assign motor_bin2 = logical_left_in2;
    assign motor_pwm1 = logical_right_pwm;
    assign motor_ain1 = logical_right_in1;
    assign motor_ain2 = logical_right_in2;

    // Complete build: live camera + sensor OSD + target box through the true
    // HDMI VIC-4 transmitter.  Both selectors remain parameters in the child
    // module so the known legacy DVI path and fixed bars remain available.
    gao_ov5640_ddr_hdmi #(
        .HDMI_TRUE_MODE(1'b1),
        .HDMI_TEST_PATTERN(1'b0)
    ) u_camera_display (
        .clk50M(clk50M), .reset_n(reset_n),
        .camera_sclk(camera_sclk), .camera_sdat(camera_sdat),
        .camera_vsync(camera_vsync), .camera_href(camera_href),
        .camera_pclk(camera_pclk), .camera_xclk(camera_xclk),
        .camera_data(camera_data), .camera_rst_n(camera_rst_n),
        .camera_pwdn(camera_pwdn), .led(camera_status_led),
        .distance_mm(front_distance_mm),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg),
        .yaw_cdeg(yaw_cdeg),
        .drive_unlocked(drive_enable),
        .motion_state(display_motion_state),
        .show_encoder_counts(1'b0),
        .left_rpm(motor_e2_rpm), .right_rpm(motor_e1_rpm),
        .target_valid(target_valid), .target_center_x(target_center_x),
        .target_control_valid(target_valid_sync), .target_control_x(target_x_sync),
        .target_center_y(target_center_y),
        .target_pixel_count(target_pixel_count),
        .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p), .tmds_data_n(tmds_data_n),
        .O_ddr_addr(O_ddr_addr), .O_ddr_ba(O_ddr_ba),
        .O_ddr_cs_n(O_ddr_cs_n), .O_ddr_ras_n(O_ddr_ras_n),
        .O_ddr_cas_n(O_ddr_cas_n), .O_ddr_we_n(O_ddr_we_n),
        .O_ddr_clk(O_ddr_clk), .O_ddr_clk_n(O_ddr_clk_n),
        .O_ddr_cke(O_ddr_cke), .O_ddr_odt(O_ddr_odt),
        .O_ddr_reset_n(O_ddr_reset_n), .O_ddr_dqm(O_ddr_dqm),
        .IO_ddr_dq(IO_ddr_dq), .IO_ddr_dqs(IO_ddr_dqs),
        .IO_ddr_dqs_n(IO_ddr_dqs_n)
    );

    perception_hub u_perception (
        .clk(clk50M), .rst_n(reset_n),
        .tof_uart_rx(tof_uart_rx), .imu_uart_rx(imu_uart_rx),
        .front_distance_mm(front_distance_mm), .tof_strength(tof_strength),
        .distance_valid(distance_valid),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg),
        .yaw_cdeg(yaw_cdeg), .imu_valid(imu_valid),
        .tof_error_count(tof_error_count),
        .imu_error_count(imu_error_count)
    );

    sensor_telemetry_tx_v3 #(
        .CLK_FREQ(50_000_000), .BAUD_RATE(115_200), .REPORT_HZ(20),
        .FRESH_MS(500)
    ) u_sensor_telemetry (
        .clk(clk50M), .rst_n(reset_n),
        .distance_mm(front_distance_mm), .tof_strength(tof_strength),
        .distance_valid(distance_valid),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg),
        .yaw_cdeg(yaw_cdeg), .imu_valid(imu_valid),
        .tof_error_count(tof_error_count),
        .imu_error_count(imu_error_count),
        .uart_tx_pin(sensor_uart_tx),
        .frame_done(telemetry_frame_done),
        .frame_toggle(telemetry_frame_toggle)
    );

    always @(posedge clk50M or negedge reset_n) begin
        if (!reset_n) begin
            tof_seen <= 1'b0;
            imu_seen <= 1'b0;
            range_age <= 32'd0;
            range_fresh <= 1'b0;
        end else begin
            if (distance_valid) begin
                tof_seen <= 1'b1;
                range_age <= 32'd0;
                range_fresh <= 1'b1;
            end else if (range_age < RANGE_FRESH_CYCLES - 1) begin
                range_age <= range_age + 1'b1;
            end else begin
                range_fresh <= 1'b0;
            end
            if (imu_valid)      imu_seen <= 1'b1;
        end
    end

    assign led[3:0] = camera_status_led;
    assign led[4]   = tof_seen;
    assign led[5]   = imu_seen;
    // LED6 toggles on each completed telemetry frame. LED7 reports any
    // sensor-parser error, keeping the physical link status observable.
    assign led[6]   = telemetry_frame_toggle;
    assign led[7]   = (tof_error_count != 16'd0) ||
                      (imu_error_count != 16'd0);
    assign led[8]   = drive_enable;
endmodule
