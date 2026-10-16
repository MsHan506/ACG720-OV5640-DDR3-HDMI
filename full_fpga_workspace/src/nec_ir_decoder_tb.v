`timescale 1us/1ns

module nec_ir_decoder_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg ir_rx = 1'b1;
    wire valid;
    wire [7:0] address;
    wire [7:0] command;
    reg valid_seen = 1'b0;
    integer i;
    reg [31:0] payload;

    always #0.5 clk = ~clk; // 1 MHz

    nec_ir_decoder #(.CLK_FREQ(1_000_000)) dut (
        .clk(clk), .rst_n(rst_n), .ir_rx(ir_rx),
        .command_valid(valid), .address(address), .command(command));

    always @(posedge clk)
        if (valid) valid_seen <= 1'b1;

    task send_frame(input [7:0] addr, input [7:0] cmd);
        begin
            payload = {~cmd, cmd, ~addr, addr};
            ir_rx = 1'b0; #9000;
            ir_rx = 1'b1; #4500;
            for (i = 0; i < 32; i = i + 1) begin
                ir_rx = 1'b0; #560;
                ir_rx = 1'b1;
                if (payload[i]) #1690; else #560;
            end
            ir_rx = 1'b0; #560;
            ir_rx = 1'b1; #3000;
        end
    endtask

    initial begin
        #5 rst_n = 1'b1;
        #10 send_frame(8'h00, 8'h43);
        if (!valid_seen || address != 8'h00 || command != 8'h43)
            $fatal(1, "valid NEC frame was not decoded");
        #10;
        $display("PASS NEC infrared frame decode and inverse-byte checks");
        $finish;
    end
endmodule

