`timescale 1ns / 1ps

module tb_filters;
    reg clk = 0;
    reg rst_n = 0;
    reg [15:0] u_sample = 0;
    reg u_valid = 0;
    reg signed [15:0] angle_in = 0;
    reg angle_valid = 0;

    wire [15:0] gated;
    wire gated_valid;
    wire rejected;
    wire [15:0] average;
    wire average_valid;
    wire signed [15:0] angle_out;
    wire angle_out_valid;

    tof_outlier_gate #(.MAX_STEP_MM(1000), .REBASE_COUNT(3)) gate (
        .clk(clk), .rst_n(rst_n), .sample_in(u_sample), .sample_valid(u_valid),
        .sample_out(gated), .output_valid(gated_valid), .rejected(rejected)
    );
    moving_average4_unsigned average4 (
        .clk(clk), .rst_n(rst_n), .sample_in(gated), .sample_valid(gated_valid),
        .average_out(average), .average_valid(average_valid)
    );
    angle_iir_filter #(.SHIFT(2)) yaw_filter (
        .clk(clk), .rst_n(rst_n), .angle_in_cdeg(angle_in),
        .sample_valid(angle_valid), .angle_out_cdeg(angle_out),
        .output_valid(angle_out_valid)
    );

    always #5 clk = ~clk;

    task push_u;
        input [15:0] value;
        begin
            @(negedge clk); u_sample = value; u_valid = 1;
            @(negedge clk); u_valid = 0;
            repeat (2) @(negedge clk);
        end
    endtask
    task push_angle;
        input signed [15:0] value;
        begin
            @(negedge clk); angle_in = value; angle_valid = 1;
            @(negedge clk); angle_valid = 0;
            repeat (2) @(negedge clk);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk); rst_n = 1;
        push_u(100); push_u(200); push_u(300); push_u(400);
        if (average != 250) begin
            $display("FAIL moving average: %0d", average); $finish;
        end
        push_u(5000); push_u(5050); push_u(5100);
        if (gated != 5100) begin
            $display("FAIL outlier rebase: %0d", gated); $finish;
        end
        push_angle(17900); push_angle(-17900);
        if (angle_out != 17950) begin
            $display("FAIL wrapped angle filter: %0d", angle_out); $finish;
        end
        $display("PASS tb_filters");
        $finish;
    end
endmodule

