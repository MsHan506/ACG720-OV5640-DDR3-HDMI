`timescale 1ns / 1ps

module b_sensor_demo_top (
    input  wire       clk_50m,
    input  wire       reset_n,
    input  wire       tof_uart_rx,
    input  wire       imu_uart_rx,
    output wire       pc_uart_tx,
    output wire [8:0] led
);
    wire [15:0] distance_mm;
    wire [15:0] tof_strength;
    wire        distance_valid;
    wire signed [15:0] roll_cdeg;
    wire signed [15:0] pitch_cdeg;
    wire signed [15:0] yaw_cdeg;
    wire        imu_valid;
    wire [15:0] tof_error_count;
    wire [15:0] imu_error_count;

    reg distance_seen;
    reg imu_seen;
    wire [15:0] distance_hundreds_mm;

    perception_hub u_perception_hub (
        .clk(clk_50m), .rst_n(reset_n),
        .tof_uart_rx(tof_uart_rx), .imu_uart_rx(imu_uart_rx),
        .front_distance_mm(distance_mm), .tof_strength(tof_strength),
        .distance_valid(distance_valid),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg), .yaw_cdeg(yaw_cdeg),
        .imu_valid(imu_valid),
        .tof_error_count(tof_error_count), .imu_error_count(imu_error_count)
    );

    telemetry_packet_tx u_telemetry (
        .clk(clk_50m), .rst_n(reset_n),
        .distance_mm(distance_mm),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg), .yaw_cdeg(yaw_cdeg),
        .uart_tx_pin(pc_uart_tx)
    );

    always @(posedge clk_50m or negedge reset_n) begin
        if (!reset_n) begin
            distance_seen <= 1'b0;
            imu_seen      <= 1'b0;
        end else begin
            if (distance_valid)
                distance_seen <= 1'b1;
            if (imu_valid)
                imu_seen <= 1'b1;
        end
    end

    // LED[6:0] 显示距离的 100 mm 单位低七位；LED7/8 表示已收到 TOF/IMU。
    assign distance_hundreds_mm = distance_mm / 16'd100;
    assign led[6:0] = distance_hundreds_mm[6:0];
    assign led[7]   = distance_seen;
    assign led[8]   = imu_seen;
endmodule
