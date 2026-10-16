`timescale 1ns/1ps

module tb6612_quad_safe_adapter_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg enable = 1'b0;
    reg m1_pwm_in = 1'b1, m1_in1_in = 1'b1, m1_in2_in = 1'b0;
    reg m2_pwm_in = 1'b1, m2_in1_in = 1'b1, m2_in2_in = 1'b0;
    reg m3_pwm_in = 1'b1, m3_in1_in = 1'b1, m3_in2_in = 1'b0;
    reg m4_pwm_in = 1'b1, m4_in1_in = 1'b1, m4_in2_in = 1'b0;
    wire driver_stby;
    wire m1_pwm, m1_in1, m1_in2, m2_pwm, m2_in1, m2_in2;
    wire m3_pwm, m3_in1, m3_in2, m4_pwm, m4_in1, m4_in2;
    always #5 clk = ~clk;

    tb6612_quad_safe_adapter #(
        .CLK_FREQ(1_000_000), .DEADTIME_US(4), .M4_REVERSED(1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .m1_pwm_in(m1_pwm_in), .m1_in1_in(m1_in1_in), .m1_in2_in(m1_in2_in),
        .m2_pwm_in(m2_pwm_in), .m2_in1_in(m2_in1_in), .m2_in2_in(m2_in2_in),
        .m3_pwm_in(m3_pwm_in), .m3_in1_in(m3_in1_in), .m3_in2_in(m3_in2_in),
        .m4_pwm_in(m4_pwm_in), .m4_in1_in(m4_in1_in), .m4_in2_in(m4_in2_in),
        .driver_stby(driver_stby),
        .m1_pwm(m1_pwm), .m1_in1(m1_in1), .m1_in2(m1_in2),
        .m2_pwm(m2_pwm), .m2_in1(m2_in1), .m2_in2(m2_in2),
        .m3_pwm(m3_pwm), .m3_in1(m3_in1), .m3_in2(m3_in2),
        .m4_pwm(m4_pwm), .m4_in1(m4_in1), .m4_in2(m4_in2)
    );

    task expect_disabled;
        begin
            if (driver_stby || m1_pwm || m2_pwm || m3_pwm || m4_pwm ||
                m1_in1 || m1_in2 || m2_in1 || m2_in2 ||
                m3_in1 || m3_in2 || m4_in1 || m4_in2) begin
                $display("FAIL TB6612 outputs were not safely disabled");
                $fatal(1);
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        expect_disabled();
        enable = 1'b1;
        repeat (3) begin
            @(posedge clk);
            if (driver_stby) begin
                $display("FAIL standby released before dead time");
                $fatal(1);
            end
        end
        repeat (3) @(posedge clk);
        if (!driver_stby || !m1_pwm || !m2_pwm || !m3_pwm || !m4_pwm ||
            !m1_in1 || m1_in2 || !m2_in1 || m2_in2 ||
            !m3_in1 || m3_in2 || m4_in1 || !m4_in2) begin
            $display("FAIL normal channels or per-motor reversal");
            $fatal(1);
        end
        m3_in1_in = 1'b0;
        m3_in2_in = 1'b1;
        m4_in1_in = 1'b0;
        m4_in2_in = 1'b1;
        @(posedge clk);
        #1;
        expect_disabled();
        repeat (5) @(posedge clk);
        #1;
        if (!driver_stby || !m3_in2 || m3_in1 || m4_in2 || !m4_in1) begin
            $display("FAIL direction-change dead time or new direction");
            $fatal(1);
        end
        enable = 1'b0;
        @(posedge clk);
        #1;
        expect_disabled();
        $display("PASS TB6612 standby, direction dead time, and per-motor reversal");
        $finish;
    end
endmodule
