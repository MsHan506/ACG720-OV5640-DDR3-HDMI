`timescale 1ns / 1ps

// Coherent, latest-value CDC (not an event queue). Both sides share reset.
// Source holds data until acknowledgment; request follows data by one source
// edge. Destination waits one extra edge after request synchronization.
module cdc_snapshot_mailbox #(parameter WIDTH = 13) (
    input wire source_clk, destination_clk, rst_n,
    input wire [WIDTH-1:0] source_data,
    output reg [WIDTH-1:0] destination_data
);
    reg [WIDTH-1:0] held_data;
    reg request, pending, acknowledge, capture_pending;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *) reg ack_meta, ack_sync;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *) reg request_meta, request_sync;
    always @(posedge source_clk or negedge rst_n) begin
        if (!rst_n) begin
            held_data <= 0; request <= 0; pending <= 0;
            ack_meta <= 0; ack_sync <= 0;
        end else begin
            ack_meta <= acknowledge; ack_sync <= ack_meta;
            if (pending) begin
                request <= ~request; pending <= 0;
            end else if (ack_sync == request) begin
                held_data <= source_data; pending <= 1;
            end
        end
    end
    always @(posedge destination_clk or negedge rst_n) begin
        if (!rst_n) begin
            destination_data <= 0; acknowledge <= 0;
            request_meta <= 0; request_sync <= 0; capture_pending <= 0;
        end else begin
            request_meta <= request; request_sync <= request_meta;
            if (capture_pending) begin
                destination_data <= held_data;
                acknowledge <= request_sync; capture_pending <= 0;
            end else if (request_sync != acknowledge) capture_pending <= 1;
        end
    end
endmodule

// Iterative double-dabble conversion.  Spreading the conversion over sixteen
// clocks avoids a deep single-cycle arithmetic path in the 50 MHz domain.
module bin16_to_bcd5_seq (
    input wire clk,
    input wire rst_n,
    input wire [15:0] value,
    output reg [19:0] bcd,
    output wire sample,
    output reg done
);
    reg [35:0] shift;
    reg [4:0] bit_count;
    reg busy;
    reg [35:0] adjusted;
    assign sample = !busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift <= 36'd0;
            bit_count <= 5'd0;
            busy <= 1'b0;
            bcd <= 20'd0;
            done <= 1'b0;
            adjusted = 36'd0;
        end else if (!busy) begin
            done <= 1'b0;
            shift <= {20'd0, value};
            bit_count <= 5'd0;
            busy <= 1'b1;
        end else begin
            done <= 1'b0;
            adjusted = shift;
            if (adjusted[19:16] >= 5) adjusted[19:16] = adjusted[19:16] + 4'd3;
            if (adjusted[23:20] >= 5) adjusted[23:20] = adjusted[23:20] + 4'd3;
            if (adjusted[27:24] >= 5) adjusted[27:24] = adjusted[27:24] + 4'd3;
            if (adjusted[31:28] >= 5) adjusted[31:28] = adjusted[31:28] + 4'd3;
            if (adjusted[35:32] >= 5) adjusted[35:32] = adjusted[35:32] + 4'd3;
            adjusted = adjusted << 1;
            shift <= adjusted;
            if (bit_count == 5'd15) begin
                bcd <= adjusted[35:16];
                done <= 1'b1;
                busy <= 1'b0;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end
    end
endmodule

// Compact 5x7 text overlay for the live sensor values.
// Angles are shown in degrees with one decimal place; distance is millimetres.
module sensor_osd_overlay (
    input  wire        data_clk,
    input  wire        data_rst_n,
    input  wire        pixel_clk,
    input  wire        video_de,
    input  wire        hsync_in,
    input  wire        vsync_in,
    input  wire [11:0] pixel_x,
    input  wire [11:0] pixel_y,
    input  wire [7:0]  red_in,
    input  wire [7:0]  green_in,
    input  wire [7:0]  blue_in,
    input  wire [15:0] distance_mm,
    input  wire signed [15:0] roll_cdeg,
    input  wire signed [15:0] pitch_cdeg,
    input  wire signed [15:0] yaw_cdeg,
    input  wire        drive_unlocked,
    input  wire [1:0]  motion_state,
    input  wire        show_encoder_counts,
    input  wire signed [31:0] left_rpm,
    input  wire signed [31:0] right_rpm,
    output reg  [7:0]  red_out,
    output reg  [7:0]  green_out,
    output reg  [7:0]  blue_out,
    output reg         video_de_out,
    output reg         hsync_out,
    output reg         vsync_out
);
    localparam integer ORIGIN_X = 16;
    localparam integer ORIGIN_Y = 16;
    localparam integer SCALE    = 4;
    localparam integer CHAR_W   = 6 * SCALE;
    localparam integer CHAR_H   = 8 * SCALE;
    localparam integer COLS     = 13;
    localparam integer ROWS     = 7;

    localparam [5:0] CH_SPACE = 6'd0;
    localparam [5:0] CH_0 = 6'd1;
    localparam [5:0] CH_1 = 6'd2;
    localparam [5:0] CH_2 = 6'd3;
    localparam [5:0] CH_3 = 6'd4;
    localparam [5:0] CH_4 = 6'd5;
    localparam [5:0] CH_5 = 6'd6;
    localparam [5:0] CH_6 = 6'd7;
    localparam [5:0] CH_7 = 6'd8;
    localparam [5:0] CH_8 = 6'd9;
    localparam [5:0] CH_9 = 6'd10;
    localparam [5:0] CH_D = 6'd11;
    localparam [5:0] CH_I = 6'd12;
    localparam [5:0] CH_S = 6'd13;
    localparam [5:0] CH_T = 6'd14;
    localparam [5:0] CH_R = 6'd15;
    localparam [5:0] CH_O = 6'd16;
    localparam [5:0] CH_L = 6'd17;
    localparam [5:0] CH_P = 6'd18;
    localparam [5:0] CH_C = 6'd19;
    localparam [5:0] CH_H = 6'd20;
    localparam [5:0] CH_Y = 6'd21;
    localparam [5:0] CH_M = 6'd22;
    localparam [5:0] CH_MINUS = 6'd23;
    localparam [5:0] CH_DOT = 6'd24;
    localparam [5:0] CH_A = 6'd25;
    localparam [5:0] CH_W = 6'd26;
    localparam [5:0] CH_E = 6'd27;
    localparam [5:0] CH_F = 6'd28;
    localparam [5:0] CH_G = 6'd29;
    localparam [5:0] CH_K = 6'd30;
    localparam [5:0] CH_N = 6'd31;
    localparam [5:0] CH_U = 6'd32;

    wire [15:0] roll_abs  = roll_cdeg[15]  ? (~roll_cdeg  + 16'd1) : roll_cdeg;
    wire [15:0] pitch_abs = pitch_cdeg[15] ? (~pitch_cdeg + 16'd1) : pitch_cdeg;
    wire [15:0] yaw_abs   = yaw_cdeg[15]   ? (~yaw_cdeg   + 16'd1) : yaw_cdeg;
    wire [31:0] left_rpm_abs = left_rpm[31] ? -left_rpm : left_rpm;
    wire [31:0] right_rpm_abs = right_rpm[31] ? -right_rpm : right_rpm;

    wire [19:0] distance_bcd_data;
    wire [19:0] roll_bcd_data;
    wire [19:0] pitch_bcd_data;
    wire [19:0] yaw_bcd_data;
    wire [19:0] left_rpm_bcd_data;
    wire [19:0] right_rpm_bcd_data;
    reg [2:0]  angle_sign_data;
    reg        drive_unlocked_data;
    reg [1:0]  motion_state_data;
    reg        show_encoder_counts_data;
    wire bcd_sample, bcd_done;
    wire unused_roll_sample, unused_roll_done;
    wire unused_pitch_sample, unused_pitch_done;
    wire unused_yaw_sample, unused_yaw_done;
    wire unused_left_sample, unused_left_done;
    wire unused_right_sample, unused_right_done;

    bin16_to_bcd5_seq u_bcd_distance (.clk(data_clk), .rst_n(data_rst_n), .value(distance_mm), .bcd(distance_bcd_data), .sample(bcd_sample), .done(bcd_done));
    bin16_to_bcd5_seq u_bcd_roll (.clk(data_clk), .rst_n(data_rst_n), .value(roll_abs), .bcd(roll_bcd_data), .sample(unused_roll_sample), .done(unused_roll_done));
    bin16_to_bcd5_seq u_bcd_pitch (.clk(data_clk), .rst_n(data_rst_n), .value(pitch_abs), .bcd(pitch_bcd_data), .sample(unused_pitch_sample), .done(unused_pitch_done));
    bin16_to_bcd5_seq u_bcd_yaw (.clk(data_clk), .rst_n(data_rst_n), .value(yaw_abs), .bcd(yaw_bcd_data), .sample(unused_yaw_sample), .done(unused_yaw_done));
    bin16_to_bcd5_seq u_bcd_left (.clk(data_clk), .rst_n(data_rst_n), .value(left_rpm_abs[15:0]), .bcd(left_rpm_bcd_data), .sample(unused_left_sample), .done(unused_left_done));
    bin16_to_bcd5_seq u_bcd_right (.clk(data_clk), .rst_n(data_rst_n), .value(right_rpm_abs[15:0]), .bcd(right_rpm_bcd_data), .sample(unused_right_sample), .done(unused_right_done));

    always @(posedge data_clk or negedge data_rst_n) begin
        if (!data_rst_n) begin
            angle_sign_data <= 3'd0;
            drive_unlocked_data <= 1'b0;
            motion_state_data <= 2'd0;
            show_encoder_counts_data <= 1'b0;
        end else if (bcd_sample) begin
            angle_sign_data <= {yaw_cdeg[15], pitch_cdeg[15], roll_cdeg[15]};
            drive_unlocked_data <= drive_unlocked;
            motion_state_data <= motion_state;
            show_encoder_counts_data <= show_encoder_counts;
        end
    end

    // Bundled-data mailbox: hold every field until the destination acknowledges
    // it. Only request/acknowledge toggles traverse two-flop synchronizers.
    // Request is delayed one source cycle after capturing the bundle; the
    // destination waits another cycle after its two-stage synchronizer before
    // sampling. SDC bounds this bus's propagation, not a blanket CDC false path.
    reg [126:0] osd_mailbox;
    reg osd_request, osd_pending, osd_ack;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *) reg osd_ack_meta, osd_ack_sync;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *) reg osd_request_meta, osd_request_sync;
    reg osd_capture_pending;
    reg [19:0] distance_bcd, roll_bcd, pitch_bcd, yaw_bcd;
    reg [19:0] left_rpm_bcd, right_rpm_bcd;
    reg [2:0] angle_sign;
    reg drive_unlocked_sync;
    reg [1:0] motion_state_sync;
    reg show_encoder_counts_sync;

    always @(posedge data_clk or negedge data_rst_n) begin
        if (!data_rst_n) begin
            osd_mailbox <= 127'd0;
            osd_request <= 1'b0;
            osd_pending <= 1'b0;
            osd_ack_meta <= 1'b0;
            osd_ack_sync <= 1'b0;
        end else begin
            osd_ack_meta <= osd_ack;
            osd_ack_sync <= osd_ack_meta;
            if (osd_pending) begin
                osd_request <= ~osd_request;
                osd_pending <= 1'b0;
            end else if (bcd_done && osd_ack_sync == osd_request) begin
                osd_mailbox <= {distance_bcd_data, roll_bcd_data,
                    pitch_bcd_data, yaw_bcd_data, left_rpm_bcd_data,
                    right_rpm_bcd_data, angle_sign_data, drive_unlocked_data,
                    motion_state_data, show_encoder_counts_data};
                osd_pending <= 1'b1;
            end
        end
    end

    always @(posedge pixel_clk or negedge data_rst_n) begin
        if (!data_rst_n) begin
            distance_bcd <= 20'd0; roll_bcd <= 20'd0;
            pitch_bcd <= 20'd0; yaw_bcd <= 20'd0;
            left_rpm_bcd <= 20'd0; right_rpm_bcd <= 20'd0;
            angle_sign <= 3'd0; drive_unlocked_sync <= 1'b0;
            motion_state_sync <= 2'd0; show_encoder_counts_sync <= 1'b0;
            osd_request_meta <= 1'b0; osd_request_sync <= 1'b0;
            osd_capture_pending <= 1'b0; osd_ack <= 1'b0;
        end else begin
            osd_request_meta <= osd_request;
            osd_request_sync <= osd_request_meta;
            if (osd_capture_pending) begin
                {distance_bcd, roll_bcd, pitch_bcd, yaw_bcd,
                    left_rpm_bcd, right_rpm_bcd, angle_sign,
                    drive_unlocked_sync, motion_state_sync,
                    show_encoder_counts_sync} <= osd_mailbox;
                osd_ack <= osd_request_sync;
                osd_capture_pending <= 1'b0;
            end else if (osd_request_sync != osd_ack) begin
                osd_capture_pending <= 1'b1;
            end
        end
    end

    function [5:0] digit_char;
        input [3:0] digit;
        begin
            digit_char = CH_0 + digit;
        end
    endfunction

    function [5:0] char_at;
        input [2:0] row;
        input [3:0] col;
        reg [19:0] bcd;
        reg        neg;
        begin
            char_at = CH_SPACE;
            if (row == 3'd0) begin
                case (col)
                    0: char_at = CH_D;
                    1: char_at = CH_I;
                    2: char_at = CH_S;
                    3: char_at = CH_T;
                    5: char_at = digit_char(distance_bcd[19:16]);
                    6: char_at = digit_char(distance_bcd[15:12]);
                    7: char_at = digit_char(distance_bcd[11:8]);
                    8: char_at = digit_char(distance_bcd[7:4]);
                    9: char_at = digit_char(distance_bcd[3:0]);
                    11: char_at = CH_M;
                    12: char_at = CH_M;
                    default: char_at = CH_SPACE;
                endcase
            end else begin
                case (row)
                    3'd1: begin
                        bcd = roll_bcd;
                        neg = angle_sign[0];
                        case (col)
                            0: char_at = CH_R;
                            1: char_at = CH_O;
                            2: char_at = CH_L;
                            3: char_at = CH_L;
                            5: char_at = neg ? CH_MINUS : CH_SPACE;
                            6: char_at = digit_char(bcd[19:16]);
                            7: char_at = digit_char(bcd[15:12]);
                            8: char_at = digit_char(bcd[11:8]);
                            9: char_at = CH_DOT;
                            10: char_at = digit_char(bcd[7:4]);
                            default: char_at = CH_SPACE;
                        endcase
                    end
                    3'd2: begin
                        bcd = pitch_bcd;
                        neg = angle_sign[1];
                        case (col)
                            0: char_at = CH_P;
                            1: char_at = CH_I;
                            2: char_at = CH_T;
                            3: char_at = CH_C;
                            4: char_at = CH_H;
                            6: char_at = neg ? CH_MINUS : CH_SPACE;
                            7: char_at = digit_char(bcd[19:16]);
                            8: char_at = digit_char(bcd[15:12]);
                            9: char_at = digit_char(bcd[11:8]);
                            10: char_at = CH_DOT;
                            11: char_at = digit_char(bcd[7:4]);
                            default: char_at = CH_SPACE;
                        endcase
                    end
                    3'd3: begin
                        bcd = yaw_bcd;
                        neg = angle_sign[2];
                        case (col)
                            0: char_at = CH_Y;
                            1: char_at = CH_A;
                            2: char_at = CH_W;
                            6: char_at = neg ? CH_MINUS : CH_SPACE;
                            7: char_at = digit_char(bcd[19:16]);
                            8: char_at = digit_char(bcd[15:12]);
                            9: char_at = digit_char(bcd[11:8]);
                            10: char_at = CH_DOT;
                            11: char_at = digit_char(bcd[7:4]);
                            default: char_at = CH_SPACE;
                        endcase
                    end
                    3'd4: begin
                        case (col)
                            0: char_at = CH_M;
                            1: char_at = CH_O;
                            2: char_at = CH_D;
                            3: char_at = CH_E;
                            5: begin
                                if (!drive_unlocked_sync) char_at = CH_L;
                                else if (motion_state_sync == 2'd0) char_at = CH_S;
                                else if (motion_state_sync == 2'd1) char_at = CH_F;
                                else char_at = CH_T;
                            end
                            6: begin
                                if (!drive_unlocked_sync) char_at = CH_O;
                                else if (motion_state_sync == 2'd0) char_at = CH_T;
                                else if (motion_state_sync == 2'd1) char_at = CH_W;
                                else char_at = CH_U;
                            end
                            7: begin
                                if (!drive_unlocked_sync) char_at = CH_C;
                                else if (motion_state_sync == 2'd0) char_at = CH_O;
                                else if (motion_state_sync == 2'd1) char_at = CH_D;
                                else char_at = CH_R;
                            end
                            8: begin
                                if (!drive_unlocked_sync) char_at = CH_K;
                                else if (motion_state_sync == 2'd0) char_at = CH_P;
                                else if (motion_state_sync == 2'd2) char_at = CH_N;
                                else char_at = CH_SPACE;
                            end
                            default: char_at = CH_SPACE;
                        endcase
                    end
                    3'd5: begin
                        case (col)
                            0: char_at = CH_L;
                            1: char_at = CH_E;
                            2: char_at = CH_F;
                            3: char_at = CH_T;
                            5: char_at = show_encoder_counts_sync ? digit_char(left_rpm_bcd[19:16]) : digit_char(left_rpm_bcd[11:8]);
                            6: char_at = show_encoder_counts_sync ? digit_char(left_rpm_bcd[15:12]) : digit_char(left_rpm_bcd[7:4]);
                            7: char_at = show_encoder_counts_sync ? digit_char(left_rpm_bcd[11:8]) : digit_char(left_rpm_bcd[3:0]);
                            8: if (show_encoder_counts_sync) char_at = digit_char(left_rpm_bcd[7:4]);
                            9: char_at = show_encoder_counts_sync ? digit_char(left_rpm_bcd[3:0]) : CH_R;
                            10: if (!show_encoder_counts_sync) char_at = CH_P;
                            11: if (!show_encoder_counts_sync) char_at = CH_M;
                            default: char_at = CH_SPACE;
                        endcase
                    end
                    3'd6: begin
                        case (col)
                            0: char_at = CH_R;
                            1: char_at = CH_I;
                            2: char_at = CH_G;
                            3: char_at = CH_H;
                            4: char_at = CH_T;
                            6: char_at = show_encoder_counts_sync ? digit_char(right_rpm_bcd[19:16]) : digit_char(right_rpm_bcd[11:8]);
                            7: char_at = show_encoder_counts_sync ? digit_char(right_rpm_bcd[15:12]) : digit_char(right_rpm_bcd[7:4]);
                            8: char_at = show_encoder_counts_sync ? digit_char(right_rpm_bcd[11:8]) : digit_char(right_rpm_bcd[3:0]);
                            9: if (show_encoder_counts_sync) char_at = digit_char(right_rpm_bcd[7:4]);
                            10: char_at = show_encoder_counts_sync ? digit_char(right_rpm_bcd[3:0]) : CH_R;
                            11: if (!show_encoder_counts_sync) char_at = CH_P;
                            12: if (!show_encoder_counts_sync) char_at = CH_M;
                            default: char_at = CH_SPACE;
                        endcase
                    end
                    default: char_at = CH_SPACE;
                endcase
            end
        end
    endfunction

    function [4:0] font_bits;
        input [5:0] ch;
        input [2:0] row;
        begin
            font_bits = 5'b00000;
            case (ch)
                CH_0: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10001;2:font_bits=5'b10011;3:font_bits=5'b10101;4:font_bits=5'b11001;5:font_bits=5'b10001;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_1: case(row) 0:font_bits=5'b00100;1:font_bits=5'b01100;2:font_bits=5'b00100;3:font_bits=5'b00100;4:font_bits=5'b00100;5:font_bits=5'b00100;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_2: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10001;2:font_bits=5'b00001;3:font_bits=5'b00010;4:font_bits=5'b00100;5:font_bits=5'b01000;6:font_bits=5'b11111;default:font_bits=0;endcase
                CH_3: case(row) 0:font_bits=5'b11110;1:font_bits=5'b00001;2:font_bits=5'b00001;3:font_bits=5'b01110;4:font_bits=5'b00001;5:font_bits=5'b00001;6:font_bits=5'b11110;default:font_bits=0;endcase
                CH_4: case(row) 0:font_bits=5'b00010;1:font_bits=5'b00110;2:font_bits=5'b01010;3:font_bits=5'b10010;4:font_bits=5'b11111;5:font_bits=5'b00010;6:font_bits=5'b00010;default:font_bits=0;endcase
                CH_5: case(row) 0:font_bits=5'b11111;1:font_bits=5'b10000;2:font_bits=5'b10000;3:font_bits=5'b11110;4:font_bits=5'b00001;5:font_bits=5'b00001;6:font_bits=5'b11110;default:font_bits=0;endcase
                CH_6: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10000;2:font_bits=5'b10000;3:font_bits=5'b11110;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_7: case(row) 0:font_bits=5'b11111;1:font_bits=5'b00001;2:font_bits=5'b00010;3:font_bits=5'b00100;4:font_bits=5'b01000;5:font_bits=5'b01000;6:font_bits=5'b01000;default:font_bits=0;endcase
                CH_8: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b01110;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_9: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b01111;4:font_bits=5'b00001;5:font_bits=5'b00001;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_A: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b11111;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b10001;default:font_bits=0;endcase
                CH_C: case(row) 0:font_bits=5'b01111;1:font_bits=5'b10000;2:font_bits=5'b10000;3:font_bits=5'b10000;4:font_bits=5'b10000;5:font_bits=5'b10000;6:font_bits=5'b01111;default:font_bits=0;endcase
                CH_D: case(row) 0:font_bits=5'b11110;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b10001;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b11110;default:font_bits=0;endcase
                CH_H: case(row) 0:font_bits=5'b10001;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b11111;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b10001;default:font_bits=0;endcase
                CH_I: case(row) 0:font_bits=5'b11111;1:font_bits=5'b00100;2:font_bits=5'b00100;3:font_bits=5'b00100;4:font_bits=5'b00100;5:font_bits=5'b00100;6:font_bits=5'b11111;default:font_bits=0;endcase
                CH_L: case(row) 0:font_bits=5'b10000;1:font_bits=5'b10000;2:font_bits=5'b10000;3:font_bits=5'b10000;4:font_bits=5'b10000;5:font_bits=5'b10000;6:font_bits=5'b11111;default:font_bits=0;endcase
                CH_M: case(row) 0:font_bits=5'b10001;1:font_bits=5'b11011;2:font_bits=5'b10101;3:font_bits=5'b10101;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b10001;default:font_bits=0;endcase
                CH_O: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b10001;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_P: case(row) 0:font_bits=5'b11110;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b11110;4:font_bits=5'b10000;5:font_bits=5'b10000;6:font_bits=5'b10000;default:font_bits=0;endcase
                CH_R: case(row) 0:font_bits=5'b11110;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b11110;4:font_bits=5'b10100;5:font_bits=5'b10010;6:font_bits=5'b10001;default:font_bits=0;endcase
                CH_S: case(row) 0:font_bits=5'b01111;1:font_bits=5'b10000;2:font_bits=5'b10000;3:font_bits=5'b01110;4:font_bits=5'b00001;5:font_bits=5'b00001;6:font_bits=5'b11110;default:font_bits=0;endcase
                CH_T: case(row) 0:font_bits=5'b11111;1:font_bits=5'b00100;2:font_bits=5'b00100;3:font_bits=5'b00100;4:font_bits=5'b00100;5:font_bits=5'b00100;6:font_bits=5'b00100;default:font_bits=0;endcase
                CH_W: case(row) 0:font_bits=5'b10001;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b10101;4:font_bits=5'b10101;5:font_bits=5'b11011;6:font_bits=5'b10001;default:font_bits=0;endcase
                CH_Y: case(row) 0:font_bits=5'b10001;1:font_bits=5'b10001;2:font_bits=5'b01010;3:font_bits=5'b00100;4:font_bits=5'b00100;5:font_bits=5'b00100;6:font_bits=5'b00100;default:font_bits=0;endcase
                CH_E: case(row) 0:font_bits=5'b11111;1:font_bits=5'b10000;2:font_bits=5'b10000;3:font_bits=5'b11110;4:font_bits=5'b10000;5:font_bits=5'b10000;6:font_bits=5'b11111;default:font_bits=0;endcase
                CH_F: case(row) 0:font_bits=5'b11111;1:font_bits=5'b10000;2:font_bits=5'b10000;3:font_bits=5'b11110;4:font_bits=5'b10000;5:font_bits=5'b10000;6:font_bits=5'b10000;default:font_bits=0;endcase
                CH_G: case(row) 0:font_bits=5'b01110;1:font_bits=5'b10001;2:font_bits=5'b10000;3:font_bits=5'b10111;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_K: case(row) 0:font_bits=5'b10001;1:font_bits=5'b10010;2:font_bits=5'b10100;3:font_bits=5'b11000;4:font_bits=5'b10100;5:font_bits=5'b10010;6:font_bits=5'b10001;default:font_bits=0;endcase
                CH_N: case(row) 0:font_bits=5'b10001;1:font_bits=5'b11001;2:font_bits=5'b11001;3:font_bits=5'b10101;4:font_bits=5'b10011;5:font_bits=5'b10011;6:font_bits=5'b10001;default:font_bits=0;endcase
                CH_U: case(row) 0:font_bits=5'b10001;1:font_bits=5'b10001;2:font_bits=5'b10001;3:font_bits=5'b10001;4:font_bits=5'b10001;5:font_bits=5'b10001;6:font_bits=5'b01110;default:font_bits=0;endcase
                CH_MINUS: if (row == 3) font_bits = 5'b11111;
                CH_DOT:   if (row == 6) font_bits = 5'b00100;
                default: font_bits = 5'b00000;
            endcase
        end
    endfunction

    reg [7:0] red_a, green_a, blue_a;
    reg [7:0] red_b, green_b, blue_b;
    reg de_a, hs_a, vs_a, panel_a, text_a;
    reg de_b, hs_b, vs_b, panel_b, text_b;
    reg [2:0] text_row_a, glyph_y_a;
    reg [3:0] text_col_a, glyph_x_a;
    reg [2:0] text_row_b, glyph_y_b;
    reg [3:0] glyph_x_b;
    reg [5:0] selected_char_b;
    reg [4:0] bits_now;
    integer rel_x_now;
    integer rel_y_now;

    function [3:0] text_col_from_rel;
        input integer rel;
        integer value;
        begin
            value = rel / CHAR_W;
            text_col_from_rel = value[3:0];
        end
    endfunction

    function [2:0] text_row_from_rel;
        input integer rel;
        integer value;
        begin
            value = rel / CHAR_H;
            text_row_from_rel = value[2:0];
        end
    endfunction

    function [3:0] glyph_x_from_rel;
        input integer rel;
        integer value;
        begin
            value = (rel % CHAR_W) / SCALE;
            glyph_x_from_rel = value[3:0];
        end
    endfunction

    function [2:0] glyph_y_from_rel;
        input integer rel;
        integer value;
        begin
            value = (rel % CHAR_H) / SCALE;
            glyph_y_from_rel = value[2:0];
        end
    endfunction

    // Stage A: coordinate decoding and source-pixel delay.
    always @(posedge pixel_clk or negedge data_rst_n) begin
        if (!data_rst_n) begin
            red_a <= 0; green_a <= 0; blue_a <= 0;
            de_a <= 0; hs_a <= 0; vs_a <= 0;
            panel_a <= 0; text_a <= 0;
            text_row_a <= 0; text_col_a <= 0;
            glyph_x_a <= 0; glyph_y_a <= 0;
        end else begin
            red_a <= red_in; green_a <= green_in; blue_a <= blue_in;
            de_a <= video_de; hs_a <= hsync_in; vs_a <= vsync_in;
            panel_a <= video_de && pixel_x >= ORIGIN_X &&
                       pixel_x < ORIGIN_X + COLS*CHAR_W + 12 &&
                       pixel_y >= ORIGIN_Y &&
                       pixel_y < ORIGIN_Y + ROWS*CHAR_H + 12;
            text_a <= video_de && pixel_x >= ORIGIN_X + 6 &&
                      pixel_x < ORIGIN_X + 6 + COLS*CHAR_W &&
                      pixel_y >= ORIGIN_Y + 6 &&
                      pixel_y < ORIGIN_Y + 6 + ROWS*CHAR_H;
            rel_x_now = pixel_x - ORIGIN_X - 6;
            rel_y_now = pixel_y - ORIGIN_Y - 6;
            text_col_a <= text_col_from_rel(rel_x_now);
            text_row_a <= text_row_from_rel(rel_y_now);
            glyph_x_a <= glyph_x_from_rel(rel_x_now);
            glyph_y_a <= glyph_y_from_rel(rel_y_now);
        end
    end

    // Stage B: choose the character; this separates the font mux from coordinates.
    always @(posedge pixel_clk or negedge data_rst_n) begin
        if (!data_rst_n) begin
            red_b <= 0; green_b <= 0; blue_b <= 0;
            de_b <= 0; hs_b <= 0; vs_b <= 0;
            panel_b <= 0; text_b <= 0;
            text_row_b <= 0; glyph_x_b <= 0; glyph_y_b <= 0;
            selected_char_b <= CH_SPACE;
        end else begin
            red_b <= red_a; green_b <= green_a; blue_b <= blue_a;
            de_b <= de_a; hs_b <= hs_a; vs_b <= vs_a;
            panel_b <= panel_a; text_b <= text_a;
            text_row_b <= text_row_a;
            glyph_x_b <= glyph_x_a; glyph_y_b <= glyph_y_a;
            selected_char_b <= char_at(text_row_a, text_col_a);
        end
    end

    // Stage C: font lookup and final colour selection.
    always @(posedge pixel_clk or negedge data_rst_n) begin
        if (!data_rst_n) begin
            red_out <= 0; green_out <= 0; blue_out <= 0;
            video_de_out <= 0; hsync_out <= 0; vsync_out <= 0;
            bits_now = 0;
        end else begin
            video_de_out <= de_b;
            hsync_out <= hs_b;
            vsync_out <= vs_b;
            red_out <= panel_b ? 8'h08 : red_b;
            green_out <= panel_b ? 8'h18 : green_b;
            blue_out <= panel_b ? 8'h28 : blue_b;
            bits_now = font_bits(selected_char_b, glyph_y_b);
            if (text_b && glyph_x_b < 5 && glyph_y_b < 7 && bits_now[4-glyph_x_b]) begin
                red_out <= 8'hF8;
                green_out <= (text_row_b == 0) ? 8'hF8 : 8'hE8;
                blue_out <= (text_row_b == 0) ? 8'h40 : 8'hF8;
            end
        end
    end
endmodule
