`timescale 1ns / 1ps

module moving_average4_unsigned (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in,
    input  wire        sample_valid,
    output reg  [15:0] average_out,
    output reg         average_valid
);
    reg [15:0] s0, s1, s2, s3;
    reg [2:0] sample_count;
    reg [17:0] sum_next;
    reg [17:0] average_next;

    always @(*) begin
        case (sample_count)
            3'd0: sum_next = {2'd0, sample_in};
            3'd1: sum_next = {2'd0, s0} + sample_in;
            3'd2: sum_next = {2'd0, s0} + s1 + sample_in;
            default: sum_next = {2'd0, s0} + s1 + s2 + sample_in;
        endcase

        case (sample_count)
            3'd0: average_next = sum_next;
            3'd1: average_next = sum_next >> 1;
            3'd2: average_next = sum_next / 3;
            default: average_next = sum_next >> 2;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0 <= 0; s1 <= 0; s2 <= 0; s3 <= 0;
            sample_count <= 0;
            average_out <= 0;
            average_valid <= 1'b0;
        end else begin
            average_valid <= 1'b0;
            if (sample_valid) begin
                s3 <= s2;
                s2 <= s1;
                s1 <= s0;
                s0 <= sample_in;

                case (sample_count)
                    3'd0: begin
                        average_out <= sample_in;
                        sample_count <= 3'd1;
                    end
                    3'd1: begin
                        average_out <= average_next[15:0];
                        sample_count <= 3'd2;
                    end
                    3'd2: begin
                        average_out <= average_next[15:0];
                        sample_count <= 3'd3;
                    end
                    default: begin
                        average_out <= average_next[15:0];
                        sample_count <= 3'd4;
                    end
                endcase
                average_valid <= 1'b1;
            end
        end
    end
endmodule
