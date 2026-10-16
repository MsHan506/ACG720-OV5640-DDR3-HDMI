// ==============0ooo===================================================0ooo===========
// =  Copyright (C) 2014-2020 Gowin Semiconductor Technology Co.,Ltd.
// =                     All rights reserved.
// ====================================================================================
// 
//  __      __      __
//  \ \    /  \    / /   [File name   ] video_top.v
//   \ \  / /\ \  / /    [Description ] Video demo
//    \ \/ /  \ \/ /     [Timestamp   ] Friday April 10 14:00:30 2020
//     \  /    \  /      [version     ] 2.0
//      \/      \/
//
// ==============0ooo===================================================0ooo===========
// Code Revision History :
// ----------------------------------------------------------------------------------
// Ver:    |  Author    | Mod. Date    | Changes Made:
// ----------------------------------------------------------------------------------
// V1.0    | Caojie     |  4/10/20     | Initial version 
// ----------------------------------------------------------------------------------
// V2.0    | Caojie     | 10/30/20     | DVI IP update 
// ----------------------------------------------------------------------------------
// ==============0ooo===================================================0ooo===========

// ACG-720/GW5AT-60B board port of Gowin's official DVI TX reference top.
// The reference timing, test-pattern interface, CLKDIV reset relationship,
// and DVI_TX_Top connections are intentionally kept unchanged.  The only
// functional board-port change is TMDS_rPLL -> gw5at_dvi_pll.
module gowin_official_video_top_acg720
(
    input             I_clk           , //50Mhz
    input             I_rst_n         ,
    output     [3:0]  O_led           , 
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,//{r,g,b}
    output     [2:0]  O_tmds_data_n   
);

//==================================================
reg  [31:0] run_cnt;
wire        running;

//--------------------------
wire        tp0_vs_in  ;
wire        tp0_hs_in  ;
wire        tp0_de_in ;
wire [ 7:0] tp0_data_r;
wire [ 7:0] tp0_data_g;
wire [ 7:0] tp0_data_b;

reg         vs_r;
reg  [9:0]  cnt_vs;

//------------------------------------
//ACG-720 HDMI1 TX
wire serial_clk;
wire pll_lock;

wire hdmi4_rst_n;

wire pix_clk;

//===================================================
//LED test
always @(posedge I_clk or negedge I_rst_n) //I_clk
begin
    if(!I_rst_n)
        run_cnt <= 32'd0;
    else if(run_cnt >= 32'd50_000_000)
        run_cnt <= 32'd0;
    else
        run_cnt <= run_cnt + 1'b1;
end

assign  running = (run_cnt < 32'd25_000_000) ? 1'b1 : 1'b0;

assign  O_led[0] = running;
assign  O_led[1] = running;
assign  O_led[2] = ~I_rst_n;
assign  O_led[3] = ~I_rst_n;

//===========================================================================
//testpattern
testpattern testpattern_inst
(
    .I_pxl_clk   (pix_clk            ),//pixel clock
    .I_rst_n     (hdmi4_rst_n        ),//low active 
    .I_mode      ({1'b0,cnt_vs[9:8]} ),//data select
    .I_sqr_width (16'd30             ),
    .I_single_r  (8'd0               ),
    .I_single_g  (8'd255             ),
    .I_single_b  (8'd0               ),                  //800x600    //1024x768   //1280x720    
    .I_h_total   (16'd1650           ),//hor total time  // 16'd1056  // 16'd1344  // 16'd1650  
    .I_h_sync    (16'd40             ),//hor sync time   // 16'd128   // 16'd136   // 16'd40    
    .I_h_bporch  (16'd220            ),//hor back porch  // 16'd88    // 16'd160   // 16'd220   
    .I_h_res     (16'd1280           ),//hor resolution  // 16'd800   // 16'd1024  // 16'd1280  
    .I_v_total   (16'd750            ),//ver total time  // 16'd628   // 16'd806   // 16'd750    
    .I_v_sync    (16'd5              ),//ver sync time   // 16'd4     // 16'd6     // 16'd5     
    .I_v_bporch  (16'd20             ),//ver back porch  // 16'd23    // 16'd29    // 16'd20    
    .I_v_res     (16'd720            ),//ver resolution  // 16'd600   // 16'd768   // 16'd720    
    .I_hs_pol    (1'b1               ),//HS polarity , 0:negetive ploarity，1：positive polarity
    .I_vs_pol    (1'b1               ),//VS polarity , 0:negetive ploarity，1：positive polarity
    .O_de        (tp0_de_in          ),   
    .O_hs        (tp0_hs_in          ),
    .O_vs        (tp0_vs_in          ),
    .O_data_r    (tp0_data_r         ),   
    .O_data_g    (tp0_data_g         ),
    .O_data_b    (tp0_data_b         )
);

always@(posedge pix_clk)
begin
    vs_r<=tp0_vs_in;
end

always@(posedge pix_clk or negedge hdmi4_rst_n)
begin
    if(!hdmi4_rst_n)
        cnt_vs<=10'd0;
    else if(vs_r && !tp0_vs_in) //vs falling edge
        cnt_vs<=cnt_vs+1'b1;
end 

//==============================================================================
//TMDS TX (ACG-720 HDMI1)
gw5at_dvi_pll u_tmds_pll
(.clkin     (I_clk     )     //input clk 
,.clkout    (serial_clk)     //output clk 
,.lock      (pll_lock  )     //output lock
);

assign hdmi4_rst_n = I_rst_n & pll_lock;

CLKDIV u_clkdiv
(.RESETN(hdmi4_rst_n)
,.HCLKIN(serial_clk) //clk  x5
,.CLKOUT(pix_clk)    //clk  x1
,.CALIB (1'b1)
);
defparam u_clkdiv.DIV_MODE="5";
// The GW2A reference also sets GSREN="false".  GW5AT CLKDIV has no GSREN
// parameter, so the board port omits that device-family-specific defparam.

DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi4_rst_n   ),  //asynchronous reset, low active
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),  //pixel clock
    .I_rgb_vs      (tp0_vs_in     ), 
    .I_rgb_hs      (tp0_hs_in     ),    
    .I_rgb_de      (tp0_de_in     ), 
    .I_rgb_r       (tp0_data_r    ),  
    .I_rgb_g       (tp0_data_g    ),  
    .I_rgb_b       (tp0_data_b    ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),  //{r,g,b}
    .O_tmds_data_n (O_tmds_data_n )
);



endmodule
