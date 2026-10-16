`timescale 1ns/1ps

// NEC infrared decoder for the active-low demodulated output of the ACG720
// onboard receiver.  It emits one pulse for a complete frame and deliberately
// ignores repeat frames so a held key cannot repeatedly re-arm the car.
module nec_ir_decoder #(
    parameter integer CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ir_rx,
    output reg        command_valid,
    output reg [7:0]  address,
    output reg [7:0]  command
);
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LEADER_LOW  = 3'd1;
    localparam [2:0] LEADER_HIGH = 3'd2;
    localparam [2:0] BIT_LOW     = 3'd3;
    localparam [2:0] BIT_HIGH    = 3'd4;

    localparam integer TICKS_PER_US = CLK_FREQ / 1_000_000;
    localparam integer LEADER_LOW_MIN  = 8000 * TICKS_PER_US;
    localparam integer LEADER_LOW_MAX  = 10000 * TICKS_PER_US;
    localparam integer LEADER_HIGH_MIN = 3500 * TICKS_PER_US;
    localparam integer LEADER_HIGH_MAX = 5500 * TICKS_PER_US;
    localparam integer BIT_LOW_MIN     = 350 * TICKS_PER_US;
    localparam integer BIT_LOW_MAX     = 800 * TICKS_PER_US;
    localparam integer ZERO_HIGH_MIN   = 300 * TICKS_PER_US;
    localparam integer ZERO_HIGH_MAX   = 900 * TICKS_PER_US;
    localparam integer ONE_HIGH_MIN    = 1200 * TICKS_PER_US;
    localparam integer ONE_HIGH_MAX    = 2200 * TICKS_PER_US;
    localparam integer TIMEOUT_TICKS   = 12000 * TICKS_PER_US;

    reg [1:0] ir_sync;
    reg       ir_prev;
    reg [2:0] state;
    reg [31:0] ticks;
    reg [5:0] bit_index;
    reg [31:0] frame;
    wire ir_level = ir_sync[1];
    wire falling = ir_prev && !ir_level;
    wire rising  = !ir_prev && ir_level;
    wire final_bit_one = (ticks >= ONE_HIGH_MIN) && (ticks <= ONE_HIGH_MAX);
    wire final_bit_zero = (ticks >= ZERO_HIGH_MIN) && (ticks <= ZERO_HIGH_MAX);
    wire [7:0] final_inverse = {final_bit_one, frame[30:24]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ir_sync <= 2'b11;
            ir_prev <= 1'b1;
            state <= IDLE;
            ticks <= 32'd0;
            bit_index <= 6'd0;
            frame <= 32'd0;
            command_valid <= 1'b0;
            address <= 8'd0;
            command <= 8'd0;
        end else begin
            ir_sync <= {ir_sync[0], ir_rx};
            ir_prev <= ir_level;
            command_valid <= 1'b0;

            if (state != IDLE && ticks < TIMEOUT_TICKS)
                ticks <= ticks + 1'b1;
            else if (state != IDLE) begin
                state <= IDLE;
                ticks <= 32'd0;
            end

            case (state)
                IDLE: if (falling) begin
                    state <= LEADER_LOW;
                    ticks <= 32'd0;
                end

                LEADER_LOW: if (rising) begin
                    if (ticks >= LEADER_LOW_MIN && ticks <= LEADER_LOW_MAX) begin
                        state <= LEADER_HIGH;
                        ticks <= 32'd0;
                    end else begin
                        state <= IDLE;
                    end
                end

                LEADER_HIGH: if (falling) begin
                    if (ticks >= LEADER_HIGH_MIN && ticks <= LEADER_HIGH_MAX) begin
                        state <= BIT_LOW;
                        ticks <= 32'd0;
                        bit_index <= 6'd0;
                        frame <= 32'd0;
                    end else begin
                        // This also rejects the 2.25 ms NEC repeat leader.
                        state <= IDLE;
                    end
                end

                BIT_LOW: if (rising) begin
                    if (ticks >= BIT_LOW_MIN && ticks <= BIT_LOW_MAX) begin
                        state <= BIT_HIGH;
                        ticks <= 32'd0;
                    end else begin
                        state <= IDLE;
                    end
                end

                BIT_HIGH: if (falling) begin
                    if (final_bit_zero || final_bit_one) begin
                        frame[bit_index] <= final_bit_one;
                        ticks <= 32'd0;
                        if (bit_index == 6'd31) begin
                            state <= LEADER_LOW;
                            bit_index <= 6'd0;
                            // Validate both NEC inverse bytes before accepting.
                            if (((frame[7:0] ^ frame[15:8]) == 8'hff) &&
                                ((frame[23:16] ^ final_inverse) == 8'hff)) begin
                                address <= frame[7:0];
                                command <= frame[23:16];
                                command_valid <= 1'b1;
                            end
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            state <= BIT_LOW;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

