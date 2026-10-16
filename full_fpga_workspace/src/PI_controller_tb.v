`timescale 1ns/1ps
module PI_controller_tb;
    reg clk;
    reg rst_n;
    reg signed [31:0] target_rpm;
    reg signed [31:0] actual_rpm;
    reg update_en;
    wire [9:0] duty;
    wire signed [31:0] error;
    wire signed [31:0] integral;
    // ========================================
    // 实例化 PI 控制器
    // ========================================
    PI_controller #(
        .KP(100),
        .KI(10),
        .SCALE(1000),
        .OUT_MAX(1000),
        .I_MAX(10000)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .target_rpm(target_rpm),
        .actual_rpm(actual_rpm),
        .update_en(update_en),
        .duty(duty),
        .error(error),
        .integral(integral)
    );
    // ========================================
    // 产生时钟
    // 50 MHz
    // 周期 = 20 ns
    // ========================================
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end
    // ========================================
    // 产生 update_en
    //
    // 为了仿真方便：
    // 每 1 us 更新一次
    //
    // 实际系统以后是 10 ms
    // ========================================
    initial begin
        update_en = 1'b0;
        forever begin
            #990;
            update_en = 1'b1;
            #20;
            update_en = 1'b0;
        end
    end
    // ========================================
    // 测试过程
    // ========================================
    initial begin
        // 初始状态
        rst_n = 1'b0;
        target_rpm = 32'sd0;
        actual_rpm = 32'sd0;
        #100;
        rst_n = 1'b1;
        // ====================================
        // 目标速度设置为 300 RPM
        // ====================================
        target_rpm = 32'sd300;
        // ====================================
        // 模拟实际速度逐渐上升
        // ====================================
        #1000;
        actual_rpm = 32'sd50;
        #1000;
        actual_rpm = 32'sd100;
        #1000;
        actual_rpm = 32'sd150;
        #1000;
        actual_rpm = 32'sd200;
        #1000;
        actual_rpm = 32'sd230;
        #1000;
        actual_rpm = 32'sd250;
        #1000;
        actual_rpm = 32'sd270;
        #1000;
        actual_rpm = 32'sd285;
        #1000;
        actual_rpm = 32'sd295;
        #1000;
        actual_rpm = 32'sd300;
        // ====================================
        // 保持 300 RPM
        // ====================================
        #5000;
        // ====================================
        // 停止
        // ====================================
        $stop;
    end

endmodule