`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        done,
    output reg        frame_error
);
    localparam integer BIT_CLKS  = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_CLKS = BIT_CLKS / 2;
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    reg rx_d0, rx_d1, rx_d2;
    reg [1:0] state;
    reg [31:0] clk_count;
    reg [2:0] bit_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_d0 <= 1'b1;
            rx_d1 <= 1'b1;
            rx_d2 <= 1'b1;
        end else begin
            rx_d0 <= rx;
            rx_d1 <= rx_d0;
            rx_d2 <= rx_d1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            clk_count   <= 32'd0;
            bit_index   <= 3'd0;
            data        <= 8'h00;
            done        <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            done        <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 32'd0;
                    bit_index <= 3'd0;
                    if (!rx_d2)
                        state <= START;
                end

                START: begin
                    if (clk_count == HALF_CLKS - 1) begin
                        clk_count <= 32'd0;
                        if (!rx_d2)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count == BIT_CLKS - 1) begin
                        clk_count       <= 32'd0;
                        data[bit_index] <= rx_d2;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_count == BIT_CLKS - 1) begin
                        clk_count <= 32'd0;
                        state     <= IDLE;
                        if (rx_d2)
                            done <= 1'b1;
                        else
                            frame_error <= 1'b1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

