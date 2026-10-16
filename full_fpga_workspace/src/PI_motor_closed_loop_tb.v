`timescale 1ns/1ps

module PI_motor_closed_loop_tb;
    reg clk;
    reg rst_n;
    reg signed [31:0] target_rpm;
    wire signed [31:0] actual_rpm;
    reg update_en;
    wire [9:0] duty;
    wire signed [31:0] error;
    wire signed [31:0] integral;
    // =========================
    // 50 MHz 时钟
    // =========================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    // =========================
    // PI 控制器
    // =========================
    PI_controller #(
        .KP(400),
        .KI(0),
        .SCALE(1000),
        .OUT_MAX(1000),
        .I_MAX(120000)
    ) u_pi (
        .clk(clk),
        .rst_n(rst_n),
        .target_rpm(target_rpm),
        .actual_rpm(actual_rpm),
        .update_en(update_en),
        .duty(duty),
        .error(error),
        .integral(integral)
    );

    // =========================
    // 模拟电机
    // =========================
    motor_model #(
    .CLK_FREQ(50_000_000),
    .MOTOR_UPDATE_MS(1),
    .LOAD_RPM(30)
) u_motor (
    .clk(clk),
    .rst_n(rst_n),
    .duty(duty),
    .actual_rpm(actual_rpm)
);
    // =========================
    // 控制周期
    // =========================
    // 每 1 us 更新一次 PI
    initial begin
    update_en = 0;
    forever begin
        #10_000_000;
        update_en = 1;
        #20;
        update_en = 0;
    end
end
    // =========================
    // 仿真过程
    // =========================
    initial begin
    rst_n = 0;
    target_rpm = 0;
    #100;
    rst_n = 1;
    // 目标速度 300 RPM
    #1000;
    target_rpm = 300;
    // 仿真 500 ms
    #1_000_000_000;
    $stop;
    end
endmodule