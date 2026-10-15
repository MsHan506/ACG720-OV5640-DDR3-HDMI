`timescale 1ns / 1ps

module signed_iir_filter #(
    parameter SHIFT = 2
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [15:0] sample_in,
    input  wire               sample_valid,
    output reg  signed [15:0] filtered_out,
    output reg                output_valid
);
    reg initialized;
    reg signed [16:0] difference;
    reg signed [16:0] next_value;

    always @(*) begin
        difference = $signed({sample_in[15], sample_in}) -
                     $signed({filtered_out[15], filtered_out});
        next_value = $signed({filtered_out[15], filtered_out}) +
                     (difference >>> SHIFT);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            initialized  <= 1'b0;
            filtered_out <= 16'sd0;
            output_valid <= 1'b0;
        end else begin
            output_valid <= 1'b0;
            if (sample_valid) begin
                if (!initialized) begin
                    initialized  <= 1'b1;
                    filtered_out <= sample_in;
                end else begin
                    filtered_out <= next_value[15:0];
                end
                output_valid <= 1'b1;
            end
        end
    end
endmodule
