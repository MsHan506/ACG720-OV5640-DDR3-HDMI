`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,
    input  wire       start,
    output reg        tx,
    output reg        busy,
    output reg        done
);
    localparam integer BIT_CLKS = CLK_FREQ / BAUD_RATE;

    reg [31:0] clk_count;
    reg [3:0]  bit_index;
    reg [7:0]  data_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx           <= 1'b1;
            busy         <= 1'b0;
            done         <= 1'b0;
            clk_count    <= 32'd0;
            bit_index    <= 4'd0;
            data_latched <= 8'h00;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                tx        <= 1'b1;
                clk_count <= 32'd0;
                bit_index <= 4'd0;
                if (start) begin
                    data_latched <= data_in;
                    busy         <= 1'b1;
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
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end else begin
                clk_count <= clk_count + 1'b1;
            end
        end
    end
endmodule

