`timescale 1ns/1ps

module wheel_sync_control #(
    // 同步比例系数
    // correction = sync_error * K_SYNC / SCALE
    parameter integer K_SYNC = 250,
    parameter integer SCALE = 1000,
    // 最大允许同步补偿 RPM
    parameter integer MAX_CORRECTION = 50,
    // 同步死区 RPM
    parameter integer SYNC_DEADZONE = 2,
    // 最大目标转速
    parameter integer MAX_RPM = 400
)(
    input wire clk,
    input wire rst_n,
    // 是否开启同步控制
    input wire sync_enable,
    // 原始目标速度
    input wire signed [31:0] left_target_rpm,
    input wire signed [31:0] right_target_rpm,
    // 左右轮实际速度
    input wire signed [31:0] left_actual_rpm,
    input wire signed [31:0] right_actual_rpm,
    // 同步后的目标速度
    output reg signed [31:0] left_target_sync_rpm,
    output reg signed [31:0] right_target_sync_rpm,
    // 调试信号
    output reg signed [31:0] sync_error,
    output reg signed [31:0] correction
);
    // =========================================================
    // 中间变量
    // =========================================================
    reg signed [31:0] error_next;
    reg signed [63:0] correction_temp;
    reg signed [31:0] correction_next;
    reg signed [31:0] left_target_temp;
    reg signed [31:0] right_target_temp;
    // =========================================================
    // 同步控制计算
    // =========================================================
    always @(*) begin
        // -----------------------------------------------------
        // 1. 计算左右轮速度差
        //
        // sync_error > 0：
        // 左轮比右轮快
        //
        // sync_error < 0：
        // 右轮比左轮快
        // -----------------------------------------------------
        error_next =
            left_actual_rpm - right_actual_rpm;
        // -----------------------------------------------------
        // 2. 默认值
        // -----------------------------------------------------
        correction_temp = 64'sd0;
        correction_next = 32'sd0;
        left_target_temp = left_target_rpm;
        right_target_temp = right_target_rpm;
        // -----------------------------------------------------
        // 3. 目标为 0
        //
        // 停车时不进行同步补偿
        // -----------------------------------------------------
        if ((left_target_rpm == 0) &&
            (right_target_rpm == 0)) begin
            correction_next = 32'sd0;
            left_target_temp = 32'sd0;
            right_target_temp = 32'sd0;
        end
        // -----------------------------------------------------
        // 4. 同步控制关闭
        // -----------------------------------------------------
        else if (!sync_enable) begin
            correction_next = 32'sd0;
            left_target_temp = left_target_rpm;
            right_target_temp = right_target_rpm;
        end
        // -----------------------------------------------------
        // 5. 同步控制
        // -----------------------------------------------------
        else begin
            // ---------------------------------------------
            // 同步死区
            //
            // 速度差很小时认为已经同步
            // 避免编码器量化误差造成频繁修正
            // ---------------------------------------------
            if ((error_next <= SYNC_DEADZONE) &&
                (error_next >= -SYNC_DEADZONE)) begin
                correction_next = 32'sd0;
            end
            else begin
                // -----------------------------------------
                // 比例同步补偿
                //
                // correction =
                //     error × K_SYNC / SCALE
                // -----------------------------------------
                correction_temp =
                    error_next * K_SYNC;

                correction_temp =
                    correction_temp / SCALE;
                // -----------------------------------------
                // 同步补偿限幅
                // -----------------------------------------

                if (correction_temp > MAX_CORRECTION)
                    correction_next = MAX_CORRECTION;

                else if (correction_temp < -MAX_CORRECTION)
                    correction_next = -MAX_CORRECTION;

                else
                    correction_next =
                        correction_temp[31:0];

            end
            // ---------------------------------------------
            // 左右目标速度补偿
            //
            // 左轮快：
            // correction > 0
            // 左目标下降
            // 右目标上升
            //
            // 右轮快：
            // correction < 0
            // 左目标上升
            // 右目标下降
            // ---------------------------------------------
            left_target_temp =
                left_target_rpm - correction_next;

            right_target_temp =
                right_target_rpm + correction_next;
        end
        // =====================================================
        // 6. 左轮目标速度限幅
        // =====================================================
        if (left_target_temp > MAX_RPM)
            left_target_sync_rpm = MAX_RPM;

        else if (left_target_temp < 0)
            left_target_sync_rpm = 0;

        else
            left_target_sync_rpm = left_target_temp;
        // =====================================================
        // 7. 右轮目标速度限幅
        // =====================================================
        if (right_target_temp > MAX_RPM)
            right_target_sync_rpm = MAX_RPM;

        else if (right_target_temp < 0)
            right_target_sync_rpm = 0;
        else
            right_target_sync_rpm = right_target_temp;
        // =====================================================
        // 8. 输出实际同步误差和补偿量
        // =====================================================
        sync_error = error_next;
        correction = correction_next;
    end
endmodule
