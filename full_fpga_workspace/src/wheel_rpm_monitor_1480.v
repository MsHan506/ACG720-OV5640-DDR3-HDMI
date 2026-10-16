`timescale 1ns/1ps

// Timing-safe RPM monitor for the measured 1480 quadrature counts/revolution
// and a 100 ms window.  RPM = delta_count * 600 / 1480 = delta_count * 15 / 37.
// Division is performed over several clocks by repeated subtraction; it is a
// display/telemetry path only and never delays the motor safety path.
module wheel_rpm_monitor_1480 #(
    parameter integer CLK_FREQ = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [31:0] count,
    output reg  signed [31:0] rpm,
    output reg  update_en
);
    localparam integer SAMPLE_COUNT = CLK_FREQ / 10;
    reg [31:0] sample_counter;
    reg signed [31:0] last_count;
    reg [35:0] remainder;
    reg [31:0] quotient;
    reg negative;
    reg busy;
    wire signed [31:0] count_delta = count - last_count;
    wire [31:0] delta_magnitude = count_delta[31] ?
        (~count_delta + 1'b1) : count_delta;
    wire [35:0] scaled_delta =
        ({4'd0, delta_magnitude} << 4) - {4'd0, delta_magnitude};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 32'd0;
            last_count <= 32'sd0;
            remainder <= 36'd0;
            quotient <= 32'd0;
            negative <= 1'b0;
            busy <= 1'b0;
            rpm <= 32'sd0;
            update_en <= 1'b0;
        end else begin
            update_en <= 1'b0;

            if (sample_counter >= SAMPLE_COUNT - 1) begin
                sample_counter <= 32'd0;
                last_count <= count;
                if (!busy) begin
                    remainder <= scaled_delta;
                    quotient <= 32'd0;
                    negative <= count_delta[31];
                    busy <= 1'b1;
                end
            end else begin
                sample_counter <= sample_counter + 1'b1;
            end

            if (busy) begin
                if (remainder >= 36'd37) begin
                    remainder <= remainder - 36'd37;
                    quotient <= quotient + 1'b1;
                end else begin
                    rpm <= negative ? -$signed(quotient) : $signed(quotient);
                    update_en <= 1'b1;
                    busy <= 1'b0;
                end
            end
        end
    end
endmodule

