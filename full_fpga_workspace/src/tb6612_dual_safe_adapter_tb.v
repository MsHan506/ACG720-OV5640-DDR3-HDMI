`timescale 1ns/1ps

module tb6612_dual_safe_adapter_tb;
    reg clk = 0, rst_n = 0, enable = 0;
    reg ch1_pwm_in = 1, ch1_in1_in = 1, ch1_in2_in = 0;
    reg ch2_pwm_in = 1, ch2_in1_in = 1, ch2_in2_in = 0;
    wire driver_stby, ch1_pwm, ch1_in1, ch1_in2;
    wire ch2_pwm, ch2_in1, ch2_in2;
    always #5 clk = ~clk;

    tb6612_dual_safe_adapter #(
        .CLK_FREQ(1_000_000), .DEADTIME_US(4), .CH2_REVERSED(1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .ch1_pwm_in(ch1_pwm_in), .ch1_in1_in(ch1_in1_in),
        .ch1_in2_in(ch1_in2_in), .ch2_pwm_in(ch2_pwm_in),
        .ch2_in1_in(ch2_in1_in), .ch2_in2_in(ch2_in2_in),
        .driver_stby(driver_stby), .ch1_pwm(ch1_pwm),
        .ch1_in1(ch1_in1), .ch1_in2(ch1_in2),
        .ch2_pwm(ch2_pwm), .ch2_in1(ch2_in1), .ch2_in2(ch2_in2));

    task expect_disabled;
        begin
            if (driver_stby || ch1_pwm || ch1_in1 || ch1_in2 ||
                ch2_pwm || ch2_in1 || ch2_in2) $fatal(1, "unsafe output");
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk); #1; expect_disabled();
        enable = 1;
        repeat (6) @(posedge clk); #1;
        if (!driver_stby || !ch1_pwm || !ch1_in1 || ch1_in2 ||
            !ch2_pwm || ch2_in1 || !ch2_in2)
            $fatal(1, "enable/deadtime/reversal failed");
        ch1_in1_in = 0; ch1_in2_in = 1;
        @(posedge clk); #1; expect_disabled();
        repeat (5) @(posedge clk); #1;
        if (!driver_stby || ch1_in1 || !ch1_in2)
            $fatal(1, "direction deadtime failed");
        enable = 0;
        @(posedge clk); #1; expect_disabled();
        $display("PASS photographed two-channel TB6612 interface safety");
        $finish;
    end
endmodule
