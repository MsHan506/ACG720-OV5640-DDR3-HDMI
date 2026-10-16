`timescale 1ns/1ps
// Audit the real HDMI encoder's parallel output. Serializer phase/startup is
// separately exercised with the Gowin primitive models by tb_serializer_audit.
module tb_hdmi_protocol #(parameter bit DVI_MODE=0);
  reg pixel_clk = 0;
  always #6.734 pixel_clk = ~pixel_clk;
  reg gsr_n = 0;
  GSR GSR (.GSRI(gsr_n));
  reg reset = 1;
  wire [10:0] x, fw, sw;
  wire [9:0] y, fh, sh;
  wire [2:0] serial;
  wire serial_clock;
  wire [23:0] rgb = {8'(x), 8'(y), 8'(x ^ y)};
  logic [15:0] audio [1:0] = '{0,0};
  hdmi #(.VIDEO_ID_CODE(4), .VIDEO_REFRESH_RATE(60.0), .IT_CONTENT(0), .DVI_OUTPUT(DVI_MODE)) dut
    (.clk_pixel(pixel_clk), .clk_pixel_x5(1'b0), .clk_audio(pixel_clk),
     .reset(reset), .rgb(rgb), .audio_sample_word(audio),
     .tmds(serial), .tmds_clock(serial_clock), .cx(x), .cy(y),
     .frame_width(fw), .frame_height(fh), .screen_width(sw), .screen_height(sh),
     .debug_hsync(), .debug_vsync(), .debug_de(), .debug_mode());

  integer px1, py1, px2, py2, px3, py3;
  integer valid = 0, failures = 0, cycles = 0;
  reg measuring = 0;
  integer videos = 0, controls = 0, islands = 0, avi_count = 0;
  integer packet_index = 0, sum, ch, bitnum;
  integer frame_avi = 0;
  reg [31:0] header_bits;
  reg [63:0] sub_bits [3:0];
  reg [3:0] nibble [2:0];
  reg [7:0] payload [27:0];
  reg [7:0] residue;
  reg [2:0] expected_mode;
  reg hs, vs;

  function automatic [2:0] mode_at(input integer a, b);
    if (DVI_MODE) mode_at = (a < 1280 && b < 720) ? 1 : 0;
    else if (a >= 1292 && a < 1294 || a >= 1326 && a < 1328) mode_at = 4;
    else if (a >= 1294 && a < 1326) mode_at = 3;
    else if (a >= 1648 && (b == 749 || b < 719)) mode_at = 2;
    else if (a < 1280 && b < 720) mode_at = 1;
    else mode_at = 0;
  endfunction
  function automatic [9:0] control_code(input reg [1:0] c);
    case (c)
      0: control_code = 10'b1101010100;
      1: control_code = 10'b0010101011;
      2: control_code = 10'b0101010100;
      3: control_code = 10'b1010101011;
    endcase
  endfunction
  function automatic [7:0] decode_video(input reg [9:0] w);
    reg [7:0] q;
    integer i;
    q = w[9] ? ~w[7:0] : w[7:0];
    decode_video[0] = q[0];
    for (i=1; i<8; i=i+1)
      decode_video[i] = w[8] ? q[i]^q[i-1] : ~(q[i]^q[i-1]);
  endfunction
  function automatic [3:0] decode_terc(input reg [9:0] w);
    case(w)
      10'b1010011100: decode_terc=0; 10'b1001100011: decode_terc=1;
      10'b1011100100: decode_terc=2; 10'b1011100010: decode_terc=3;
      10'b0101110001: decode_terc=4; 10'b0100011110: decode_terc=5;
      10'b0110001110: decode_terc=6; 10'b0100111100: decode_terc=7;
      10'b1011001100: decode_terc=8; 10'b0100111001: decode_terc=9;
      10'b0110011100: decode_terc=10; 10'b1011000110: decode_terc=11;
      10'b1010001110: decode_terc=12; 10'b1001110001: decode_terc=13;
      10'b0101100011: decode_terc=14; 10'b1011000011: decode_terc=15;
      default: decode_terc=4'bxxxx;
    endcase
  endfunction
  task automatic fail(input string msg);
    if (failures < 12) $display("FAIL x=%0d y=%0d %s",px3,py3,msg);
    failures = failures + 1;
  endtask

  always @(posedge pixel_clk) begin
    px3=px2; py3=py2; px2=px1; py2=py1; px1=x; py1=y;
    if (reset) valid=0; else valid=valid+1;
    #0.001;
    // Ignore the partial startup frame, then audit two complete steady frames.
    if (valid > 4 && px3==0 && py3==0) measuring=1;
    if (valid > 4 && measuring) begin
      cycles=cycles+1;
      if(px1!=((px2==1649)?0:px2+1) || py1!=((px2==1649)?((py2==749)?0:py2+1):py2)) fail("raster counter discontinuity");
      expected_mode=mode_at(px3,py3);
      hs=(px3>=1390 && px3<1430); vs=(py3>=725 && py3<730);
      case(expected_mode)
        0: begin
          controls=controls+1;
          if (dut.tmds_internal[0] !== control_code({vs,hs})) fail("blue control sync/coordinate mismatch");
          if (dut.tmds_internal[1] !== control_code({1'b0, !DVI_MODE && ((px3>=1284 && px3<1292) || (px3>=1640 && px3<1648 && (py3==749 || py3<719)))})) fail("green preamble mismatch");
          if (dut.tmds_internal[2] !== control_code({1'b0,!DVI_MODE && px3>=1284 && px3<1292})) fail("red preamble mismatch");
        end
        1: begin
          videos=videos+1;
          if ({decode_video(dut.tmds_internal[2]),decode_video(dut.tmds_internal[1]),decode_video(dut.tmds_internal[0])} !== {8'(px3),8'(py3),8'(px3^py3)}) fail("RGB/DE pixel mismatch");
        end
        2: begin
          if (dut.tmds_internal[0] !== 10'b1011001100 || dut.tmds_internal[1] !== 10'b0100110011 || dut.tmds_internal[2] !== 10'b1011001100) fail("video guard mismatch");
        end
        3: begin
          islands=islands+1;
          for(ch=0;ch<3;ch=ch+1) nibble[ch]=decode_terc(dut.tmds_internal[ch]);
          if ((^{nibble[0],nibble[1],nibble[2]}) === 1'bx) fail("non-TERC4 code in data island");
          if(nibble[0][1:0] !== {vs,hs}) fail("data-island sync mismatch");
          packet_index=px3-1294;
          header_bits[packet_index]=nibble[0][2];
          for(ch=0;ch<4;ch=ch+1) begin
            sub_bits[ch][2*packet_index]=nibble[1][ch];
            sub_bits[ch][2*packet_index+1]=nibble[2][ch];
          end
          if(packet_index==31) begin
            // Independent syndrome check over the reconstructed wire blocks:
            // all data plus transmitted parity must leave zero BCH remainder.
            residue=0;
            for(bitnum=0;bitnum<32;bitnum=bitnum+1)
              residue=(residue>>1)^((residue[0]^header_bits[bitnum])?8'h83:0);
            if(residue!==0) fail("header BCH syndrome");
            for(ch=0;ch<4;ch=ch+1) begin
              residue=0;
              for(bitnum=0;bitnum<64;bitnum=bitnum+1)
                residue=(residue>>1)^((residue[0]^sub_bits[ch][bitnum])?8'h83:0);
              if(residue!==0) fail("subpacket BCH syndrome");
              for(bitnum=0;bitnum<7;bitnum=bitnum+1) payload[ch*7+bitnum]=sub_bits[ch][bitnum*8+:8];
            end
            if(header_bits[23:0]==24'h0d0282) begin
              avi_count=avi_count+1;
              frame_avi=frame_avi+1;
              sum=8'h82+2+13;
              for(bitnum=0;bitnum<14;bitnum=bitnum+1) sum=sum+payload[bitnum];
              if((sum & 255)!=0) fail("AVI checksum");
              if(payload[0]!==8'h43 || payload[1]!==0 || payload[2]!==8'h28 || payload[3]!==0 || payload[4]!==4 || payload[5]!==0) fail("AVI RGB/16:9/VIC4 fields");
            end else if(header_bits[23:0]!==0) fail("unexpected packet header");
          end
        end
        4: begin
          if(decode_terc(dut.tmds_internal[0]) !== {2'b11,vs,hs} || dut.tmds_internal[1] !== 10'b0100110011 || dut.tmds_internal[2] !== 10'b0100110011) fail("data guard mismatch");
        end
      endcase
      if(px3==1649 && py3==749) begin
        if(frame_avi!=(DVI_MODE?0:1)) fail("AVI count per frame");
        frame_avi=0;
      end
      if(cycles>=1650*750*2) begin
        if(videos!=1280*720*2 || islands!=(DVI_MODE?0:32*750*2) || avi_count!=(DVI_MODE?0:2)) fail("two-frame aggregate count");
        $display("RESULT pixels=%0d video=%0d control=%0d island_pixels=%0d AVI=%0d failures=%0d",cycles,videos,controls,islands,avi_count,failures);
        if(failures) $fatal(1,"HDMI protocol regression failed");
        $finish;
      end
    end
  end
  initial begin
    repeat(4) @(negedge pixel_clk); gsr_n=1;
    repeat(4) @(negedge pixel_clk); reset=0;
    #60000000; $fatal(1,"timeout");
  end
endmodule
