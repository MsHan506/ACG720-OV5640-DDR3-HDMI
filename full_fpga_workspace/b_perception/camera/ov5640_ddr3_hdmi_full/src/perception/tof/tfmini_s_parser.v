`timescale 1ns / 1ps

module tfmini_s_parser (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    output reg  [15:0] distance_cm,
    output wire [15:0] distance_mm,
    output reg  [15:0] strength,
    output reg         frame_valid,
    output reg         measurement_valid,
    output reg         checksum_error
);
    localparam WAIT_HEAD_1 = 2'd0;
    localparam WAIT_HEAD_2 = 2'd1;
    localparam READ_FRAME  = 2'd2;

    reg [1:0] state;
    reg [3:0] byte_index;
    reg [7:0] checksum;
    reg [7:0] dist_l, dist_h;
    reg [7:0] strength_l, strength_h;

    assign distance_mm = (distance_cm << 3) + (distance_cm << 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= WAIT_HEAD_1;
            byte_index        <= 4'd0;
            checksum          <= 8'h00;
            dist_l            <= 8'h00;
            dist_h            <= 8'h00;
            strength_l        <= 8'h00;
            strength_h        <= 8'h00;
            distance_cm       <= 16'd0;
            strength          <= 16'd0;
            frame_valid       <= 1'b0;
            measurement_valid <= 1'b0;
            checksum_error    <= 1'b0;
        end else begin
            frame_valid       <= 1'b0;
            measurement_valid <= 1'b0;
            checksum_error    <= 1'b0;

            if (rx_valid) begin
                case (state)
                    WAIT_HEAD_1: begin
                        if (rx_data == 8'h59) begin
                            checksum <= 8'h59;
                            state    <= WAIT_HEAD_2;
                        end
                    end

                    WAIT_HEAD_2: begin
                        if (rx_data == 8'h59) begin
                            checksum   <= 8'hB2;
                            byte_index <= 4'd2;
                            state      <= READ_FRAME;
                        end else begin
                            state <= WAIT_HEAD_1;
                        end
                    end

                    READ_FRAME: begin
                        case (byte_index)
                            4'd2: begin
                                dist_l     <= rx_data;
                                checksum   <= checksum + rx_data;
                                byte_index <= 4'd3;
                            end
                            4'd3: begin
                                dist_h     <= rx_data;
                                checksum   <= checksum + rx_data;
                                byte_index <= 4'd4;
                            end
                            4'd4: begin
                                strength_l <= rx_data;
                                checksum   <= checksum + rx_data;
                                byte_index <= 4'd5;
                            end
                            4'd5: begin
                                strength_h <= rx_data;
                                checksum   <= checksum + rx_data;
                                byte_index <= 4'd6;
                            end
                            4'd6: begin
                                checksum   <= checksum + rx_data;
                                byte_index <= 4'd7;
                            end
                            4'd7: begin
                                checksum   <= checksum + rx_data;
                                byte_index <= 4'd8;
                            end
                            4'd8: begin
                                if (rx_data == checksum) begin
                                    distance_cm <= {dist_h, dist_l};
                                    strength    <= {strength_h, strength_l};
                                    frame_valid <= 1'b1;
                                    if ({dist_h, dist_l} != 16'hFFFF &&
                                        {dist_h, dist_l} != 16'hFFFE &&
                                        {dist_h, dist_l} != 16'hFFFC &&
                                        {strength_h, strength_l} >= 16'd100)
                                        measurement_valid <= 1'b1;
                                end else begin
                                    checksum_error <= 1'b1;
                                end
                                state      <= WAIT_HEAD_1;
                                byte_index <= 4'd0;
                                checksum   <= 8'h00;
                            end
                            default: begin
                                state <= WAIT_HEAD_1;
                                byte_index <= 4'd0;
                            end
                        endcase
                    end
                    default: state <= WAIT_HEAD_1;
                endcase
            end
        end
    end
endmodule

