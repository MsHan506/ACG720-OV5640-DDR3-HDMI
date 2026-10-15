`timescale 1ns/1ps

// Self-checking timing test.  This file is intentionally not added to the
// synthesis project; it is for an HDL simulator only.
module tb_disp_driver_720p60;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [23:0] data = 24'h123456;
    wire data_req;
    wire [11:0] x, y;
    wire hs, vs, de;
    wire [7:0] r, g, b;
    wire frame_begin;
    wire pclk;

    integer clocks;
    integer lines;
    integer frames;
    integer de_pixels;
    integer de_lines;
    integer hs_pixels;
    integer vs_lines;
    reg hs_seen_line;
    reg de_seen_line;

    always #6.734006734 clk = ~clk; // 74.25 MHz

    disp_driver dut(
        .ClkDisp(clk), .Rst_n(rst_n), .Data(data), .DataReq(data_req),
        .H_Addr(x), .V_Addr(y), .Disp_HS(hs), .Disp_VS(vs),
        .Disp_Red(r), .Disp_Green(g), .Disp_Blue(b),
        .Frame_Begin(frame_begin), .Disp_DE(de), .Disp_PCLK(pclk));

    initial begin
        clocks = 0; lines = 0; frames = 0; de_pixels = 0;
        de_lines = 0; hs_pixels = 0; vs_lines = 0;
        hs_seen_line = 0; de_seen_line = 0;
        #100 rst_n = 1'b1;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            clocks = clocks + 1;
            if (hs) hs_pixels = hs_pixels + 1;
            if (de) begin
                de_pixels = de_pixels + 1;
                de_seen_line = 1'b1;
            end
            if (dut.hcount_r == 12'd1649) begin
                lines = lines + 1;
                if (hs_pixels != 40) begin
                    $display("FAIL: HS width=%0d on line %0d", hs_pixels, lines);
                    $finish;
                end
                if (de_seen_line) de_lines = de_lines + 1;
                if (vs) vs_lines = vs_lines + 1;
                hs_pixels = 0;
                de_seen_line = 1'b0;
                if (dut.vcount_r == 12'd749) begin
                    frames = frames + 1;
                    if (lines != 750 || de_pixels != 1280*720 ||
                        de_lines != 720 || vs_lines != 5) begin
                        $display("FAIL: lines=%0d pixels=%0d de_lines=%0d vs_lines=%0d",
                                 lines, de_pixels, de_lines, vs_lines);
                        $finish;
                    end
                    lines = 0; de_pixels = 0; de_lines = 0; vs_lines = 0;
                    if (frames == 2) begin
                        $display("PASS: two complete 1650x750 frames, active 1280x720, HS=40, VS=5");
                        $finish;
                    end
                end
            end
        end
    end
endmodule
