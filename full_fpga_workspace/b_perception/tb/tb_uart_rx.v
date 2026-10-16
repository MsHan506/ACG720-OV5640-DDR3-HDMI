`timescale 1ns / 1ps

module tb_uart_rx;
    localparam CLK_FREQ = 10_000_000;
    localparam BAUD_RATE = 1_000_000;
    localparam BIT_CLKS = CLK_FREQ / BAUD_RATE;

    reg clk = 0;
    reg rst_n = 0;
    reg rx = 1;
    wire [7:0] data;
    wire done;
    wire frame_error;
    integer i;
    integer done_count = 0;
    integer error_count = 0;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .rst_n(rst_n), .rx(rx),
        .data(data), .done(done), .frame_error(frame_error)
    );

    always #50 clk = ~clk;
    always @(posedge clk) begin
        if (done) done_count <= done_count + 1;
        if (frame_error) error_count <= error_count + 1;
    end

    task send_byte;
        input [7:0] value;
        input stop_value;
        begin
            rx = 0; repeat (BIT_CLKS) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                rx = value[i]; repeat (BIT_CLKS) @(posedge clk);
            end
            rx = stop_value; repeat (BIT_CLKS) @(posedge clk);
            rx = 1; repeat (BIT_CLKS) @(posedge clk);
        end
    endtask

    initial begin
        repeat (5) @(posedge clk); rst_n = 1;
        repeat (5) @(posedge clk);
        send_byte(8'hA5, 1'b1);
        repeat (5) @(posedge clk);
        if (done_count != 1 || data != 8'hA5) begin
            $display("FAIL uart good frame"); $finish;
        end
        send_byte(8'h3C, 1'b0);
        repeat (5) @(posedge clk);
        if (error_count != 1 || done_count != 1)
            $display("FAIL uart stop-bit check");
        else
            $display("PASS tb_uart_rx");
        $finish;
    end
endmodule

