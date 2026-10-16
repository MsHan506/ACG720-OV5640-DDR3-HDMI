`timescale 1ns/1ps

module dual_motor_control_tb;

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


    // =========================================================
    // 2. 时钟和复位
    // =========================================================

    reg clk;
    reg rst_n;

    initial begin
        clk = 1'b0;
        forever #500 clk = ~clk;
    end


    // =========================================================
    // 3. 双电机控制输入
    // =========================================================

    reg signed [31:0] left_target_rpm;
    reg signed [31:0] right_target_rpm;

    reg left_dir;
    reg right_dir;


    // =========================================================
    // 4. 编码器输入
    // =========================================================

    reg left_enc_a;
    reg left_enc_b;

    reg right_enc_a;
    reg right_enc_b;


    // =========================================================
    // 5. 双电机控制输出
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
    // 6. 实例化 dual_motor_control
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
    ) uut (

        .clk(clk),
        .rst_n(rst_n),

        .left_target_rpm(left_target_rpm),
        .right_target_rpm(right_target_rpm),

        .left_dir(left_dir),
        .right_dir(right_dir),

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
    // 7. 左右电机模型
    // =========================================================

    localparam integer MAX_RPM = 400;
    localparam integer RESPONSE_DIV = 20;

    reg signed [31:0] left_motor_rpm;
    reg signed [31:0] right_motor_rpm;

    reg signed [31:0] left_motor_target_rpm;
    reg signed [31:0] right_motor_target_rpm;

    reg [31:0] left_motor_counter;
    reg [31:0] right_motor_counter;


    // PWM占空比 → 电机目标转速
    always @(*) begin
        left_motor_target_rpm =
            left_duty * MAX_RPM / 1000;

        right_motor_target_rpm =
            right_duty * MAX_RPM / 1000;
    end


    // 左右电机动态模型
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            left_motor_counter <= 0;
            right_motor_counter <= 0;

            left_motor_rpm <= 0;
            right_motor_rpm <= 0;

        end
        else begin

            // 每 1000 个时钟更新一次电机转速
            // 1 MHz 时钟下 = 1 ms

            if (left_motor_counter >= 1000 - 1) begin

                left_motor_counter <= 0;

                left_motor_rpm <= left_motor_rpm +
                    (left_motor_target_rpm - left_motor_rpm)
                    / RESPONSE_DIV;

            end
            else begin
                left_motor_counter <=
                    left_motor_counter + 1'b1;
            end


            if (right_motor_counter >= 1000 - 1) begin

                right_motor_counter <= 0;

                right_motor_rpm <= right_motor_rpm +
                    (right_motor_target_rpm - right_motor_rpm)
                    / RESPONSE_DIV;

            end
            else begin
                right_motor_counter <=
                    right_motor_counter + 1'b1;
            end

        end
    end


    // =========================================================
    // 8. 左右编码器模型
    // =========================================================

    reg [31:0] left_encoder_counter;
    reg [31:0] right_encoder_counter;

    reg [1:0] left_encoder_state;
    reg [1:0] right_encoder_state;

    reg [31:0] left_encoder_period;
    reg [31:0] right_encoder_period;


    // 根据电机转速计算编码器周期
    always @(*) begin

        // 左编码器
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


        // 右编码器
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
    // 9. 编码器状态变化
    // =========================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            left_encoder_counter <= 0;
            right_encoder_counter <= 0;

            left_encoder_state <= 2'b00;
            right_encoder_state <= 2'b00;

        end
        else begin

            // -------------------------
            // 左编码器
            // -------------------------

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


            // -------------------------
            // 右编码器
            // -------------------------

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


    // 编码器状态 → A/B
    always @(*) begin

        left_enc_a = left_encoder_state[1];
        left_enc_b = left_encoder_state[0];

        right_enc_a = right_encoder_state[1];
        right_enc_b = right_encoder_state[0];

    end


    // =========================================================
    // 10. 测试流程
    // =========================================================

    initial begin

        rst_n = 1'b0;

        left_target_rpm = 32'sd0;
        right_target_rpm = 32'sd0;

        left_dir = 1'b0;
        right_dir = 1'b0;


        // 等待复位
        #5000;

        rst_n = 1'b1;


        // -----------------------------------------------------
        // 0 ~ 2 s
        // 两个电机停止
        // -----------------------------------------------------

        #2_000_000_000;


        // -----------------------------------------------------
        // 2 ~ 6 s
        // 左右轮同时 300 RPM
        // -----------------------------------------------------

        left_target_rpm = 32'sd300;
        right_target_rpm = 32'sd300;

        #4_000_000_000;


        // -----------------------------------------------------
        // 6 ~ 10 s
        // 左 150 RPM，右 300 RPM
        // -----------------------------------------------------

        left_target_rpm = 32'sd150;
        right_target_rpm = 32'sd300;

        #4_000_000_000;


        // -----------------------------------------------------
        // 10 ~ 14 s
        // 左 300 RPM，右 150 RPM
        // -----------------------------------------------------

        left_target_rpm = 32'sd300;
        right_target_rpm = 32'sd150;

        #4_000_000_000;


        // -----------------------------------------------------
        // 14 ~ 18 s
        // 两个电机重新回到 300 RPM
        // -----------------------------------------------------

        left_target_rpm = 32'sd300;
        right_target_rpm = 32'sd300;

        #4_000_000_000;


        // -----------------------------------------------------
        // 18 ~ 20 s
        // 两个电机停止
        // -----------------------------------------------------

        left_target_rpm = 32'sd0;
        right_target_rpm = 32'sd0;

        #2_000_000_000;


        $stop;

    end

endmodule