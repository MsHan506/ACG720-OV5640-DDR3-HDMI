`timescale 1ns/1ps

module safe_motor_command_ramp_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg enable = 1'b0;
    reg [9:0] target_duty = 10'd0;
    reg target_left_dir = 1'b0;
    reg target_right_dir = 1'b0;
    wire [9:0] duty;
    wire left_dir;
    wire right_dir;

    safe_motor_command_ramp #(
        .CLK_FREQ(1000), .UPDATE_MS(10),
        .ACCEL_STEP(10'd10), .DECEL_STEP(10'd20)
    ) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .target_duty(target_duty),
        .target_left_dir(target_left_dir),
        .target_right_dir(target_right_dir),
        .duty(duty), .left_dir(left_dir), .right_dir(right_dir));

    always #5 clk = ~clk;

    task wait_update;
        integer i;
        begin
            for (i = 0; i < 10; i = i + 1)
                @(posedge clk);
            #1;
        end
    endtask

    task check_outputs;
        input [9:0] expected_duty;
        input expected_left;
        input expected_right;
        begin
            if ((duty !== expected_duty) ||
                (left_dir !== expected_left) ||
                (right_dir !== expected_right)) begin
                $display("FAIL duty=%0d left=%0b right=%0b expected=%0d/%0b/%0b",
                    duty, left_dir, right_dir,
                    expected_duty, expected_left, expected_right);
                $fatal(1);
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        enable = 1'b1;
        target_duty = 10'd40;

        wait_update; check_outputs(10, 0, 0);
        wait_update; check_outputs(20, 0, 0);
        wait_update; check_outputs(30, 0, 0);
        wait_update; check_outputs(40, 0, 0);

        // A requested reversal must decelerate to zero first.
        target_duty = 10'd30;
        target_right_dir = 1'b1;
        wait_update; check_outputs(20, 0, 0);
        wait_update; check_outputs(0, 0, 0);
        wait_update; check_outputs(0, 0, 1);
        wait_update; check_outputs(10, 0, 1);

        // Stop is immediate and does not wait for the next update interval.
        @(negedge clk);
        enable = 1'b0;
        @(posedge clk); #1;
        check_outputs(0, 0, 1);

        $display("PASS safe motor command ramp");
        $finish;
    end
endmodule
