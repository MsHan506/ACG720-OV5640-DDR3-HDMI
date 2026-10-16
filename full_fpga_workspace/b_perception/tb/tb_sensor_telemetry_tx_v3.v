`timescale 1ns / 1ps

module tb_sensor_telemetry_tx_v3;
    localparam integer CLK_FREQ  = 1_000_000;
    localparam integer BAUD_RATE = 100_000;
    localparam integer BIT_CLKS  = CLK_FREQ / BAUD_RATE;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [15:0] distance_mm = 16'h1234;
    reg [15:0] tof_strength = 16'h5678;
    reg distance_valid = 1'b0;
    reg signed [15:0] roll_cdeg = -16'sd123;
    reg signed [15:0] pitch_cdeg = 16'sd456;
    reg signed [15:0] yaw_cdeg = -16'sd789;
    reg imu_valid = 1'b0;
    reg [15:0] tof_error_count = 16'h0002;
    reg [15:0] imu_error_count = 16'h0003;
    wire tx;
    wire frame_done;
    wire frame_toggle;

    reg [7:0] frame [0:27];
    reg [15:0] crc;
    integer i;
    integer errors = 0;

    always #500 clk = ~clk;

    sensor_telemetry_tx_v3 #(
        .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE),
        .REPORT_HZ(1000), .FRESH_MS(20)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .distance_mm(distance_mm), .tof_strength(tof_strength),
        .distance_valid(distance_valid),
        .roll_cdeg(roll_cdeg), .pitch_cdeg(pitch_cdeg),
        .yaw_cdeg(yaw_cdeg), .imu_valid(imu_valid),
        .tof_error_count(tof_error_count),
        .imu_error_count(imu_error_count),
        .uart_tx_pin(tx), .frame_done(frame_done),
        .frame_toggle(frame_toggle)
    );

    function [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0] data_in;
        integer k;
        reg [15:0] work;
        begin
            work = crc_in ^ {data_in, 8'h00};
            for (k = 0; k < 8; k = k + 1) begin
                if (work[15])
                    work = (work << 1) ^ 16'h1021;
                else
                    work = work << 1;
            end
            crc16_next = work;
        end
    endfunction

    task receive_byte;
        output [7:0] value;
        integer b;
        begin
            @(negedge tx);
            repeat (BIT_CLKS / 2) @(posedge clk);
            #1;
            if (tx !== 1'b0) begin
                $display("ERROR: invalid start bit");
                errors = errors + 1;
            end
            for (b = 0; b < 8; b = b + 1) begin
                repeat (BIT_CLKS) @(posedge clk);
                #1;
                value[b] = tx;
            end
            repeat (BIT_CLKS) @(posedge clk);
            #1;
            if (tx !== 1'b1) begin
                $display("ERROR: invalid stop bit");
                errors = errors + 1;
            end
        end
    endtask

    task check_byte;
        input integer index;
        input [7:0] expected;
        begin
            if (frame[index] !== expected) begin
                $display("ERROR: byte[%0d]=%02x expected=%02x",
                         index, frame[index], expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        distance_valid <= 1'b1;
        imu_valid <= 1'b1;
        @(posedge clk);
        distance_valid <= 1'b0;
        imu_valid <= 1'b0;

        for (i = 0; i < 28; i = i + 1)
            receive_byte(frame[i]);

        check_byte(0, 8'hA5);
        check_byte(1, 8'h5A);
        check_byte(2, 8'h01);
        check_byte(3, 8'h10);
        check_byte(4, 8'd21);
        check_byte(5, 8'h00);
        check_byte(6, 8'h00);
        if ((frame[7] & 8'h3F) !== 8'h3F) begin
            $display("ERROR: status=%02x expected low six bits set", frame[7]);
            errors = errors + 1;
        end
        check_byte(8, 8'h34);
        check_byte(9, 8'h12);
        check_byte(10, 8'h78);
        check_byte(11, 8'h56);
        check_byte(12, 8'h85);
        check_byte(13, 8'hFF);
        check_byte(14, 8'hC8);
        check_byte(15, 8'h01);
        check_byte(16, 8'hEB);
        check_byte(17, 8'hFC);
        check_byte(18, 8'h02);
        check_byte(19, 8'h00);
        check_byte(20, 8'h03);
        check_byte(21, 8'h00);

        crc = 16'hFFFF;
        for (i = 2; i <= 25; i = i + 1)
            crc = crc16_next(crc, frame[i]);
        if ({frame[27], frame[26]} !== crc) begin
            $display("ERROR: CRC received=%04x expected=%04x",
                     {frame[27], frame[26]}, crc);
            errors = errors + 1;
        end

        for (i = 0; i < 28; i = i + 1)
            receive_byte(frame[i]);
        check_byte(5, 8'h01);
        check_byte(6, 8'h00);

        if (errors == 0)
            $display("PASS: two telemetry v3 frames, byte order and CRC verified");
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: timeout");
        $finish;
    end
endmodule

