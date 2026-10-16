`timescale 1ns/1ps

// Momentary, suspended-wheel motor commissioning control.  Both buttons are
// active-low.  Releasing all buttons always returns the driver to standby.
module motor_button_commissioning #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer PWM_HZ = 20_000,
    parameter integer DUTY_PERCENT = 20,
    parameter integer DEADTIME_US = 2000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire ch1_button_n,
    input  wire ch2_button_n,
    output wire test_active,
    output wire driver_stby,
    output wire ch1_pwm,
    output wire ch1_in1,
    output wire ch1_in2,
    output wire ch2_pwm,
    output wire ch2_in1,
    output wire ch2_in2
);
    localparam integer PWM_PERIOD = CLK_FREQ / PWM_HZ;
    localparam integer PWM_HIGH = (PWM_PERIOD * DUTY_PERCENT) / 100;

    reg [1:0] ch1_sync;
    reg [1:0] ch2_sync;
    reg [31:0] pwm_counter;
    wire ch1_request = ~ch1_sync[1];
    wire ch2_request = ~ch2_sync[1];
    wire pwm_raw = pwm_counter < PWM_HIGH;

    assign test_active = ch1_request | ch2_request;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch1_sync <= 2'b11;
            ch2_sync <= 2'b11;
            pwm_counter <= 32'd0;
        end else begin
            ch1_sync <= {ch1_sync[0], ch1_button_n};
            ch2_sync <= {ch2_sync[0], ch2_button_n};
            if (pwm_counter == PWM_PERIOD - 1)
                pwm_counter <= 32'd0;
            else
                pwm_counter <= pwm_counter + 1'b1;
        end
    end

    tb6612_dual_safe_adapter #(
        .CLK_FREQ(CLK_FREQ), .DEADTIME_US(DEADTIME_US)
    ) u_safe_adapter (
        .clk(clk), .rst_n(rst_n), .enable(test_active),
        .ch1_pwm_in(pwm_raw & ch1_request),
        .ch1_in1_in(1'b1), .ch1_in2_in(1'b0),
        .ch2_pwm_in(pwm_raw & ch2_request),
        .ch2_in1_in(1'b1), .ch2_in2_in(1'b0),
        .driver_stby(driver_stby),
        .ch1_pwm(ch1_pwm), .ch1_in1(ch1_in1), .ch1_in2(ch1_in2),
        .ch2_pwm(ch2_pwm), .ch2_in1(ch2_in1), .ch2_in2(ch2_in2)
    );
endmodule
