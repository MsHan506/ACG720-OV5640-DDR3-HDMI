`timescale 1ns/1ps

module autonomous_motion_controller_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg enable = 1'b0;
    reg [15:0] distance_mm = 16'd0;
    reg distance_valid = 1'b0;
    wire signed [31:0] left_target_rpm;
    wire signed [31:0] right_target_rpm;
    wire left_dir;
    wire right_dir;
    wire [1:0] motion_state;
    integer errors = 0;

    autonomous_motion_controller #(
        .CLK_FREQ(1000),
        .STOP_DISTANCE_MM(300),
        .CLEAR_DISTANCE_MM(450),
        .FORWARD_RPM(180),
        .TURN_RPM(140),
        .TURN_TIME_MS(5),
        .BRAKE_TIME_MS(3),
        .SENSOR_WATCHDOG_MS(10)
    ) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .distance_mm(distance_mm), .distance_valid(distance_valid),
        .left_target_rpm(left_target_rpm),
        .right_target_rpm(right_target_rpm),
        .left_dir(left_dir), .right_dir(right_dir),
        .motion_state(motion_state)
    );

    task send_distance;
        input [15:0] value;
        begin
            @(negedge clk);
            distance_mm = value;
            distance_valid = 1'b1;
            @(negedge clk);
            distance_valid = 1'b0;
        end
    endtask

    task check;
        input condition;
        input [8*80-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        check(motion_state == 0 && left_target_rpm == 0,
              "reset/disabled state must stop both motors");

        enable = 1'b1;
        send_distance(16'd800);
        check(motion_state == 1 && left_target_rpm == 180 &&
              right_target_rpm == 180 && !left_dir && !right_dir,
              "clear path must command forward motion");

        send_distance(16'd200);
        check(motion_state == 3 && left_target_rpm == 0 &&
              right_target_rpm == 0,
              "near obstacle must enter an explicit stopped brake state");
        repeat (4) @(posedge clk);
        #1;
        check(motion_state == 2 && left_target_rpm == 140 &&
              right_target_rpm == 140 && !left_dir && right_dir,
              "brake interval must lead to an in-place turn");

        send_distance(16'd800);
        repeat (6) @(posedge clk);
        #1;
        check(motion_state == 1,
              "turn timer plus clear distance must return to forward motion");

        repeat (11) @(posedge clk);
        #1;
        check(motion_state == 0 && left_target_rpm == 0 &&
              right_target_rpm == 0,
              "sensor watchdog must stop the car when range data disappears");

        enable = 1'b0;
        send_distance(16'd800);
        check(motion_state == 0,
              "disabled controller must remain stopped even with valid data");

        if (errors == 0)
            $display("PASS autonomous stop, forward, obstacle turn, and watchdog logic");
        else
            $fatal(1, "%0d autonomous motion checks failed", errors);
        $finish;
    end
endmodule
