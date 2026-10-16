`timescale 1ns / 1ps

module tof_outlier_gate #(
    parameter MAX_STEP_MM  = 16'd1500,
    parameter REBASE_COUNT = 3
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in,
    input  wire        sample_valid,
    output reg  [15:0] sample_out,
    output reg         output_valid,
    output reg         rejected
);
    reg initialized;
    reg [15:0] candidate;
    reg [2:0] candidate_count;

    wire [15:0] main_diff = (sample_in >= sample_out) ?
                            (sample_in - sample_out) : (sample_out - sample_in);
    wire [15:0] candidate_diff = (sample_in >= candidate) ?
                                 (sample_in - candidate) : (candidate - sample_in);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            initialized     <= 1'b0;
            candidate       <= 16'd0;
            candidate_count <= 3'd0;
            sample_out      <= 16'd0;
            output_valid    <= 1'b0;
            rejected        <= 1'b0;
        end else begin
            output_valid <= 1'b0;
            rejected     <= 1'b0;

            if (sample_valid) begin
                if (!initialized) begin
                    initialized     <= 1'b1;
                    sample_out      <= sample_in;
                    output_valid    <= 1'b1;
                    candidate_count <= 3'd0;
                end else if (main_diff <= MAX_STEP_MM) begin
                    sample_out      <= sample_in;
                    output_valid    <= 1'b1;
                    candidate_count <= 3'd0;
                end else begin
                    rejected <= 1'b1;
                    if (candidate_count != 0 &&
                        candidate_diff <= (MAX_STEP_MM >> 2)) begin
                        if (candidate_count == REBASE_COUNT - 1) begin
                            sample_out      <= sample_in;
                            output_valid    <= 1'b1;
                            candidate_count <= 3'd0;
                        end else begin
                            candidate       <= sample_in;
                            candidate_count <= candidate_count + 1'b1;
                        end
                    end else begin
                        candidate       <= sample_in;
                        candidate_count <= 3'd1;
                    end
                end
            end
        end
    end
endmodule

