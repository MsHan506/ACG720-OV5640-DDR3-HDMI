`timescale 1ns/1ps

module motor_button_commissioning_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ch1_button_n = 1'b1;
    reg ch2_button_n = 1'b1;
    wire test_active, stby, pwm1, ain1, ain2, pwm2, bin1, bin2;
    integer i;
    reg saw_pwm1;
    reg saw_pwm2;

    always #500 clk = ~clk;

    motor_button_commissioning #(
        .CLK_FREQ(1_000_000), .PWM_HZ(10_000),
        .DUTY_PERCENT(20), .DEADTIME_US(5)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .ch1_button_n(ch1_button_n), .ch2_button_n(ch2_button_n),
        .test_active(test_active), .driver_stby(stby),
        .ch1_pwm(pwm1), .ch1_in1(ain1), .ch1_in2(ain2),
        .ch2_pwm(pwm2), .ch2_in1(bin1), .ch2_in2(bin2)
    );

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);
        if ({stby,pwm1,ain1,ain2,pwm2,bin1,bin2} !== 7'b0)
            $fatal(1, "outputs not locked with no button");

        ch1_button_n = 1'b0;
        saw_pwm1 = 1'b0;
        for (i = 0; i < 220; i = i + 1) begin
            @(posedge clk);
            if (pwm1) saw_pwm1 = 1'b1;
            if (pwm2) $fatal(1, "channel 2 moved during channel 1 test");
        end
        if (!saw_pwm1 || !stby || !ain1 || ain2)
            $fatal(1, "channel 1 momentary test failed");

        ch1_button_n = 1'b1;
        repeat (4) @(posedge clk);
        if ({stby,pwm1,ain1,ain2,pwm2,bin1,bin2} !== 7'b0)
            $fatal(1, "button release did not return to standby");

        ch2_button_n = 1'b0;
        saw_pwm2 = 1'b0;
        for (i = 0; i < 220; i = i + 1) begin
            @(posedge clk);
            if (pwm2) saw_pwm2 = 1'b1;
            if (pwm1) $fatal(1, "channel 1 moved during channel 2 test");
        end
        if (!saw_pwm2 || !stby || !bin1 || bin2)
            $fatal(1, "channel 2 momentary test failed");

        ch2_button_n = 1'b1;
        repeat (4) @(posedge clk);
        if ({stby,pwm1,ain1,ain2,pwm2,bin1,bin2} !== 7'b0)
            $fatal(1, "final state is not locked");

        $display("PASS momentary S1/S2 low-duty motor commissioning safety");
        $finish;
    end
endmodule
