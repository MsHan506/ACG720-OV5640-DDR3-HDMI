`timescale 1ns / 1ps

module b_sensor_demo_top (
    input  wire       clk_50m,
    input  wire       reset_n,
    input  wire       tof_uart_rx,
    input  wire       imu_uart_rx,
    output wire       sensor_uart_tx,
    output wire [6:0] led
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

    sensor_telemetry_tx_v3 #(
        .CLK_FREQ(50_000_000), .BAUD_RATE(115_200), .REPORT_HZ(20),
        .FRESH_MS(500)
    ) u_telemetry (
        .clk(clk_50m), .rst_n(reset_n),
        .distance_mm(distance_mm), .tof_strength(tof_strength),
        .distance_valid(distance_valid),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg), .yaw_cdeg(yaw_cdeg),
        .imu_valid(imu_valid),
        .tof_error_count(tof_error_count), .imu_error_count(imu_error_count),
        .uart_tx_pin(sensor_uart_tx), .frame_done(), .frame_toggle()
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

    // GW5AT-60B 上 LED0/LED1 复用专用 SSPI 引脚，本工程只使用 LED2..LED8。
    // LED[4:0] 显示距离的 100 mm 单位低五位；LED[5]/LED[6] 表示已收到 TOF/IMU。
    assign distance_hundreds_mm = distance_mm / 16'd100;
    assign led[4:0] = distance_hundreds_mm[4:0];
    assign led[5]   = distance_seen;
    assign led[6]   = imu_seen;
endmodule
