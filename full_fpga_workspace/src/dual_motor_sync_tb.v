`timescale 1ns/1ps

module dual_motor_sync_tb;

    // =========================================================
    // 1. 仿真参数
    // =========================================================

    localparam integer CLK_FREQ = 1_000_000;
    localparam integer PWM_FREQ = 20_000;

    localparam integer COUNTS_PER_REV = 1456;
    localparam integer SAMPLE_TIME_MS = 10;

    // PI 参数
    localparam integer KP = 100;
    localparam integer KI = 10;
    localparam integer SCALE = 1000;
    localparam integer OUT_MAX = 1000;
    localparam integer I_MAX = 120000;
    localparam integer DEAD_ZONE = 0;
    localparam integer DUTY_MAX = 1000;

    // 同步参数
    localparam integer K_SYNC = 250;
    localparam integer SYNC_SCALE = 1000;
    localparam integer MAX_CORRECTION = 50;
    localparam integer SYNC_DEADZONE = 2;
    localparam integer MAX_RPM = 400;


    // =========================================================
    // 2. 时钟
    // =========================================================

    reg clk;

    initial begin
        clk = 1'b0;

        forever #500 clk = ~clk;
    end


    // =========================================================
    // 3. 复位
    // =========================================================

    reg rst_n;


    // =========================================================
    // 4. 原始目标速度
    // =========================================================

    reg signed [31:0] left_target_rpm;
    reg signed [31:0] right_target_rpm;


    // =========================================================
    // 5. 同步控制
    // =========================================================

    reg sync_enable;

    wire signed [31:0] left_target_sync_rpm;
    wire signed [31:0] right_target_sync_rpm;

    wire signed [31:0] sync_error;
    wire signed [31:0] correction;


    // =========================================================
    // 6. 编码器信号
    // =========================================================

    reg left_enc_a;
    reg left_enc_b;

    reg right_enc_a;
    reg right_enc_b;


    // =========================================================
    // 7. 双电机控制输出
    // =========================================================

    wire left_pwm;
    wire left_in1;
    wire left_in2;

    wire right_pwm;
    wire right_in1;
    wire right_in2;


    wire signed [31:0] left_encoder_count;
    wire signed [31:0] right_encoder_count;

    wire signed [31:0] left_actual_rpm;
    wire signed [31:0] right_actual_rpm;

    wire [9:0] left_duty;
    wire [9:0] right_duty;

    wire signed [31:0] left_error;
    wire signed [31:0] right_error;


    // =========================================================
    // 8. wheel_sync_control
    // =========================================================

    wheel_sync_control #(
        .K_SYNC(K_SYNC),
        .SCALE(SYNC_SCALE),
        .MAX_CORRECTION(MAX_CORRECTION),
        .SYNC_DEADZONE(SYNC_DEADZONE),
        .MAX_RPM(MAX_RPM)
    ) u_sync_control (

        .clk(clk),
        .rst_n(rst_n),

        .sync_enable(sync_enable),

        .left_target_rpm(left_target_rpm),
        .right_target_rpm(right_target_rpm),

        .left_actual_rpm(left_actual_rpm),
        .right_actual_rpm(right_actual_rpm),

        .left_target_sync_rpm(left_target_sync_rpm),
        .right_target_sync_rpm(right_target_sync_rpm),

        .sync_error(sync_error),
        .correction(correction)
    );


    // =========================================================
    // 9. dual_motor_control
    //
    // 注意：
    // 这里输入的是同步控制器修正后的目标速度
    // =========================================================

    dual_motor_control #(
        .CLK_FREQ(CLK_FREQ),
        .PWM_FREQ(PWM_FREQ),
        .COUNTS_PER_REV(COUNTS_PER_REV),
        .SAMPLE_TIME_MS(SAMPLE_TIME_MS),

        .KP(KP),
        .KI(KI),
        .SCALE(SCALE),
        .OUT_MAX(OUT_MAX),
        .I_MAX(I_MAX),
        .DEAD_ZONE(DEAD_ZONE),
        .DUTY_MAX(DUTY_MAX)
    ) u_dual_motor_control (

        .clk(clk),
        .rst_n(rst_n),

        .left_target_rpm(left_target_sync_rpm),
        .right_target_rpm(right_target_sync_rpm),

        .left_dir(1'b0),
        .right_dir(1'b0),

        .left_enc_a(left_enc_a),
        .left_enc_b(left_enc_b),

        .right_enc_a(right_enc_a),
        .right_enc_b(right_enc_b),

        .left_pwm(left_pwm),
        .left_in1(left_in1),
        .left_in2(left_in2),

        .right_pwm(right_pwm),
        .right_in1(right_in1),
        .right_in2(right_in2),

        .left_encoder_count(left_encoder_count),
        .right_encoder_count(right_encoder_count),

        .left_actual_rpm(left_actual_rpm),
        .right_actual_rpm(right_actual_rpm),

        .left_duty(left_duty),
        .right_duty(right_duty),

        .left_error(left_error),
        .right_error(right_error)
    );


    // =========================================================
    // 10. 电机模型
    // =========================================================

    // 故意让左右电机存在差异
    localparam integer LEFT_MAX_RPM = 400;
    localparam integer RIGHT_MAX_RPM = 370;

    localparam integer RESPONSE_DIV = 20;


    reg signed [31:0] left_motor_rpm;
    reg signed [31:0] right_motor_rpm;

    reg signed [31:0] left_motor_target_rpm;
    reg signed [31:0] right_motor_target_rpm;

    reg [31:0] left_motor_counter;
    reg [31:0] right_motor_counter;


    // =========================================================
    // 11. duty → 电机目标转速
    // =========================================================

    always @(*) begin

        left_motor_target_rpm =
            left_duty * LEFT_MAX_RPM / 1000;

        right_motor_target_rpm =
            right_duty * RIGHT_MAX_RPM / 1000;

    end


    // =========================================================
    // 12. 电机动态模型
    // =========================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            left_motor_counter <= 0;
            right_motor_counter <= 0;

            left_motor_rpm <= 0;
            right_motor_rpm <= 0;

        end
        else begin

            // -------------------------------------------------
            // 左电机
            // -------------------------------------------------

            if (left_motor_counter >= 1000 - 1) begin

                left_motor_counter <= 0;

                left_motor_rpm <= left_motor_rpm +
                    (left_motor_target_rpm -
                     left_motor_rpm) /
                    RESPONSE_DIV;

            end
            else begin

                left_motor_counter <=
                    left_motor_counter + 1'b1;

            end


            // -------------------------------------------------
            // 右电机
            // -------------------------------------------------

            if (right_motor_counter >= 1000 - 1) begin

                right_motor_counter <= 0;

                right_motor_rpm <= right_motor_rpm +
                    (right_motor_target_rpm -
                     right_motor_rpm) /
                    RESPONSE_DIV;

            end
            else begin

                right_motor_counter <=
                    right_motor_counter + 1'b1;

            end

        end

    end


    // =========================================================
    // 13. 编码器模型
    // =========================================================

    reg [31:0] left_encoder_counter;
    reg [31:0] right_encoder_counter;

    reg [1:0] left_encoder_state;
    reg [1:0] right_encoder_state;

    reg [31:0] left_encoder_period;
    reg [31:0] right_encoder_period;


    // =========================================================
    // 14. 根据电机转速计算编码器周期
    // =========================================================

    always @(*) begin

        // -----------------------------------------------------
        // 左编码器
        // -----------------------------------------------------

        if (left_motor_rpm <= 0) begin

            left_encoder_period = 32'hFFFFFFFF;

        end
        else begin

            left_encoder_period =
                (CLK_FREQ * 60) /
                (left_motor_rpm * COUNTS_PER_REV);

            if (left_encoder_period < 4)
                left_encoder_period = 4;

        end


        // -----------------------------------------------------
        // 右编码器
        // -----------------------------------------------------

        if (right_motor_rpm <= 0) begin

            right_encoder_period = 32'hFFFFFFFF;

        end
        else begin

            right_encoder_period =
                (CLK_FREQ * 60) /
                (right_motor_rpm * COUNTS_PER_REV);

            if (right_encoder_period < 4)
                right_encoder_period = 4;

        end

    end


    // =========================================================
    // 15. 编码器状态机
    // =========================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            left_encoder_counter <= 0;
            right_encoder_counter <= 0;

            left_encoder_state <= 2'b00;
            right_encoder_state <= 2'b00;

        end
        else begin

            // =================================================
            // 左编码器
            // =================================================

            if (left_motor_rpm <= 0) begin

                left_encoder_counter <= 0;
                left_encoder_state <= 2'b00;

            end
            else if (left_encoder_counter >=
                     left_encoder_period - 1) begin

                left_encoder_counter <= 0;

                case (left_encoder_state)

                    2'b00:
                        left_encoder_state <= 2'b01;

                    2'b01:
                        left_encoder_state <= 2'b11;

                    2'b11:
                        left_encoder_state <= 2'b10;

                    2'b10:
                        left_encoder_state <= 2'b00;

                    default:
                        left_encoder_state <= 2'b00;

                endcase

            end
            else begin

                left_encoder_counter <=
                    left_encoder_counter + 1'b1;

            end


            // =================================================
            // 右编码器
            // =================================================
            if (right_motor_rpm <= 0) begin
                right_encoder_counter <= 0;
                right_encoder_state <= 2'b00;
            end
            else if (right_encoder_counter >=
                     right_encoder_period - 1) begin
                right_encoder_counter <= 0;
                case (right_encoder_state)
                    2'b00:
                        right_encoder_state <= 2'b01;
                    2'b01:
                        right_encoder_state <= 2'b11;
                    2'b11:
                        right_encoder_state <= 2'b10;
                    2'b10:
                        right_encoder_state <= 2'b00;
                    default:
                        right_encoder_state <= 2'b00;
                endcase
            end
            else begin

                right_encoder_counter <=
                    right_encoder_counter + 1'b1;
            end
        end
    end
    // =========================================================
    // 16. 编码器状态 → A/B
    // =========================================================
    always @(*) begin
        left_enc_a = left_encoder_state[1];
        left_enc_b = left_encoder_state[0];
        right_enc_a = right_encoder_state[1];
        right_enc_b = right_encoder_state[0];
    end
    // =========================================================
    // 17. 测试流程
    // =========================================================
    initial begin
        // -----------------------------------------------------
        // 初始状态
        // -----------------------------------------------------
        rst_n = 1'b0;
        left_target_rpm = 32'sd0;
        right_target_rpm = 32'sd0;
        sync_enable = 1'b0;
        // -----------------------------------------------------
        // 复位
        // -----------------------------------------------------
        #5000;
        rst_n = 1'b1;
        // =====================================================
        // 第一阶段
        //
        // 0 ~ 2 s
        // 同步关闭
        // 两轮停止
        // =====================================================
        #2_000_000_000;
        // =====================================================
        // 第二阶段
        //
        // 2 ~ 7 s
        //
        // 左右目标都是 300 RPM
        // 同步关闭
        //
        // 观察由于左右电机性能不同产生的速度差
        // =====================================================
        left_target_rpm = 32'sd300;
        right_target_rpm = 32'sd300;
        sync_enable = 1'b0;
        #3_000_000_000;
#2_000_000_000;
        // =====================================================
        // 第三阶段
        //
        // 7 ~ 12 s
        //
        // 保持 300 / 300
        // 开启同步控制
        //
        // 观察左右实际速度逐渐靠近
        // =====================================================
        sync_enable = 1'b1;
        #3_000_000_000;
#2_000_000_000;
        // =====================================================
        // 第四阶段
        //
        // 12 ~ 17 s
        //
        // 测试不同目标速度
        // 左 200 / 右 300
        //
        // 注意：
        // 这个阶段用于验证同步模块不会简单地强行
        // 把两个不同目标速度变成相同速度。
        // =====================================================
        left_target_rpm = 32'sd200;
        right_target_rpm = 32'sd300;
        #3_000_000_000;
#2_000_000_000;
        // =====================================================
        // 第五阶段
        //
        // 17 ~ 22 s
        //
        // 回到 300 / 300
        // =====================================================
        left_target_rpm = 32'sd300;
        right_target_rpm = 32'sd300;
        #3_000_000_000;
#2_000_000_000;
        // =====================================================
        // 第六阶段
        //
        // 22 ~ 24 s
        //
        // 停车
        // =====================================================
        left_target_rpm = 32'sd0;
        right_target_rpm = 32'sd0;
        #2_000_000_000;
        $stop;
    end
endmodule