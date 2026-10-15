`timescale 1ps/1ps
// Functional audit against Gowin's GW5A simulation primitives.
// These are simulated startup trials, not physical cold-boot measurements.
module tb_serializer_audit;
  reg gsr_n = 0;
  GSR GSR (.GSRI(gsr_n));
  reg fclk = 0;
  reg run_clock = 0;
  wire pclk;
  CLKDIV #(.DIV_MODE("5")) u_div
    (.HCLKIN(fclk), .RESETN(1'b1), .CALIB(1'b1), .CLKOUT(pclk));
  logic [9:0] words [2:0];
  wire [2:0] serial;
  wire forwarded_clock;
  serializer u_ser (.clk_pixel(pclk), .clk_pixel_x5(fclk), .reset(1'b0),
    .tmds_internal(words), .tmds(serial), .tmds_clock(forwarded_clock));

  always #1347 if (run_clock) fclk = ~fclk;
  reg [9:0] seed;
  reg [29:0] history [0:1023];
  integer input_count = 0;
  integer last_match = -1;
  integer checked_words = 0;
  integer trial_checked = 0;
  integer trial = 0;
  integer failures = 0;
  integer bit_index = 0;
  reg collecting = 0;
  reg clock_prev = 0;
  reg [9:0] decoded [2:0];
  time last_pixel = 0;
  time period_seen = 0;
  time last_fast_rise = 0;
  time last_pixel_fall = 0;
  time high_width_seen = 0;
  time low_width_seen = 0;
  integer first_match_latency = -1;

  always @(posedge fclk) last_fast_rise = $time;
  always @(negedge pclk) begin
    if (gsr_n && run_clock && input_count > 12)
      high_width_seen = $time - last_pixel;
    last_pixel_fall = $time;
  end

  always @(posedge pclk) begin
    if (gsr_n && run_clock) begin
      if (input_count > 12) begin
        low_width_seen = $time - last_pixel_fall;
        if ($time != last_fast_rise) begin
          $display("FAIL PCLK rising-edge phase trial=%0d", trial);
          failures = failures + 1;
        end
      end
      if (last_pixel != 0) begin
        period_seen = $time - last_pixel;
        if (period_seen != 13470) begin
          $display("FAIL pixel period trial=%0d period_ps=%0d", trial, period_seen);
          failures = failures + 1;
        end
      end
      last_pixel = $time;
      if (input_count < 1024) begin
        history[input_count] = {words[2], words[1], words[0]};
        input_count = input_count + 1;
      end
      seed = {seed[8:0], seed[9] ^ seed[6]};
      words[0] <= seed;
      words[1] <= {seed[3:0], seed[9:4]} ^ 10'h155;
      words[2] <= (seed * 10'd37) ^ 10'h2aa;
    end
  end

  // Recover word boundaries independently from the forwarded TMDS clock.
  // With D0..D4=0 and D5..D9=1 its falling edge marks serialized bit D0.
  integer k;
  integer found;
  always @(posedge fclk or negedge fclk or negedge gsr_n) begin
    #1;
    if (!gsr_n || !run_clock) begin
      collecting = 0;
      bit_index = 0;
      clock_prev = 0;
    end else begin
      if (forwarded_clock === 1'b0 && clock_prev === 1'b1) begin
        // A short initial serializer pipeline fill is not valid video. The
        // production design holds its raster for far longer (about 14 ms).
        if (input_count > 12 && collecting && bit_index != 10) begin
          $display("FAIL incomplete word trial=%0d bits=%0d", trial, bit_index);
          failures = failures + 1;
        end
        collecting = 1;
        bit_index = 0;
      end
      if (collecting && bit_index < 10) begin
        decoded[0][bit_index] = serial[0];
        decoded[1][bit_index] = serial[1];
        decoded[2][bit_index] = serial[2];
        if (input_count > 12 && forwarded_clock !== (bit_index >= 5)) begin
          $display("FAIL forwarded clock trial=%0d bit=%0d", trial, bit_index);
          failures = failures + 1;
        end
        bit_index = bit_index + 1;
        if (bit_index == 10 && input_count > 12) begin
          found = -1;
          for (k = 0; k < input_count; k = k + 1)
            if ({decoded[2],decoded[1],decoded[0]} === history[k]) found = k;
          if (found < 0 || (last_match >= 0 && found != last_match + 1)) begin
            $display("FAIL word trial=%0d received=%h found=%0d previous=%0d inputs=%0d",
              trial, {decoded[2],decoded[1],decoded[0]}, found, last_match, input_count);
            failures = failures + 1;
          end else begin
            if (last_match < 0) begin
              if (first_match_latency < 0) first_match_latency = input_count - found;
              else if (first_match_latency != input_count - found) begin
                $display("FAIL startup latency changed trial=%0d", trial);
                failures = failures + 1;
              end
            end
            checked_words = checked_words + 1;
            trial_checked = trial_checked + 1;
          end
          last_match = found;
        end
      end
      clock_prev = forwarded_clock;
    end
  end

  initial begin
    for (trial = 0; trial < 25; trial = trial + 1) begin
      run_clock = 0;
      gsr_n = 0;
      #20000;
      fclk = 0;
      input_count = 0;
      last_match = -1;
      last_pixel = 0;
      trial_checked = 0;
      seed = 10'h1;
      words[0] = 10'h1;
      words[1] = 10'h155;
      words[2] = 10'h2aa;
      #(1000 + trial * 137);
      if (trial % 3 == 0) begin
        // Also test GSR release before the PLL's first output clock edge.
        gsr_n = 1;
        #(5000 + trial * 193);
        run_clock = 1;
      end else begin
        run_clock = 1;
        #(5000 + trial * 193);
        gsr_n = 1;
      end
      #4000000;
      $display("TRIAL %0d complete_words=%0d", trial, trial_checked);
      if (trial_checked < 250) failures = failures + 1;
    end
    $display("RESULT trials=25 complete_3lane_words=%0d failures=%0d first_latency=%0d",
      checked_words, failures, first_match_latency);
    $display("MODEL_CLOCK period_ps=%0d high_ps=%0d low_ps=%0d FCLK_period_ps=2694",
      period_seen, high_width_seen, low_width_seen);
    if (failures != 0) $fatal(1, "serializer functional audit failed");
    $finish;
  end
endmodule
