`timescale 1ns/1ps

module tb_perception_hub_dualbaud;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg tof_uart_rx = 1'b1;
    reg imu_uart_rx = 1'b1;
    wire signed [15:0] roll_cdeg;
    wire signed [15:0] pitch_cdeg;
    wire signed [15:0] yaw_cdeg;
    wire imu_valid;

    always #50 clk = ~clk; // 10 MHz

    perception_hub #(
        .CLK_FREQ(10_000_000),
        .TOF_BAUD(115_200),
        .IMU_BAUD(9_600),
        .IMU_BAUD_ALT(115_200),
        .ANGLE_LPF_SHIFT(2)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .tof_uart_rx(tof_uart_rx), .imu_uart_rx(imu_uart_rx),
        .front_distance_mm(), .tof_strength(), .distance_valid(),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg),
        .yaw_cdeg(yaw_cdeg), .imu_valid(imu_valid),
        .tof_error_count(), .imu_error_count()
    );

    task send_uart_byte;
        input [7:0] value;
        input integer bit_ns;
        integer i;
        begin
            imu_uart_rx = 1'b0;
            #(bit_ns);
            for (i = 0; i < 8; i = i + 1) begin
                imu_uart_rx = value[i];
                #(bit_ns);
            end
            imu_uart_rx = 1'b1;
            #(bit_ns);
        end
    endtask

    task send_angle_frame;
        input integer bit_ns;
        begin
            // roll=0x1000 -> 22.50 deg, pitch=0x2000 -> 45.00 deg,
            // yaw=0xE000 -> -45.00 deg. Checksum is 0xB8.
            send_uart_byte(8'h55, bit_ns);
            send_uart_byte(8'h53, bit_ns);
            send_uart_byte(8'h00, bit_ns);
            send_uart_byte(8'h10, bit_ns);
            send_uart_byte(8'h00, bit_ns);
            send_uart_byte(8'h20, bit_ns);
            send_uart_byte(8'h00, bit_ns);
            send_uart_byte(8'hE0, bit_ns);
            send_uart_byte(8'h00, bit_ns);
            send_uart_byte(8'h00, bit_ns);
            send_uart_byte(8'hB8, bit_ns);
        end
    endtask

    task expect_angles;
        begin
            @(posedge imu_valid);
            #100;
            if (roll_cdeg !== 16'sd2250 ||
                pitch_cdeg !== 16'sd4500 ||
                yaw_cdeg !== -16'sd4500) begin
                $display("FAIL dual-baud angles: roll=%0d pitch=%0d yaw=%0d",
                    roll_cdeg, pitch_cdeg, yaw_cdeg);
                $fatal(1);
            end
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        fork
            send_angle_frame(104167); // 9600 baud
            expect_angles();
        join

        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        fork
            send_angle_frame(8681); // 115200 baud
            expect_angles();
        join

        $display("PASS WT901 automatic 9600/115200 baud reception");
        $finish;
    end
endmodule
