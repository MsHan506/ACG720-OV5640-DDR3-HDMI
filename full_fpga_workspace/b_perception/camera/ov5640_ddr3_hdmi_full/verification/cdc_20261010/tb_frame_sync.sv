`timescale 1ns/1ps
// FIFO stubs isolate the frame-sync logic only; NOT a DDR/FIFO integrity test.
module rd_data_fifo(input [127:0] Data, input Reset,WrClk,RdClk,WrEn,RdEn,
    output [9:0] Wnum, output [12:0] Rnum, output Almost_Empty,Almost_Full,
    output [15:0] Q, output Empty,Full);
    assign {Wnum,Rnum,Q}=0;
    assign {Almost_Empty,Almost_Full,Empty,Full}=4'b1010;
endmodule
module wr_data_fifo(input [15:0] Data, input Reset,WrClk,RdClk,WrEn,RdEn,
    output [12:0] Wnum, output [9:0] Rnum, output Almost_Empty,Almost_Full,
    output [127:0] Q, output Empty,Full);
    assign {Wnum,Rnum,Q}=0;
    assign {Almost_Empty,Almost_Full,Empty,Full}=4'b1010;
endmodule
module tb_frame_sync;
    reg ui_clk=0, wr_clk=0, rd_clk=0, rst_n=0;
    always #10 ui_clk=~ui_clk;
    always #5.701 wr_clk=~wr_clk;
    always #6.734 rd_clk=~rd_clk;
    reg wr_load=0, rd_load=0;
    fifo_ddr3_adapter dut (
        .ui_clk(ui_clk),.wr_clk(wr_clk),.rd_clk(rd_clk),.rst_n(rst_n),
        .wr_load(wr_load),.rd_load(rd_load),.init_calib_complete(1'b0),
        .app_rdy(1'b0),.app_wdf_rdy(1'b0),.app_rd_data_valid(1'b0),
        .app_rd_data(128'd0),.app_addr_rd_min(28'd0),.app_addr_rd_max(28'd921600),
        .app_addr_wr_min(28'd0),.app_addr_wr_max(28'd921600),
        .rd_bust_len(8'd160),.wr_bust_len(8'd160),.wfifo_wren(1'b0),
        .wfifo_din(16'd0),.rfifo_rden(1'b0));
    reg expected_wr,expected_rd;
    integer wr_edges=0,rd_edges=0;
    always @(posedge ui_clk) if(rst_n) begin
        expected_wr=dut.wr_load_d1 && !dut.wr_load_d2;
        expected_rd=dut.rd_load_d1 && !dut.rd_load_d2;
        #0.001;
        if(dut.wr_rst!==expected_wr || dut.rd_rst!==expected_rd)
            $fatal(1,"frame edge consumed unsynchronized stage 1");
        if(dut.wr_rst) wr_edges=wr_edges+1;
        if(dut.rd_rst) rd_edges=rd_edges+1;
    end
    initial begin
        #43 rst_n=1;
        repeat(100) begin
            @(negedge wr_clk); wr_load=1;
            @(negedge rd_clk); rd_load=1;
            #200;
            @(negedge wr_clk); wr_load=0;
            @(negedge rd_clk); rd_load=0;
            #200;
        end
        #100;
        if(wr_edges!=100 || rd_edges!=100) $fatal(1,"lost/duplicated frame edges");
        $display("PASS frame sync: 100 write + 100 read edges, stage 2 only");
        $finish;
    end
endmodule
