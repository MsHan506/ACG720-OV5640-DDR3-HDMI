`timescale 1ns/1ps

module wheel_rpm_monitor_1480_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg signed [31:0] count = 0;
    wire signed [31:0] rpm;
    wire update_en;
    always #5 clk = ~clk;

    wheel_rpm_monitor_1480 #(.CLK_FREQ(1000)) dut (
        .clk(clk), .rst_n(rst_n), .count(count),
        .rpm(rpm), .update_en(update_en));

    initial begin
        repeat (3) @(posedge clk); rst_n = 1'b1;
        count = 32'sd148;
        wait (update_en); #1;
        if (rpm != 32'sd60) $fatal(1, "148 counts/100ms must be 60 RPM");
        count = 32'sd0;
        wait (!update_en);
        wait (update_en); #1;
        if (rpm != -32'sd60) $fatal(1, "reverse RPM sign must be preserved");
        $display("PASS timing-safe measured-CPR RPM monitor");
        $finish;
    end
endmodule

