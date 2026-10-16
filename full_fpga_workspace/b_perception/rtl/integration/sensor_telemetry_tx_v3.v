`timescale 1ns / 1ps

// Sensor telemetry v3
// Frame: A5 5A | version | type | payload_len | payload | CRC16 little-endian
// CRC-16/CCITT-FALSE covers version through the last payload byte.
module sensor_telemetry_tx_v3 #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 115_200,
    parameter integer REPORT_HZ = 20,
    parameter integer FRESH_MS  = 500
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire [15:0]        distance_mm,
    input  wire [15:0]        tof_strength,
    input  wire               distance_valid,
    input  wire signed [15:0] roll_cdeg,
    input  wire signed [15:0] pitch_cdeg,
    input  wire signed [15:0] yaw_cdeg,
    input  wire               imu_valid,
    input  wire [15:0]        tof_error_count,
    input  wire [15:0]        imu_error_count,
    output wire               uart_tx_pin,
    output reg                frame_done,
    output reg                frame_toggle
);
    localparam integer REPORT_CLKS = CLK_FREQ / REPORT_HZ;
    localparam integer MS_CLKS     = CLK_FREQ / 1000;
    localparam integer FRESH_CLKS  = (CLK_FREQ / 1000) * FRESH_MS;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEND = 2'd1;
    localparam [1:0] WAIT = 2'd2;

    reg [1:0]  state;
    reg [31:0] report_count;
    reg [31:0] millisecond_count;
    reg [31:0] uptime_ms;
    reg [31:0] tof_age;
    reg [31:0] imu_age;
    reg        tof_seen;
    reg        imu_seen;

    reg [5:0]  byte_index;
    reg [15:0] frame_sequence;
    reg [15:0] sequence_latched;
    reg [7:0]  status_latched;
    reg [15:0] distance_latched;
    reg [15:0] strength_latched;
    reg signed [15:0] roll_latched;
    reg signed [15:0] pitch_latched;
    reg signed [15:0] yaw_latched;
    reg [15:0] tof_errors_latched;
    reg [15:0] imu_errors_latched;
    reg [31:0] uptime_latched;
    reg [15:0] crc_latched;

    wire tof_fresh = tof_seen && (tof_age < FRESH_CLKS);
    wire imu_fresh = imu_seen && (imu_age < FRESH_CLKS);
    wire [7:0] status_now = {
        2'b00,
        (imu_error_count != 16'd0),
        (tof_error_count != 16'd0),
        imu_fresh,
        tof_fresh,
        imu_seen,
        tof_seen
    };

    function [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0] data_in;
        integer i;
        reg [15:0] crc_work;
        begin
            crc_work = crc_in ^ {data_in, 8'h00};
            for (i = 0; i < 8; i = i + 1) begin
                if (crc_work[15])
                    crc_work = (crc_work << 1) ^ 16'h1021;
                else
                    crc_work = crc_work << 1;
            end
            crc16_next = crc_work;
        end
    endfunction

    wire [15:0] crc00 = crc16_next(16'hFFFF, 8'h01);
    wire [15:0] crc01 = crc16_next(crc00, 8'h10);
    wire [15:0] crc02 = crc16_next(crc01, 8'd21);
    wire [15:0] crc03 = crc16_next(crc02, frame_sequence[7:0]);
    wire [15:0] crc04 = crc16_next(crc03, frame_sequence[15:8]);
    wire [15:0] crc05 = crc16_next(crc04, status_now);
    wire [15:0] crc06 = crc16_next(crc05, distance_mm[7:0]);
    wire [15:0] crc07 = crc16_next(crc06, distance_mm[15:8]);
    wire [15:0] crc08 = crc16_next(crc07, tof_strength[7:0]);
    wire [15:0] crc09 = crc16_next(crc08, tof_strength[15:8]);
    wire [15:0] crc10 = crc16_next(crc09, roll_cdeg[7:0]);
    wire [15:0] crc11 = crc16_next(crc10, roll_cdeg[15:8]);
    wire [15:0] crc12 = crc16_next(crc11, pitch_cdeg[7:0]);
    wire [15:0] crc13 = crc16_next(crc12, pitch_cdeg[15:8]);
    wire [15:0] crc14 = crc16_next(crc13, yaw_cdeg[7:0]);
    wire [15:0] crc15 = crc16_next(crc14, yaw_cdeg[15:8]);
    wire [15:0] crc16 = crc16_next(crc15, tof_error_count[7:0]);
    wire [15:0] crc17 = crc16_next(crc16, tof_error_count[15:8]);
    wire [15:0] crc18 = crc16_next(crc17, imu_error_count[7:0]);
    wire [15:0] crc19 = crc16_next(crc18, imu_error_count[15:8]);
    wire [15:0] crc20 = crc16_next(crc19, uptime_ms[7:0]);
    wire [15:0] crc21 = crc16_next(crc20, uptime_ms[15:8]);
    wire [15:0] crc22 = crc16_next(crc21, uptime_ms[23:16]);
    wire [15:0] crc23 = crc16_next(crc22, uptime_ms[31:24]);

    reg [7:0] tx_byte;
    always @(*) begin
        case (byte_index)
            6'd0:  tx_byte = 8'hA5;
            6'd1:  tx_byte = 8'h5A;
            6'd2:  tx_byte = 8'h01;
            6'd3:  tx_byte = 8'h10;
            6'd4:  tx_byte = 8'd21;
            6'd5:  tx_byte = sequence_latched[7:0];
            6'd6:  tx_byte = sequence_latched[15:8];
            6'd7:  tx_byte = status_latched;
            6'd8:  tx_byte = distance_latched[7:0];
            6'd9:  tx_byte = distance_latched[15:8];
            6'd10: tx_byte = strength_latched[7:0];
            6'd11: tx_byte = strength_latched[15:8];
            6'd12: tx_byte = roll_latched[7:0];
            6'd13: tx_byte = roll_latched[15:8];
            6'd14: tx_byte = pitch_latched[7:0];
            6'd15: tx_byte = pitch_latched[15:8];
            6'd16: tx_byte = yaw_latched[7:0];
            6'd17: tx_byte = yaw_latched[15:8];
            6'd18: tx_byte = tof_errors_latched[7:0];
            6'd19: tx_byte = tof_errors_latched[15:8];
            6'd20: tx_byte = imu_errors_latched[7:0];
            6'd21: tx_byte = imu_errors_latched[15:8];
            6'd22: tx_byte = uptime_latched[7:0];
            6'd23: tx_byte = uptime_latched[15:8];
            6'd24: tx_byte = uptime_latched[23:16];
            6'd25: tx_byte = uptime_latched[31:24];
            6'd26: tx_byte = crc_latched[7:0];
            default: tx_byte = crc_latched[15:8];
        endcase
    end

    wire tx_ready;
    wire tx_done;
    wire tx_valid = (state == SEND);

    uart_tx_v3 #(
        .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk), .rst_n(rst_n), .data(tx_byte), .valid(tx_valid),
        .ready(tx_ready), .tx(uart_tx_pin), .done(tx_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            millisecond_count <= 32'd0;
            uptime_ms         <= 32'd0;
            tof_age           <= FRESH_CLKS;
            imu_age           <= FRESH_CLKS;
            tof_seen          <= 1'b0;
            imu_seen          <= 1'b0;
        end else begin
            if (millisecond_count == MS_CLKS - 1) begin
                millisecond_count <= 32'd0;
                uptime_ms <= uptime_ms + 1'b1;
            end else begin
                millisecond_count <= millisecond_count + 1'b1;
            end

            if (distance_valid) begin
                tof_age  <= 32'd0;
                tof_seen <= 1'b1;
            end else if (tof_age < FRESH_CLKS) begin
                tof_age <= tof_age + 1'b1;
            end

            if (imu_valid) begin
                imu_age  <= 32'd0;
                imu_seen <= 1'b1;
            end else if (imu_age < FRESH_CLKS) begin
                imu_age <= imu_age + 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= IDLE;
            report_count        <= 32'd0;
            byte_index          <= 6'd0;
            frame_sequence      <= 16'd0;
            sequence_latched    <= 16'd0;
            status_latched      <= 8'd0;
            distance_latched    <= 16'd0;
            strength_latched    <= 16'd0;
            roll_latched        <= 16'sd0;
            pitch_latched       <= 16'sd0;
            yaw_latched         <= 16'sd0;
            tof_errors_latched  <= 16'd0;
            imu_errors_latched  <= 16'd0;
            uptime_latched      <= 32'd0;
            crc_latched         <= 16'hFFFF;
            frame_done          <= 1'b0;
            frame_toggle        <= 1'b0;
        end else begin
            frame_done <= 1'b0;
            case (state)
                IDLE: begin
                    if (report_count == REPORT_CLKS - 1) begin
                        report_count       <= 32'd0;
                        byte_index         <= 6'd0;
                        sequence_latched   <= frame_sequence;
                        status_latched     <= status_now;
                        distance_latched   <= distance_mm;
                        strength_latched   <= tof_strength;
                        roll_latched       <= roll_cdeg;
                        pitch_latched      <= pitch_cdeg;
                        yaw_latched        <= yaw_cdeg;
                        tof_errors_latched <= tof_error_count;
                        imu_errors_latched <= imu_error_count;
                        uptime_latched     <= uptime_ms;
                        crc_latched        <= crc23;
                        frame_sequence     <= frame_sequence + 1'b1;
                        state              <= SEND;
                    end else begin
                        report_count <= report_count + 1'b1;
                    end
                end

                SEND: begin
                    if (tx_ready)
                        state <= WAIT;
                end

                WAIT: begin
                    if (tx_done) begin
                        if (byte_index == 6'd27) begin
                            frame_done   <= 1'b1;
                            frame_toggle <= ~frame_toggle;
                            state        <= IDLE;
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
endmodule
