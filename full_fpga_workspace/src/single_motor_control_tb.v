`timescale 1ns/1ps

module single_motor_control_tb;

    // =========================================================
    // 仿真参数
    // =========================================================

    localparam integer CLK_FREQ = 1_000_000;
    localparam integer PWM_FREQ = 20_000;

    localparam integer COUNTS_PER_REV = 1456;
    localparam integer SAMPLE_TIME_MS = 10;

    // 模拟电机最大转速
    localparam integer MAX_RPM = 400;

    // 电机响应速度
    localparam integer RESPONSE_DIV = 20;


    // =========================================================
    // 时钟
    // =========================================================

    reg clk;

    initial begin
        clk = 1'b0;
        forever #500 clk = ~clk;
    end


    // =========================================================
    // 输入
    // =========================================================

    reg rst_n;

    reg signed [31:0] target_rpm;

    reg dir;

    reg enc_a;
    reg enc_b;


    // =========================================================
    // 输出
    // =========================================================

    wire pwm_out;
    wire in1;
    wire in2;

    wire signed [31:0] encoder_count;

    wire signed [31:0] actual_rpm;

    wire [9:0] duty;
    wire [9:0] duty_pi;

    wire signed [31:0] error;
    wire signed [31:0] integral;


    // =========================================================
    // 被测模块
    // =========================================================

    single_motor_control #(
        .CLK_FREQ(CLK_FREQ),
        .PWM_FREQ(PWM_FREQ),

        .COUNTS_PER_REV(COUNTS_PER_REV),
        .SAMPLE_TIME_MS(SAMPLE_TIME_MS),

        .KP(100),
        .KI(10),
        .SCALE(1000),

        .OUT_MAX(1000),
        .I_MAX(120000),

        .DEAD_ZONE(0),
        .DUTY_MAX(1000)

    ) dut (

        .clk(clk),
        .rst_n(rst_n),

        .target_rpm(target_rpm),
        .dir(dir),

        .enc_a(enc_a),
        .enc_b(enc_b),

        .pwm_out(pwm_out),
        .in1(in1),
        .in2(in2),

        .encoder_count(encoder_count),
        .actual_rpm(actual_rpm),

        .duty(duty),
        .duty_pi(duty_pi),

        .error(error),
        .integral(integral)
    );


    // =========================================================
    // 简单电机模型
    // 直接写在 TB 中
    // =========================================================

    reg signed [31:0] motor_rpm;

    reg [31:0] motor_counter;

    reg signed [31:0] motor_target_rpm;


    // 根据 duty 得到电机目标转速
    always @(*) begin

        motor_target_rpm =
            duty * MAX_RPM / 1000;

    end


    // 电机一阶响应
    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            motor_counter <= 0;
            motor_rpm <= 0;

        end
        else begin

            // 每 1ms 更新一次电机速度

            if (motor_counter >= 1000 - 1) begin

                motor_counter <= 0;

                motor_rpm <= motor_rpm +
                    (motor_target_rpm - motor_rpm)
                    / RESPONSE_DIV;

            end
            else begin

                motor_counter <= motor_counter + 1'b1;

            end

        end

    end


    // =========================================================
    // 简单编码器模型
    // 直接根据 motor_rpm 产生 A/B
    // =========================================================

    reg [31:0] encoder_counter;

    reg [1:0] encoder_state;

    reg [31:0] encoder_period;


    always @(*) begin

        if (motor_rpm <= 0) begin

            encoder_period = 32'hFFFFFFFF;

        end
        else begin

            encoder_period =
                (CLK_FREQ * 60) /
                (motor_rpm * COUNTS_PER_REV);

            if (encoder_period < 4)
                encoder_period = 4;

        end

    end


    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            encoder_counter <= 0;
            encoder_state <= 2'b00;

        end
        else begin

            if (motor_rpm <= 0) begin

                encoder_counter <= 0;
                encoder_state <= 2'b00;

            end
            else if (encoder_counter >= encoder_period - 1) begin

                encoder_counter <= 0;

                case (encoder_state)

                    // 00 -> 01
                    2'b00:
                        encoder_state <= 2'b01;

                    // 01 -> 11
                    2'b01:
                        encoder_state <= 2'b11;

                    // 11 -> 10
                    2'b11:
                        encoder_state <= 2'b10;

                    // 10 -> 00
                    2'b10:
                        encoder_state <= 2'b00;

                    default:
                        encoder_state <= 2'b00;

                endcase

            end
            else begin

                encoder_counter <= encoder_counter + 1'b1;

            end

        end

    end


    // 把状态转换成 A/B

    always @(*) begin

        enc_a = encoder_state[1];
        enc_b = encoder_state[0];

    end


    // =========================================================
    // 测试过程
    // =========================================================

    initial begin

    // =====================================================
    // 初始状态
    // =====================================================

    rst_n = 1'b0;

    target_rpm = 32'sd0;

    dir = 1'b0;


    // =====================================================
    // 复位
    // =====================================================

    #5000;

    rst_n = 1'b1;


    // =====================================================
    // 0 ~ 20 ms
    // 目标速度 = 0 RPM
    // =====================================================

    #20_000_000;


    // =====================================================
    // 20 ms ~ 5 s
    // 目标速度 = 300 RPM
    // =====================================================

    target_rpm = 32'sd300;

    #2_980_000_000;
#2_000_000_000;

    // =====================================================
    // 5 s ~ 10 s
    // 目标速度 = 150 RPM
    // =====================================================

    target_rpm = 32'sd150;

    #3_000_000_000;
#2_000_000_000;

    // =====================================================
    // 10 s ~ 15 s
    // 目标速度 = 300 RPM
    // =====================================================

    target_rpm = 32'sd300;

    #3_000_000_000;
#2_000_000_000;

    // =====================================================
    // 15 s ~ 16 s
    // 目标速度 = 0 RPM
    // =====================================================

    target_rpm = 32'sd0;

    #1_000_000_000;


    // =====================================================
    // 仿真结束
    // =====================================================

    $stop;

end

endmodule