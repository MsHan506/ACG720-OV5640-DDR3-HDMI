`timescale 1ns / 1ps

module angle_iir_filter #(
    parameter SHIFT = 2
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [15:0] angle_in_cdeg,
    input  wire               sample_valid,
    output reg  signed [15:0] angle_out_cdeg,
    output reg                output_valid
);
    reg initialized;
    reg signed [16:0] difference;
    reg signed [16:0] next_angle;

    always @(*) begin
        difference = $signed({angle_in_cdeg[15], angle_in_cdeg}) -
                     $signed({angle_out_cdeg[15], angle_out_cdeg});
        if (difference > 17'sd18000)
            difference = difference - 17'sd36000;
        else if (difference < -17'sd18000)
            difference = difference + 17'sd36000;

        next_angle = $signed({angle_out_cdeg[15], angle_out_cdeg}) +
                     (difference >>> SHIFT);
        if (next_angle >= 17'sd18000)
            next_angle = next_angle - 17'sd36000;
        else if (next_angle < -17'sd18000)
            next_angle = next_angle + 17'sd36000;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            initialized    <= 1'b0;
            angle_out_cdeg <= 16'sd0;
            output_valid   <= 1'b0;
        end else begin
            output_valid <= 1'b0;
            if (sample_valid) begin
                if (!initialized) begin
                    initialized    <= 1'b1;
                    angle_out_cdeg <= angle_in_cdeg;
                end else begin
                    angle_out_cdeg <= next_angle[15:0];
                end
                output_valid <= 1'b1;
            end
        end
    end
endmodule

