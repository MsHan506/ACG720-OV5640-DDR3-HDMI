`timescale 1ns/1ps

// Fail-safe command receiver for a host/RK3588 semantic-navigation process.
// Packet (115200 8N1): A5 5A SEQ CMD LEFT RIGHT FLAGS XOR
// XOR is the XOR of bytes 0..6. LEFT/RIGHT are signed RPM (-80..80).
// Commands: 00 heartbeat, 01 arm, 02 velocity, 03 stop, 04 emergency stop.
module ai_uart_command_receiver #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer BAUD_RATE = 115_200,
    parameter integer WATCHDOG_MS = 350,
    parameter integer MAX_RPM = 80
)(
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx_pin,
    input  wire manual_override,
    output reg  active,
    output reg  start_pulse,
    output reg  stop_pulse,
    output reg signed [31:0] left_target_rpm,
    output reg signed [31:0] right_target_rpm,
    output reg  left_dir,
    output reg  right_dir,
    output reg  packet_valid,
    output reg [15:0] packet_error_count
);
    localparam integer WATCHDOG_CYCLES = (CLK_FREQ / 1000) * WATCHDOG_MS;
    localparam [7:0] CMD_HEARTBEAT = 8'h00;
    localparam [7:0] CMD_ARM       = 8'h01;
    localparam [7:0] CMD_VELOCITY  = 8'h02;
    localparam [7:0] CMD_STOP      = 8'h03;
    localparam [7:0] CMD_ESTOP     = 8'h04;

    wire [7:0] rx_data;
    wire rx_done;
    wire rx_frame_error;
    reg [2:0] index;
    reg [7:0] checksum;
    reg [7:0] command_byte;
    reg [7:0] left_byte;
    reg [7:0] right_byte;
    reg [31:0] watchdog_count;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_ai_uart_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rx_pin),
        .data(rx_data), .done(rx_done), .frame_error(rx_frame_error));

    function [7:0] clamp_magnitude;
        input [7:0] signed_value;
        reg [7:0] magnitude;
        begin
            magnitude = signed_value[7] ? (~signed_value + 1'b1) : signed_value;
            clamp_magnitude = (magnitude > MAX_RPM) ? MAX_RPM[7:0] : magnitude;
        end
    endfunction

    task apply_velocity;
        input [7:0] left_value;
        input [7:0] right_value;
        begin
            left_dir <= left_value[7];
            right_dir <= right_value[7];
            left_target_rpm <= {24'd0, clamp_magnitude(left_value)};
            right_target_rpm <= {24'd0, clamp_magnitude(right_value)};
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 1'b0;
            start_pulse <= 1'b0;
            stop_pulse <= 1'b0;
            left_target_rpm <= 0;
            right_target_rpm <= 0;
            left_dir <= 1'b0;
            right_dir <= 1'b0;
            packet_valid <= 1'b0;
            packet_error_count <= 16'd0;
            index <= 3'd0;
            checksum <= 8'd0;
            command_byte <= 8'd0;
            left_byte <= 8'd0;
            right_byte <= 8'd0;
            watchdog_count <= 32'd0;
        end else begin
            start_pulse <= 1'b0;
            stop_pulse <= 1'b0;
            packet_valid <= 1'b0;

            if (manual_override) begin
                active <= 1'b0;
                left_target_rpm <= 0;
                right_target_rpm <= 0;
                watchdog_count <= 0;
            end else if (active) begin
                if (watchdog_count >= WATCHDOG_CYCLES - 1) begin
                    active <= 1'b0;
                    stop_pulse <= 1'b1;
                    left_target_rpm <= 0;
                    right_target_rpm <= 0;
                    watchdog_count <= 0;
                end else begin
                    watchdog_count <= watchdog_count + 1'b1;
                end
            end

            if (rx_frame_error) begin
                index <= 0;
                if (packet_error_count != 16'hffff)
                    packet_error_count <= packet_error_count + 1'b1;
            end

            if (rx_done) begin
                case (index)
                    3'd0: begin
                        if (rx_data == 8'hA5) begin
                            checksum <= 8'hA5;
                            index <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (rx_data == 8'h5A) begin
                            checksum <= checksum ^ rx_data;
                            index <= 3'd2;
                        end else begin
                            index <= (rx_data == 8'hA5) ? 3'd1 : 3'd0;
                            checksum <= 8'hA5;
                        end
                    end
                    3'd2: begin // sequence number
                        checksum <= checksum ^ rx_data;
                        index <= 3'd3;
                    end
                    3'd3: begin
                        command_byte <= rx_data;
                        checksum <= checksum ^ rx_data;
                        index <= 3'd4;
                    end
                    3'd4: begin
                        left_byte <= rx_data;
                        checksum <= checksum ^ rx_data;
                        index <= 3'd5;
                    end
                    3'd5: begin
                        right_byte <= rx_data;
                        checksum <= checksum ^ rx_data;
                        index <= 3'd6;
                    end
                    3'd6: begin // flags, currently reserved
                        checksum <= checksum ^ rx_data;
                        index <= 3'd7;
                    end
                    3'd7: begin
                        index <= 3'd0;
                        if (rx_data == checksum) begin
                            packet_valid <= 1'b1;
                            case (command_byte)
                                CMD_HEARTBEAT: watchdog_count <= 0;
                                CMD_ARM: begin
                                    watchdog_count <= 0;
                                    active <= 1'b1;
                                    start_pulse <= 1'b1;
                                    apply_velocity(left_byte, right_byte);
                                end
                                CMD_VELOCITY: begin
                                    watchdog_count <= 0;
                                    if (active)
                                        apply_velocity(left_byte, right_byte);
                                end
                                CMD_STOP: begin
                                    left_target_rpm <= 0;
                                    right_target_rpm <= 0;
                                    stop_pulse <= 1'b1;
                                end
                                CMD_ESTOP: begin
                                    active <= 1'b0;
                                    left_target_rpm <= 0;
                                    right_target_rpm <= 0;
                                    stop_pulse <= 1'b1;
                                end
                                default: begin
                                    if (packet_error_count != 16'hffff)
                                        packet_error_count <= packet_error_count + 1'b1;
                                end
                            endcase
                        end else if (packet_error_count != 16'hffff) begin
                            packet_error_count <= packet_error_count + 1'b1;
                        end
                    end
                endcase
            end
        end
    end
endmodule
