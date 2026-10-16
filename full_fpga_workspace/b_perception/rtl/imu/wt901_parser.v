`timescale 1ns / 1ps

module wt901_parser (
    input  wire               clk,
    input  wire               rst_n,
    input  wire [7:0]         rx_data,
    input  wire               rx_valid,
    output reg  signed [15:0] roll_raw,
    output reg  signed [15:0] pitch_raw,
    output reg  signed [15:0] yaw_raw,
    output reg  signed [15:0] roll_cdeg,
    output reg  signed [15:0] pitch_cdeg,
    output reg  signed [15:0] yaw_cdeg,
    output reg                angle_valid,
    output reg                checksum_error
);
    localparam WAIT_HEAD = 2'd0;
    localparam WAIT_TYPE = 2'd1;
    localparam READ_DATA = 2'd2;

    reg [1:0] state;
    reg [3:0] byte_index;
    reg [7:0] frame_type;
    reg [7:0] checksum;
    reg [7:0] p0, p1, p2, p3, p4, p5, p6, p7;

    function signed [15:0] raw_to_cdeg;
        input signed [15:0] raw_angle;
        reg signed [31:0] scaled;
        reg signed [31:0] shifted;
        begin
            scaled = raw_angle * 32'sd18000;
            shifted = scaled >>> 15;
            raw_to_cdeg = shifted[15:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= WAIT_HEAD;
            byte_index     <= 4'd0;
            frame_type     <= 8'h00;
            checksum       <= 8'h00;
            p0 <= 0; p1 <= 0; p2 <= 0; p3 <= 0;
            p4 <= 0; p5 <= 0; p6 <= 0; p7 <= 0;
            roll_raw       <= 16'sd0;
            pitch_raw      <= 16'sd0;
            yaw_raw        <= 16'sd0;
            roll_cdeg      <= 16'sd0;
            pitch_cdeg     <= 16'sd0;
            yaw_cdeg       <= 16'sd0;
            angle_valid    <= 1'b0;
            checksum_error <= 1'b0;
        end else begin
            angle_valid    <= 1'b0;
            checksum_error <= 1'b0;

            if (rx_valid) begin
                case (state)
                    WAIT_HEAD: begin
                        if (rx_data == 8'h55) begin
                            checksum <= 8'h55;
                            state    <= WAIT_TYPE;
                        end
                    end

                    WAIT_TYPE: begin
                        if (rx_data >= 8'h50 && rx_data <= 8'h59) begin
                            frame_type <= rx_data;
                            checksum   <= checksum + rx_data;
                            byte_index <= 4'd2;
                            state      <= READ_DATA;
                        end else begin
                            state <= WAIT_HEAD;
                        end
                    end

                    READ_DATA: begin
                        if (byte_index < 4'd10) begin
                            case (byte_index)
                                4'd2: p0 <= rx_data;
                                4'd3: p1 <= rx_data;
                                4'd4: p2 <= rx_data;
                                4'd5: p3 <= rx_data;
                                4'd6: p4 <= rx_data;
                                4'd7: p5 <= rx_data;
                                4'd8: p6 <= rx_data;
                                4'd9: p7 <= rx_data;
                                default: ;
                            endcase
                            checksum   <= checksum + rx_data;
                            byte_index <= byte_index + 1'b1;
                        end else begin
                            if (rx_data == checksum) begin
                                if (frame_type == 8'h53) begin
                                    roll_raw   <= $signed({p1, p0});
                                    pitch_raw  <= $signed({p3, p2});
                                    yaw_raw    <= $signed({p5, p4});
                                    roll_cdeg  <= raw_to_cdeg($signed({p1, p0}));
                                    pitch_cdeg <= raw_to_cdeg($signed({p3, p2}));
                                    yaw_cdeg   <= raw_to_cdeg($signed({p5, p4}));
                                    angle_valid <= 1'b1;
                                end
                            end else begin
                                checksum_error <= 1'b1;
                            end
                            state      <= WAIT_HEAD;
                            byte_index <= 4'd0;
                            checksum   <= 8'h00;
                        end
                    end
                    default: state <= WAIT_HEAD;
                endcase
            end
        end
    end
endmodule
