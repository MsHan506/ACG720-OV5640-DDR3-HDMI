`timescale 1ns/1ps

module tb_ai_uart_command_receiver;
    localparam integer CLK_FREQ = 1_000_000;
    localparam integer BAUD = 100_000;
    localparam integer BIT_NS = 10_000;
    reg clk=0, rst_n=0, rx=1, manual_override=0;
    wire active,start_pulse,stop_pulse,left_dir,right_dir,packet_valid;
    wire signed [31:0] left_target_rpm,right_target_rpm;
    wire [15:0] packet_error_count;
    always #500 clk=~clk;

    ai_uart_command_receiver #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD),
        .WATCHDOG_MS(5)) dut (
        .clk(clk),.rst_n(rst_n),.uart_rx_pin(rx),.manual_override(manual_override),
        .active(active),.start_pulse(start_pulse),.stop_pulse(stop_pulse),
        .left_target_rpm(left_target_rpm),.right_target_rpm(right_target_rpm),
        .left_dir(left_dir),.right_dir(right_dir),.packet_valid(packet_valid),
        .packet_error_count(packet_error_count));

    task send_byte(input [7:0] value);
        integer i;
        begin
            rx=0; #(BIT_NS);
            for(i=0;i<8;i=i+1) begin rx=value[i]; #(BIT_NS); end
            rx=1; #(BIT_NS);
        end
    endtask
    task send_packet(input [7:0] seq,input [7:0] cmd,input [7:0] l,input [7:0] r,input bad);
        reg [7:0] crc;
        begin
            crc=8'hA5^8'h5A^seq^cmd^l^r^8'h00;
            send_byte(8'hA5);send_byte(8'h5A);send_byte(seq);send_byte(cmd);
            send_byte(l);send_byte(r);send_byte(8'h00);send_byte(bad ? crc^8'h01 : crc);
        end
    endtask

    initial begin
        #3000; rst_n=1;
        send_packet(1,8'h01,8'd60,8'hD3,0); // arm: +60, -45
        #2000;
        if(!active || left_target_rpm!=60 || right_target_rpm!=45 || left_dir || !right_dir)
            $fatal(1,"ARM/velocity decode failed");
        send_packet(2,8'h02,8'd100,8'd20,0); // clamp left to 80
        #2000;
        if(left_target_rpm!=80 || right_target_rpm!=20)
            $fatal(1,"clamp failed");
        send_packet(3,8'h02,8'd1,8'd1,1);
        #2000;
        if(packet_error_count!=1 || left_target_rpm!=80)
            $fatal(1,"bad CRC was accepted");
        // No heartbeat: watchdog must stop and disarm.
        #8_000_000;
        if(active || left_target_rpm!=0 || right_target_rpm!=0)
            $fatal(1,"watchdog failed");
        $display("PASS tb_ai_uart_command_receiver");
        $finish;
    end
endmodule
