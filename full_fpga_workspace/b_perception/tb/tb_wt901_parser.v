`timescale 1ns / 1ps

module tb_wt901_parser;
    reg clk = 0;
    reg rst_n = 0;
    reg [7:0] rx_data = 0;
    reg rx_valid = 0;
    wire signed [15:0] roll_raw, pitch_raw, yaw_raw;
    wire signed [15:0] roll_cdeg, pitch_cdeg, yaw_cdeg;
    wire angle_valid, checksum_error;
    integer valid_count = 0;
    integer error_count = 0;

    wt901_parser dut (.*);
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (angle_valid) valid_count <= valid_count + 1;
        if (checksum_error) error_count <= error_count + 1;
    end

    task push;
        input [7:0] value;
        begin
            @(negedge clk); rx_data = value; rx_valid = 1;
            @(negedge clk); rx_valid = 0;
        end
    endtask

    initial begin
        repeat (4) @(negedge clk); rst_n = 1;
        // roll=+90°, pitch=-45°, yaw=+45°, checksum=E8.
        push(8'h55); push(8'h53);
        push(8'h00); push(8'h40); push(8'h00); push(8'hE0);
        push(8'h00); push(8'h20); push(8'h00); push(8'h00); push(8'hE8);
        repeat (3) @(posedge clk);
        if (valid_count != 1 || roll_cdeg != 9000 ||
            pitch_cdeg != -4500 || yaw_cdeg != 4500) begin
            $display("FAIL WT901 angle frame %0d %0d %0d",
                     roll_cdeg, pitch_cdeg, yaw_cdeg); $finish;
        end

        push(8'h55); push(8'h53);
        push(8'h00); push(8'h40); push(8'h00); push(8'hE0);
        push(8'h00); push(8'h20); push(8'h00); push(8'h00); push(8'hE9);
        repeat (3) @(posedge clk);
        if (error_count != 1 || valid_count != 1)
            $display("FAIL WT901 checksum");
        else
            $display("PASS tb_wt901_parser");
        $finish;
    end
endmodule

