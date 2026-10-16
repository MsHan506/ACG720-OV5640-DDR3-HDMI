module motor_model #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer MOTOR_UPDATE_MS = 1,
    parameter integer LOAD_RPM = 30
)(
    input wire clk,
    input wire rst_n,
    input wire [9:0] duty,
    output reg signed [31:0] actual_rpm
);
    // 1 ms 对应的时钟数
    localparam integer UPDATE_COUNT =
        CLK_FREQ / 1000 * MOTOR_UPDATE_MS;
    localparam integer COUNTER_WIDTH =
        $clog2(UPDATE_COUNT);
    reg [COUNTER_WIDTH-1:0] update_counter;
    reg signed [31:0] target_rpm;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            update_counter <= 0;
            actual_rpm <= 0;
        end
        else begin
            if (update_counter >= UPDATE_COUNT - 1) begin
                update_counter <= 0;
                // ==========================
                // PWM → 理想电机转速
                // ==========================
                target_rpm = duty / 2;
                // ==========================
                // 模拟负载
                // ==========================
                if (target_rpm > LOAD_RPM)
                    target_rpm = target_rpm - LOAD_RPM;
                else
                    target_rpm = 0;
                // ==========================
                // 模拟电机惯性
                // ==========================
                actual_rpm <= actual_rpm +
                              (target_rpm - actual_rpm) / 10;
            end
            else begin
                update_counter <= update_counter + 1'b1;
            end
        end
    end
endmodule