`timescale 1ns/1ps

module motor_logic_selfcheck_tb;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    integer errors = 0;

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

    reg rst_n = 1'b0;

    reg [9:0] duty = 10'd0;
    reg dir = 1'b0;
    wire pwm_out;
    wire in1;
    wire in2;
    motor_control #(.CLK_FREQ(100), .PWM_FREQ(10)) u_motor (
        .clk(clk), .rst_n(rst_n), .duty(duty), .dir(dir),
        .pwm_out(pwm_out), .in1(in1), .in2(in2)
    );

    reg enc_a = 1'b0;
    reg enc_b = 1'b0;
    wire enc_dir;
    wire signed [31:0] enc_count;
    quadrature_encoder u_encoder (
        .clk(clk), .rst_n(rst_n), .enc_a(enc_a), .enc_b(enc_b),
        .direction(enc_dir), .count(enc_count)
    );

    reg signed [31:0] speed_count = 0;
    wire signed [31:0] rpm;
    wire rpm_update;
    speed_measure #(
        .CLK_FREQ(1000), .SAMPLE_TIME_MS(10), .COUNTS_PER_REV(100)
    ) u_speed (
        .clk(clk), .rst_n(rst_n), .count(speed_count),
        .rpm(rpm), .update_en(rpm_update)
    );

    reg signed [31:0] target_rpm = 0;
    reg signed [31:0] actual_rpm = 0;
    reg pi_update = 1'b0;
    wire [9:0] duty_pi;
    wire [9:0] pi_duty;
    wire signed [31:0] pi_error;
    wire signed [31:0] pi_integral;
    PI_controller #(.KP(1000), .KI(0), .SCALE(1000)) u_pi (
        .clk(clk), .rst_n(rst_n), .target_rpm(target_rpm),
        .actual_rpm(actual_rpm), .update_en(pi_update),
        .duty_pi(duty_pi), .duty(pi_duty), .error(pi_error),
        .integral(pi_integral)
    );

    reg sync_enable = 1'b0;
    reg signed [31:0] left_target = 0;
    reg signed [31:0] right_target = 0;
    reg signed [31:0] left_actual = 0;
    reg signed [31:0] right_actual = 0;
    wire signed [31:0] left_sync;
    wire signed [31:0] right_sync;
    wire signed [31:0] sync_error;
    wire signed [31:0] correction;
    wheel_sync_control u_sync (
        .clk(clk), .rst_n(rst_n), .sync_enable(sync_enable),
        .left_target_rpm(left_target), .right_target_rpm(right_target),
        .left_actual_rpm(left_actual), .right_actual_rpm(right_actual),
        .left_target_sync_rpm(left_sync), .right_target_sync_rpm(right_sync),
        .sync_error(sync_error), .correction(correction)
    );

    task encoder_state;
        input [1:0] state;
        begin
            @(negedge clk);
            enc_a = state[1];
            enc_b = state[0];
            repeat (4) @(posedge clk);
        end
    endtask

    integer high_count;
    integer i;
    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        check(pwm_out === 1'b0 && in1 === 1'b0 && in2 === 1'b0,
              "zero duty must disable the motor outputs");

        duty = 10'd500;
        dir = 1'b0;
        repeat (2) @(posedge clk);
        check(in1 === 1'b1 && in2 === 1'b0,
              "forward direction must drive IN1=1, IN2=0");
        high_count = 0;
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk);
            if (pwm_out) high_count = high_count + 1;
        end
        check(high_count == 5, "500/1000 duty must produce 50 percent PWM");

        dir = 1'b1;
        #1;
        check(in1 === 1'b0 && in2 === 1'b1,
              "reverse direction must drive IN1=0, IN2=1");

        duty = 10'd0;
        #1;
        check(in1 === 1'b0 && in2 === 1'b0 && pwm_out === 1'b0,
              "stopping must make PWM and both direction pins low");

        encoder_state(2'b01);
        encoder_state(2'b11);
        encoder_state(2'b10);
        encoder_state(2'b00);
        check(enc_count == 4 && enc_dir == 1'b1,
              "one forward quadrature cycle must add four counts");
        encoder_state(2'b10);
        encoder_state(2'b11);
        encoder_state(2'b01);
        encoder_state(2'b00);
        check(enc_count == 0 && enc_dir == 1'b0,
              "one reverse quadrature cycle must subtract four counts");

        speed_count = 10;
        wait (rpm_update == 1'b1);
        @(negedge clk);
        check(rpm == 600, "speed conversion must report 600 RPM for the test window");

        target_rpm = 100;
        actual_rpm = 0;
        pi_update = 1'b1;
        @(posedge clk);
        #1;
        pi_update = 1'b0;
        check(pi_duty == 100 && pi_error == 100,
              "PI proportional output must follow the configured scale");
        target_rpm = 0;
        pi_update = 1'b1;
        @(posedge clk);
        #1;
        pi_update = 1'b0;
        check(pi_duty == 0 && pi_integral == 0,
              "zero target must stop and clear the PI integral");

        sync_enable = 1'b1;
        left_target = 100;
        right_target = 100;
        left_actual = 120;
        right_actual = 80;
        #1;
        check(sync_error == 40 && correction == 10 &&
              left_sync == 90 && right_sync == 110,
              "wheel synchronizer must slow the faster side and raise the slower side");

        if (errors == 0)
            $display("PASS motor PWM, direction, encoder, speed, PI, and wheel sync logic");
        else
            $fatal(1, "%0d motor logic checks failed", errors);
        $finish;
    end
endmodule
