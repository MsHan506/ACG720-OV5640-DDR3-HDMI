`timescale 1ns / 1ps

// ACG720-GW5AT60 最小上板测试：LED2 持续闪烁。
module led_blink_top (
    input  wire clk_50m,
    output wire led2
);
    reg [24:0] counter = 25'd0;

    always @(posedge clk_50m) begin
        counter <= counter + 1'b1;
    end

    // 无论板载 LED 是高电平还是低电平点亮，都能观察到明暗交替。
    assign led2 = counter[24];
endmodule
