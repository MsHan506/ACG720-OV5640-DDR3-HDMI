`timescale 1ns / 1ps

module tb_tfmini_s_parser;
    reg clk = 0;
    reg rst_n = 0;
    reg [7:0] rx_data = 0;
    reg rx_valid = 0;
    wire [15:0] distance_cm;
    wire [15:0] distance_mm;
    wire [15:0] strength;
    wire frame_valid;
    wire measurement_valid;
    wire checksum_error;
    integer valid_count = 0;
    integer measurement_count = 0;
    integer error_count = 0;

    tfmini_s_parser dut (.*);
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (frame_valid) valid_count <= valid_count + 1;
        if (measurement_valid) measurement_count <= measurement_count + 1;
        if (checksum_error) error_count <= error_count + 1;
    end

    task push;
        input [7:0] value;
        begin
            @(negedge clk); rx_data = value; rx_valid = 1;
            @(negedge clk); rx_valid = 0;
        end
    endtask

    task good_frame;
        begin
            push(8'h59); push(8'h59); push(8'h7B); push(8'h00);
            push(8'hF4); push(8'h01); push(8'h00); push(8'h00); push(8'h22);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk); rst_n = 1;
        good_frame(); repeat (3) @(posedge clk);
        if (valid_count != 1 || measurement_count != 1 ||
            distance_cm != 123 || distance_mm != 1230 || strength != 500) begin
            $display("FAIL TFmini valid frame"); $finish;
        end
        push(8'h59); push(8'h59); push(8'h7B); push(8'h00);
        push(8'hF4); push(8'h01); push(8'h00); push(8'h00); push(8'h23);
        repeat (3) @(posedge clk);
        if (error_count != 1 || valid_count != 1)
            $display("FAIL TFmini checksum");
        else
            $display("PASS tb_tfmini_s_parser");
        $finish;
    end
endmodule

