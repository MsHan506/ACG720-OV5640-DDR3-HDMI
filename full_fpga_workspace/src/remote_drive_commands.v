`timescale 1ns/1ps

// Command bytes used by the common 21-key "Car MP3" NEC remote supplied with
// the kit.  Address is intentionally not fixed because compatible batches use
// either 00/FF or another valid NEC address pair.
module remote_drive_commands (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       command_valid,
    input  wire [7:0] command,
    output reg        start_pulse,
    output reg        stop_pulse,
    output reg [2:0]  drive_mode
);
    localparam [7:0] CMD_CH_MINUS = 8'h45;
    localparam [7:0] CMD_PLAY     = 8'h43;
    localparam [7:0] CMD_1        = 8'h0c;
    localparam [7:0] CMD_2        = 8'h18;
    localparam [7:0] CMD_3        = 8'h5e;
    localparam [7:0] CMD_4        = 8'h08;
    localparam [7:0] CMD_5        = 8'h1c;
    localparam [7:0] CMD_6        = 8'h5a;
    localparam [7:0] CMD_8        = 8'h52;

    localparam [2:0] MODE_AUTO    = 3'd0;
    localparam [2:0] MODE_FORWARD = 3'd1;
    localparam [2:0] MODE_REVERSE = 3'd2;
    localparam [2:0] MODE_LEFT    = 3'd3;
    localparam [2:0] MODE_RIGHT   = 3'd4;
    localparam [2:0] MODE_ROUTE   = 3'd5;
    localparam [2:0] MODE_TARGET  = 3'd6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_pulse <= 1'b0;
            stop_pulse <= 1'b0;
            drive_mode <= MODE_AUTO;
        end else begin
            start_pulse <= command_valid &&
                (command==CMD_PLAY || command==CMD_1 || command==CMD_2 ||
                 command==CMD_3 || command==CMD_4 || command==CMD_6 ||
                 command==CMD_8);
            stop_pulse <= command_valid &&
                (command==CMD_CH_MINUS || command==CMD_5);
            if (command_valid) begin
                case(command)
                    CMD_PLAY: drive_mode <= MODE_AUTO;
                    CMD_2: drive_mode <= MODE_FORWARD;
                    CMD_8: drive_mode <= MODE_REVERSE;
                    CMD_4: drive_mode <= MODE_LEFT;
                    CMD_6: drive_mode <= MODE_RIGHT;
                    CMD_1: drive_mode <= MODE_ROUTE;
                    CMD_3: drive_mode <= MODE_TARGET;
                    default: drive_mode <= drive_mode;
                endcase
            end
        end
    end
endmodule

