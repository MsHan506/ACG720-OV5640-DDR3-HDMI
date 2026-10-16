`timescale 1ns/1ps

module single_motor_reverse_feedback_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg signed [31:0] target_rpm = 32'sd100;
    wire [9:0] duty;
    wire signed [31:0] actual_rpm;
    always #5 clk = ~clk;

    single_motor_control #(
        .CLK_FREQ(1000), .PWM_FREQ(100), .COUNTS_PER_REV(100),
        .SAMPLE_TIME_MS(10), .KP(1000), .KI(0), .SCALE(1000)
    ) dut (
        .clk(clk), .rst_n(rst_n), .target_rpm(target_rpm), .dir(1'b1),
        .enc_a(1'b0), .enc_b(1'b0), .pwm_out(), .in1(), .in2(),
        .encoder_count(), .actual_rpm(actual_rpm), .duty(duty),
        .duty_pi(), .error(), .integral()
    );

    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        // Inject a negative encoder-derived speed and an update pulse.  The PI
        // must compare its magnitude (80) with the requested magnitude (100).
        force dut.actual_rpm = -32'sd80;
        force dut.speed_update_en = 1'b1;
        @(posedge clk);
        force dut.speed_update_en = 1'b0;
        @(posedge clk);
        #1;
        if (duty != 10'd20) begin
            $display("FAIL reverse feedback magnitude: duty=%0d expected=20", duty);
            $fatal(1);
        end
        release dut.actual_rpm;
        release dut.speed_update_en;
        $display("PASS reverse encoder polarity uses speed magnitude");
        $finish;
    end
endmodule
