`timescale 1ns/1ps
module tb_osd_cdc;
    reg data_clk=0, pixel_clk=0, rst_n=0;
    always #10 data_clk=~data_clk;
    always #6.734 pixel_clk=~pixel_clk;
    reg [15:0] distance=0;
    reg signed [15:0] roll=0, pitch=0, yaw=0;
    reg signed [31:0] left_rpm=0, right_rpm=0;
    reg unlocked=0, counts=0;
    reg [1:0] motion=0;
    sensor_osd_overlay dut (
        .data_clk(data_clk), .pixel_clk(pixel_clk), .data_rst_n(rst_n),
        .distance_mm(distance), .roll_cdeg(roll), .pitch_cdeg(pitch),
        .yaw_cdeg(yaw), .left_rpm(left_rpm), .right_rpm(right_rpm),
        .drive_unlocked(unlocked), .motion_state(motion), .show_encoder_counts(counts),
        .video_de(1'b0), .hsync_in(1'b0), .vsync_in(1'b0),
        .pixel_x(12'd0), .pixel_y(12'd0),
        .red_in(8'd0), .green_in(8'd0), .blue_in(8'd0)
    );
    function [19:0] decimal_bcd(input integer n);
        integer i;
        begin
            if(n<0) n=-n;
            decimal_bcd=0;
            for(i=0;i<5;i=i+1) begin
                decimal_bcd[i*4+:4]=n%10; n=n/10;
            end
        end
    endfunction
    reg [126:0] expected_conversion, held_before, display_expected;
    integer sent=0, received=0;
    always @(negedge data_clk) if(rst_n) begin
        distance=$urandom_range(0,65535);
        roll=$urandom_range(0,36000)-18000;
        pitch=$urandom_range(0,36000)-18000;
        yaw=$urandom_range(0,36000)-18000;
        left_rpm=$urandom_range(0,2000)-1000;
        right_rpm=$urandom_range(0,2000)-1000;
        unlocked=$urandom; motion=$urandom; counts=$urandom;
    end
    always @(posedge data_clk) if(rst_n) begin
        if(dut.bcd_sample) expected_conversion={decimal_bcd(distance),
            decimal_bcd(roll),decimal_bcd(pitch),decimal_bcd(yaw),
            decimal_bcd(left_rpm),decimal_bcd(right_rpm),
            yaw[15],pitch[15],roll[15],unlocked,motion,counts};
        if(dut.bcd_done && !dut.osd_pending && dut.osd_ack_sync==dut.osd_request) begin
            // Flags at this edge belong to the previous conversion, while a
            // new conversion starts concurrently. Check the converter outputs
            // and captured flags rather than replacing the previous snapshot.
            held_before={dut.distance_bcd_data,dut.roll_bcd_data,
                dut.pitch_bcd_data,dut.yaw_bcd_data,dut.left_rpm_bcd_data,
                dut.right_rpm_bcd_data,dut.angle_sign_data,
                dut.drive_unlocked_data,dut.motion_state_data,dut.show_encoder_counts_data};
            #0.001;
            if(dut.osd_mailbox !== held_before) $fatal(1,"mailbox source capture corrupted");
            sent=sent+1;
        end else if(dut.osd_request!=dut.osd_ack_sync) begin
            held_before=dut.osd_mailbox;
            #0.001;
            if(dut.osd_mailbox !== held_before) $fatal(1,"mailbox overwritten before ACK");
        end
    end
    // Independently check signs/status against the ORIGINAL sample edge.
    reg [126:0] sample_expected;
    always @(posedge data_clk) if(rst_n) begin
        if(dut.bcd_done) begin
            if({dut.distance_bcd_data,dut.roll_bcd_data,dut.pitch_bcd_data,
                dut.yaw_bcd_data,dut.left_rpm_bcd_data,dut.right_rpm_bcd_data,
                dut.angle_sign_data,dut.drive_unlocked_data,dut.motion_state_data,
                dut.show_encoder_counts_data} !== sample_expected)
                $fatal(1,"BCD magnitude/sign/status do not belong to same sample");
        end
        if(dut.bcd_sample) sample_expected={decimal_bcd(distance),
            decimal_bcd(roll),decimal_bcd(pitch),decimal_bcd(yaw),
            decimal_bcd(left_rpm),decimal_bcd(right_rpm),
            yaw[15],pitch[15],roll[15],unlocked,motion,counts};
    end
    always @(posedge pixel_clk) if(rst_n && dut.osd_capture_pending) begin
        display_expected=dut.osd_mailbox;
        #0.001;
        if({dut.distance_bcd,dut.roll_bcd,dut.pitch_bcd,dut.yaw_bcd,
            dut.left_rpm_bcd,dut.right_rpm_bcd,dut.angle_sign,
            dut.drive_unlocked_sync,dut.motion_state_sync,dut.show_encoder_counts_sync}
            !== display_expected) $fatal(1,"display has torn snapshot");
        received=received+1;
    end
    reg [12:0] target=0;
    wire [12:0] target_out;
    cdc_snapshot_mailbox #(.WIDTH(13)) target_cdc (
        .source_clk(pixel_clk),.destination_clk(data_clk),.rst_n(rst_n),
        .source_data(target),.destination_data(target_out));
    always @(negedge pixel_clk) if(rst_n) begin
        target[11:0]=$urandom; target[12]=^target[11:0];
    end
    always @(negedge data_clk) if(rst_n && target_out[12] !== ^target_out[11:0])
        $fatal(1,"target mailbox incoherent");
    initial begin
        #43 rst_n=1;
        #500000;
        rst_n=0; #37 rst_n=1;
        #500000;
        if(received<2500 || sent<2500) $fatal(1,"insufficient transfers");
        $display("PASS CDC random snapshots sent=%0d received=%0d, two reset phases",sent,received);
        $finish;
    end
endmodule
