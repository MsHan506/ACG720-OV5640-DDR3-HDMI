`timescale 1ns / 1ps

module perception_hub #(
    parameter CLK_FREQ      = 50_000_000,
    parameter TOF_BAUD      = 115_200,
    parameter IMU_BAUD      = 9_600,
    parameter IMU_BAUD_ALT  = 115_200,
    parameter TOF_MAX_STEP  = 16'd1500,
    parameter ANGLE_LPF_SHIFT = 2
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               tof_uart_rx,
    input  wire               imu_uart_rx,

    output wire [15:0]        front_distance_mm,
    output wire [15:0]        tof_strength,
    output wire               distance_valid,
    output wire signed [15:0] roll_cdeg,
    output wire signed [15:0] pitch_cdeg,
    output wire signed [15:0] yaw_cdeg,
    output wire               imu_valid,
    output reg  [15:0]        tof_error_count,
    output reg  [15:0]        imu_error_count
);
    wire [7:0] tof_byte;
    wire       tof_byte_valid;
    wire       tof_uart_error;
    wire [7:0] imu_byte;
    wire       imu_byte_valid;
    wire       imu_uart_error;
    wire [7:0] imu_byte_alt;
    wire       imu_byte_alt_valid;
    wire       imu_uart_alt_error;

    wire [15:0] tof_distance_cm_raw;
    wire [15:0] tof_distance_mm_raw;
    wire [15:0] tof_strength_raw;
    wire        tof_frame_valid;
    wire        tof_measurement_valid;
    wire        tof_checksum_error;

    wire [15:0] tof_gated;
    wire        tof_gated_valid;
    wire        tof_rejected;

    wire signed [15:0] roll_raw;
    wire signed [15:0] pitch_raw;
    wire signed [15:0] yaw_raw;
    wire signed [15:0] roll_cdeg_raw;
    wire signed [15:0] pitch_cdeg_raw;
    wire signed [15:0] yaw_cdeg_raw;
    wire               imu_angle_valid;
    wire               imu_checksum_error;
    wire signed [15:0] roll_raw_alt;
    wire signed [15:0] pitch_raw_alt;
    wire signed [15:0] yaw_raw_alt;
    wire signed [15:0] roll_cdeg_alt;
    wire signed [15:0] pitch_cdeg_alt;
    wire signed [15:0] yaw_cdeg_alt;
    wire               imu_angle_alt_valid;
    wire               imu_checksum_alt_error;
    wire signed [15:0] roll_cdeg_selected =
        imu_angle_valid ? roll_cdeg_raw : roll_cdeg_alt;
    wire signed [15:0] pitch_cdeg_selected =
        imu_angle_valid ? pitch_cdeg_raw : pitch_cdeg_alt;
    wire signed [15:0] yaw_cdeg_selected =
        imu_angle_valid ? yaw_cdeg_raw : yaw_cdeg_alt;
    wire               imu_angle_selected_valid =
        imu_angle_valid | imu_angle_alt_valid;
    wire               roll_filter_valid;
    wire               pitch_filter_valid;
    wire               yaw_filter_valid;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(TOF_BAUD)) u_tof_uart (
        .clk(clk), .rst_n(rst_n), .rx(tof_uart_rx),
        .data(tof_byte), .done(tof_byte_valid), .frame_error(tof_uart_error)
    );

    tfmini_s_parser u_tof_parser (
        .clk(clk), .rst_n(rst_n),
        .rx_data(tof_byte), .rx_valid(tof_byte_valid),
        .distance_cm(tof_distance_cm_raw),
        .distance_mm(tof_distance_mm_raw),
        .strength(tof_strength_raw),
        .frame_valid(tof_frame_valid),
        .measurement_valid(tof_measurement_valid),
        .checksum_error(tof_checksum_error)
    );

    tof_outlier_gate #(.MAX_STEP_MM(TOF_MAX_STEP), .REBASE_COUNT(3)) u_tof_gate (
        .clk(clk), .rst_n(rst_n),
        .sample_in(tof_distance_mm_raw),
        .sample_valid(tof_measurement_valid),
        .sample_out(tof_gated),
        .output_valid(tof_gated_valid),
        .rejected(tof_rejected)
    );

    moving_average4_unsigned u_tof_average (
        .clk(clk), .rst_n(rst_n),
        .sample_in(tof_gated), .sample_valid(tof_gated_valid),
        .average_out(front_distance_mm), .average_valid(distance_valid)
    );

    assign tof_strength = tof_strength_raw;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(IMU_BAUD)) u_imu_uart (
        .clk(clk), .rst_n(rst_n), .rx(imu_uart_rx),
        .data(imu_byte), .done(imu_byte_valid), .frame_error(imu_uart_error)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(IMU_BAUD_ALT)) u_imu_uart_alt (
        .clk(clk), .rst_n(rst_n), .rx(imu_uart_rx),
        .data(imu_byte_alt), .done(imu_byte_alt_valid),
        .frame_error(imu_uart_alt_error)
    );

    wt901_parser u_imu_parser (
        .clk(clk), .rst_n(rst_n),
        .rx_data(imu_byte), .rx_valid(imu_byte_valid),
        .roll_raw(roll_raw), .pitch_raw(pitch_raw), .yaw_raw(yaw_raw),
        .roll_cdeg(roll_cdeg_raw),
        .pitch_cdeg(pitch_cdeg_raw),
        .yaw_cdeg(yaw_cdeg_raw),
        .angle_valid(imu_angle_valid),
        .checksum_error(imu_checksum_error)
    );

    wt901_parser u_imu_parser_alt (
        .clk(clk), .rst_n(rst_n),
        .rx_data(imu_byte_alt), .rx_valid(imu_byte_alt_valid),
        .roll_raw(roll_raw_alt), .pitch_raw(pitch_raw_alt),
        .yaw_raw(yaw_raw_alt), .roll_cdeg(roll_cdeg_alt),
        .pitch_cdeg(pitch_cdeg_alt), .yaw_cdeg(yaw_cdeg_alt),
        .angle_valid(imu_angle_alt_valid),
        .checksum_error(imu_checksum_alt_error)
    );

    signed_iir_filter #(.SHIFT(ANGLE_LPF_SHIFT)) u_roll_filter (
        .clk(clk), .rst_n(rst_n),
        .sample_in(roll_cdeg_selected),
        .sample_valid(imu_angle_selected_valid),
        .filtered_out(roll_cdeg), .output_valid(roll_filter_valid)
    );

    signed_iir_filter #(.SHIFT(ANGLE_LPF_SHIFT)) u_pitch_filter (
        .clk(clk), .rst_n(rst_n),
        .sample_in(pitch_cdeg_selected),
        .sample_valid(imu_angle_selected_valid),
        .filtered_out(pitch_cdeg), .output_valid(pitch_filter_valid)
    );

    angle_iir_filter #(.SHIFT(ANGLE_LPF_SHIFT)) u_yaw_filter (
        .clk(clk), .rst_n(rst_n),
        .angle_in_cdeg(yaw_cdeg_selected),
        .sample_valid(imu_angle_selected_valid),
        .angle_out_cdeg(yaw_cdeg), .output_valid(yaw_filter_valid)
    );

    assign imu_valid = roll_filter_valid & pitch_filter_valid & yaw_filter_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tof_error_count <= 16'd0;
            imu_error_count <= 16'd0;
        end else begin
            if ((tof_uart_error || tof_checksum_error || tof_rejected) &&
                tof_error_count != 16'hFFFF)
                tof_error_count <= tof_error_count + 1'b1;
            if ((imu_uart_error || imu_uart_alt_error ||
                 imu_checksum_error || imu_checksum_alt_error) &&
                imu_error_count != 16'hFFFF)
                imu_error_count <= imu_error_count + 1'b1;
        end
    end
endmodule

