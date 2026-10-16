`timescale 1ns / 1ps

// LEGACY v1 sender. It is intentionally excluded from current projects.
// Use sensor_telemetry_tx_v3 instead.

module telemetry_packet_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115_200,
    parameter REPORT_HZ = 10
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire [15:0]        distance_mm,
    input  wire signed [15:0] roll_cdeg,
    input  wire signed [15:0] pitch_cdeg,
    input  wire signed [15:0] yaw_cdeg,
    output wire               uart_tx_pin
);
    localparam integer REPORT_CLKS = CLK_FREQ / REPORT_HZ;
    localparam IDLE = 2'd0;
    localparam SEND = 2'd1;
    localparam WAIT = 2'd2;

    reg [1:0] state;
    reg [31:0] report_count;
    reg [3:0] byte_index;
    reg [7:0] tx_data;
    reg       tx_start;
    wire      tx_busy;
    wire      tx_done;

    reg [15:0] distance_latched;
    reg signed [15:0] roll_latched;
    reg signed [15:0] pitch_latched;
    reg signed [15:0] yaw_latched;
    reg [7:0] checksum_latched;

    wire [7:0] snapshot_checksum =
        8'hAA + 8'h55 +
        distance_mm[7:0] + distance_mm[15:8] +
        roll_cdeg[7:0] + roll_cdeg[15:8] +
        pitch_cdeg[7:0] + pitch_cdeg[15:8] +
        yaw_cdeg[7:0] + yaw_cdeg[15:8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= IDLE;
            report_count       <= 32'd0;
            byte_index         <= 4'd0;
            tx_data            <= 8'h00;
            tx_start           <= 1'b0;
            distance_latched   <= 16'd0;
            roll_latched       <= 16'sd0;
            pitch_latched      <= 16'sd0;
            yaw_latched        <= 16'sd0;
            checksum_latched   <= 8'h00;
        end else begin
            tx_start <= 1'b0;
            case (state)
                IDLE: begin
                    if (report_count == REPORT_CLKS - 1) begin
                        report_count     <= 32'd0;
                        distance_latched <= distance_mm;
                        roll_latched     <= roll_cdeg;
                        pitch_latched    <= pitch_cdeg;
                        yaw_latched      <= yaw_cdeg;
                        checksum_latched <= snapshot_checksum;
                        byte_index       <= 4'd0;
                        state            <= SEND;
                    end else begin
                        report_count <= report_count + 1'b1;
                    end
                end

                SEND: begin
                    if (!tx_busy) begin
                        case (byte_index)
                            4'd0: tx_data <= 8'hAA;
                            4'd1: tx_data <= 8'h55;
                            4'd2: tx_data <= distance_latched[7:0];
                            4'd3: tx_data <= distance_latched[15:8];
                            4'd4: tx_data <= roll_latched[7:0];
                            4'd5: tx_data <= roll_latched[15:8];
                            4'd6: tx_data <= pitch_latched[7:0];
                            4'd7: tx_data <= pitch_latched[15:8];
                            4'd8: tx_data <= yaw_latched[7:0];
                            4'd9: tx_data <= yaw_latched[15:8];
                            default: tx_data <= checksum_latched;
                        endcase
                        tx_start <= 1'b1;
                        state    <= WAIT;
                    end
                end

                WAIT: begin
                    if (tx_done) begin
                        if (byte_index == 4'd10) begin
                            state <= IDLE;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            state      <= SEND;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_uart_tx (
        .clk(clk), .rst_n(rst_n),
        .data_in(tx_data), .start(tx_start),
        .tx(uart_tx_pin), .busy(tx_busy), .done(tx_done)
    );
endmodule
