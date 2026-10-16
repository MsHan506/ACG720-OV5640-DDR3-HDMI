`timescale 1ns/1ps

// Debounced start and immediate-priority stop latch.  A rejected start press
// is consumed, so clearing an obstacle cannot cause an unexpected late start;
// the operator must release and press START again.
module safe_start_stop_latch #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start_button_n,
    input  wire stop_button_n,
    input  wire remote_start_pulse,
    input  wire remote_stop_pulse,
    input  wire start_allowed,
    output reg  enabled
);
    localparam integer DEBOUNCE_CYCLES = (CLK_FREQ / 1000) * DEBOUNCE_MS;
    reg [1:0] start_sync;
    reg [1:0] stop_sync;
    reg [31:0] start_counter;
    reg start_consumed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_sync <= 2'b11;
            stop_sync <= 2'b11;
            start_counter <= 32'd0;
            start_consumed <= 1'b0;
            enabled <= 1'b0;
        end else begin
            start_sync <= {start_sync[0], start_button_n};
            stop_sync <= {stop_sync[0], stop_button_n};

            if (!stop_sync[1] || remote_stop_pulse)
                enabled <= 1'b0;

            // A decoded remote command is already a clean one-clock event, so
            // it does not pass through the mechanical-button debounce path.
            if (remote_start_pulse && start_allowed && stop_sync[1] &&
                !remote_stop_pulse)
                enabled <= 1'b1;

            if (start_sync[1]) begin
                start_counter <= 32'd0;
                start_consumed <= 1'b0;
            end else if (!start_consumed) begin
                if (start_counter >= DEBOUNCE_CYCLES - 1) begin
                    start_counter <= 32'd0;
                    start_consumed <= 1'b1;
                    if (start_allowed && stop_sync[1])
                        enabled <= 1'b1;
                end else begin
                    start_counter <= start_counter + 1'b1;
                end
            end
        end
    end
endmodule
