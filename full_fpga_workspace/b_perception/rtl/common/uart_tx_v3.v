`timescale 1ns / 1ps

// Byte-oriented 8N1 UART transmitter.
// A byte is accepted only when valid && ready are high on the same clock edge.
module uart_tx_v3 #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data,
    input  wire       valid,
    output reg        ready,
    output reg        tx,
    output reg        done
);
    localparam integer BIT_CLKS = (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;

    reg [31:0] clk_count;
    reg [3:0]  bit_index;
    reg [7:0]  data_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready        <= 1'b1;
            tx           <= 1'b1;
            done         <= 1'b0;
            clk_count    <= 32'd0;
            bit_index    <= 4'd0;
            data_latched <= 8'h00;
        end else begin
            done <= 1'b0;

            if (ready) begin
                tx        <= 1'b1;
                clk_count <= 32'd0;
                bit_index <= 4'd0;
                if (valid) begin
                    data_latched <= data;
                    ready        <= 1'b0;
                    tx           <= 1'b0;
                end
            end else if (clk_count == BIT_CLKS - 1) begin
                clk_count <= 32'd0;
                if (bit_index < 4'd8) begin
                    tx        <= data_latched[bit_index];
                    bit_index <= bit_index + 1'b1;
                end else if (bit_index == 4'd8) begin
                    tx        <= 1'b1;
                    bit_index <= 4'd9;
                end else begin
                    tx    <= 1'b1;
                    ready <= 1'b1;
                    done  <= 1'b1;
                end
            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end
    end
endmodule

