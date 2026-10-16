`timescale 1ns/1ps

module safe_start_stop_latch_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start_n = 1'b1;
    reg stop_n = 1'b1;
    reg remote_start = 1'b0;
    reg remote_stop = 1'b0;
    reg allowed = 1'b0;
    wire enabled;
    always #500 clk = ~clk;

    safe_start_stop_latch #(.CLK_FREQ(1000), .DEBOUNCE_MS(3)) dut (
        .clk(clk), .rst_n(rst_n), .start_button_n(start_n),
        .stop_button_n(stop_n), .remote_start_pulse(remote_start),
        .remote_stop_pulse(remote_stop), .start_allowed(allowed),
        .enabled(enabled));

    initial begin
        repeat (3) @(posedge clk); rst_n = 1'b1;
        repeat (3) @(posedge clk);
        if (enabled) $fatal(1, "must default stopped");

        start_n = 1'b0;
        repeat (8) @(posedge clk);
        if (enabled) $fatal(1, "blocked start must not enable");
        allowed = 1'b1;
        repeat (5) @(posedge clk);
        if (enabled) $fatal(1, "held rejected press must not late-start");

        start_n = 1'b1; repeat (4) @(posedge clk);
        start_n = 1'b0; repeat (8) @(posedge clk);
        if (!enabled) $fatal(1, "valid debounced press must enable");

        stop_n = 1'b0; repeat (3) @(posedge clk);
        if (enabled) $fatal(1, "stop must clear enable");
        stop_n = 1'b1; start_n = 1'b1; repeat (4) @(posedge clk);
        if (enabled) $fatal(1, "stop must remain latched until new start");

        remote_start = 1'b1; @(posedge clk); remote_start = 1'b0;
        repeat (2) @(posedge clk);
        if (!enabled) $fatal(1, "valid remote start must enable");

        remote_stop = 1'b1; @(posedge clk); remote_stop = 1'b0;
        repeat (2) @(posedge clk);
        if (enabled) $fatal(1, "remote stop must clear enable");

        allowed = 1'b0;
        remote_start = 1'b1; @(posedge clk); remote_start = 1'b0;
        repeat (2) @(posedge clk);
        if (enabled) $fatal(1, "blocked remote start must not enable");

        $display("PASS safe start, rejected-start consumption, and stop latch");
        $finish;
    end
endmodule
