module gao_ov5640_ddr_hdmi #(
    parameter IMAGE_WIDTH  = 1280,
    parameter IMAGE_HEIGHT = 720,
    parameter HDMI_TRUE_MODE = 1'b0,
    parameter HDMI_TEST_PATTERN = 1'b0
) (
    //System clock reset
    input       clk50M        , //系统时钟输入，50MHz
    input       reset_n       , //复位信号输入

    //camera interface
    output      camera_sclk   ,
    inout       camera_sdat   ,
    input       camera_vsync  ,
    input       camera_href   ,
    input       camera_pclk   ,
    output      camera_xclk   ,
    input  [7:0]camera_data   ,
    output      camera_rst_n  ,
    output      camera_pwdn   ,
    //led
    output [3:0]led           ,

    // live sensor values for the on-screen display
    input [15:0] distance_mm,
    input signed [15:0] roll_cdeg,
    input signed [15:0] pitch_cdeg,
    input signed [15:0] yaw_cdeg,
    input drive_unlocked,
    input [1:0] motion_state,
    input show_encoder_counts,
    input signed [31:0] left_rpm,
    input signed [31:0] right_rpm,
    output target_valid,
    output target_control_valid,
    output [11:0] target_control_x,
    output [11:0] target_center_x,
    output [11:0] target_center_y,
    output [23:0] target_pixel_count,

    //hdmi output
	output       	tmds_clk_p ,
	output       	tmds_clk_n ,
	output 	[2:0]   tmds_data_p,    //rgb
	output 	[2:0]   tmds_data_n,     //rgb

    //ddr
    output [13:0] O_ddr_addr        ,
    output [2:0] O_ddr_ba           ,
    output O_ddr_cs_n               ,
    output O_ddr_ras_n              ,
    output O_ddr_cas_n              ,
    output O_ddr_we_n               ,
    output O_ddr_clk                ,
    output O_ddr_clk_n              ,
    output O_ddr_cke                ,
    output O_ddr_odt                ,
    output O_ddr_reset_n            ,
    output [1:0] O_ddr_dqm          ,
    inout [15:0] IO_ddr_dq          ,
    inout [1:0] IO_ddr_dqs          ,
    inout [1:0] IO_ddr_dqs_n        

);
    wire          loc_clk24m;
    wire          g_rst_p;
    wire          clk_200M;
    wire          pll_lock;
    wire          hdmi_pll_lock;
    wire          loc_clk50m;
    wire          hdmi_stream_reset_n;
    wire          true_hdmi_reset;
    (* syn_keep = 1 *) reg hdmi_lock_meta = 1'b0;
    (* syn_keep = 1 *) reg hdmi_lock_sync = 1'b0;
    (* syn_keep = 1 *) reg [19:0] hdmi_lock_delay = 20'd0;
    (* syn_keep = 1 *) reg hdmi_ready = 1'b0;
    (* syn_keep = 1 *) reg hdmi_lock_drop_seen = 1'b0;
    reg [4:0] true_hdmi_start_delay = 5'b00000;
    //camera
    wire          camera_init_done;
    wire          pclk_bufg_o;

    //ddr
	wire fifo_aclr;
	wire fifo_wrreq;
	wire [15:0] fifo_wrdata;
    wire wr_load;
    wire wrfifo_wren;
    wire init_calib_complete;
    wire ddr_pll_stop;
    wire [7:0] ddr_mdrp_rdata;
    wire [7:0] ddr_mdrp_wdata;
    wire [1:0] ddr_mdrp_op;
    wire ddr_mdrp_inc;
    reg ddr_mdrp_wr;
    reg ddr_pll_stop_d;
    (* syn_preserve = 1, ASYNC_REG = "TRUE" *) reg [1:0] ddr_pll_lock_sync;
    wire wrfifo_full_unused;
    wire rdfifo_empty_unused;
    
    //hdmi
    wire clk_vga;//74.25m
	wire clk_vgax5;//371.25m

	wire [11:0] hcount;
	wire [11:0] vcount;
	wire [23:0] disp_data;
 
	wire video_hs;
	wire video_vs;
	wire video_de;
	wire [7:0] video_r;
	wire [7:0] video_g;
	wire [7:0] video_b;
    wire [7:0] osd_video_r;
    wire [7:0] osd_video_g;
    wire [7:0] osd_video_b;
    wire osd_video_de;
    wire osd_video_hs;
    wire osd_video_vs;
    wire [7:0] boxed_video_r;
    wire [7:0] boxed_video_g;
    wire [7:0] boxed_video_b;
    wire boxed_video_de;
    wire boxed_video_hs;
    wire boxed_video_vs;
    wire [11:0] target_bbox_left;
    wire [11:0] target_bbox_right;
    wire [11:0] target_bbox_top;
    wire [11:0] target_bbox_bottom;
    wire target_frame_toggle;


    assign  g_rst_p = ~pll_lock;

    assign led = {~g_rst_p,camera_init_done,init_calib_complete,pll_lock};
    
    
    camera_pll camera_pll(
        .clkout0(clk_vgax5), //output clkout0
        .clkout1(loc_clk24m), //output clkout1
        .lock(hdmi_pll_lock),
        // Keep the HDMI PLL independent of the DDR/system PLL.  This avoids
        // cascading PLL jitter and prevents a system-PLL relock from
        // interrupting the TMDS clock.
        .clkin(clk50M) //input clkin
    );

    Gowin_PLL Gowin_PLL(
        .lock(pll_lock), //output lock
        .clkout0(), // CLKOUT0 is not the GW5A DDR memory-clock output
        .clkout1(loc_clk50m), //output clkout1
        .clkout2(clk_200M), // IPUG281: GW5A memory_clk must use CLKOUT2
        .mdrdo(ddr_mdrp_rdata),
        .clkin(clk50M), //input clkin
        .reset(~reset_n), //input reset
        .mdclk(clk50M),
        .mdopc(ddr_mdrp_op),
        .mdainc(ddr_mdrp_inc),
        .mdwdi(ddr_mdrp_wdata)
    );

    // PLLA on GW5AT-60B has no ENCLK2 input.  Use Gowin's encrypted reference
    // adapter to apply DDR IP pll_stop requests through the PLL mDRP port.
    always @(posedge clk50M or negedge reset_n) begin
        if (!reset_n) begin
            ddr_pll_lock_sync <= 2'b00;
            ddr_pll_stop_d <= 1'b1;
            ddr_mdrp_wr <= 1'b0;
        end else begin
            ddr_pll_lock_sync <= {ddr_pll_lock_sync[0], pll_lock};
            ddr_pll_stop_d <= ddr_pll_stop;
            ddr_mdrp_wr <= ddr_pll_lock_sync[1] &&
                           (ddr_pll_stop_d != ddr_pll_stop);
        end
    end

    pll_mDRP_intf u_ddr_pll_mdrp (
        .clk(clk50M),
        .rst_n(reset_n),
        .pll_lock(ddr_pll_lock_sync[1]),
        .wr(ddr_mdrp_wr),
        .mdrp_inc(ddr_mdrp_inc),
        .mdrp_op(ddr_mdrp_op),
        .mdrp_wdata(ddr_mdrp_wdata),
        .mdrp_rdata(ddr_mdrp_rdata)
    );


    CLKDIV u_clkdiv
    // CLKDIV and OSER10 must start from the same configuration-time GSR.
    // Holding only CLKDIV reset until PLL LOCK randomizes the 10-bit TMDS
    // word phase relative to the serializers on every power-up.
    (.RESETN(1'b1)
    ,.HCLKIN(clk_vgax5) //clk  x5
    ,.CLKOUT(clk_vga)    //clk  x1
    ,.CALIB (1'b1)
    );
    defparam u_clkdiv.DIV_MODE="5";

    // The packet-capable HDMI core and the legacy camera/DDR raster generator
    // must leave reset on the same pixel-clock edge.  Previously disp_driver
    // started immediately while the HDMI core waited 1024 pixel clocks.  The
    // resulting fixed phase error wrapped the camera image through blanking,
    // producing the large black band seen on the directly connected monitor.
    assign hdmi_stream_reset_n = reset_n && hdmi_ready;

    // Match the isolated TX: qualify synchronized PLL LOCK for about 14 ms.
    // Once started, never reset the raster from camera/DDR readiness or a raw
    // asynchronous LOCK glitch. Log a synchronized unlock for Analyzer instead.
    // A real loss of clock lock is a hardware fault, not a valid video stream;
    // use external reset_n to explicitly restart after investigating it.
    always @(posedge clk_vga or negedge reset_n) begin
        if (!reset_n) begin
            hdmi_lock_meta <= 1'b0;
            hdmi_lock_sync <= 1'b0;
            hdmi_lock_delay <= 20'd0;
            hdmi_ready <= 1'b0;
            hdmi_lock_drop_seen <= 1'b0;
        end else begin
            hdmi_lock_meta <= hdmi_pll_lock;
            hdmi_lock_sync <= hdmi_lock_meta;
            if (!hdmi_ready) begin
                if (!hdmi_lock_sync)
                    hdmi_lock_delay <= 20'd0;
                else begin
                    hdmi_lock_delay <= hdmi_lock_delay + 1'b1;
                    if (&hdmi_lock_delay)
                        hdmi_ready <= 1'b1;
                end
            end else if (!hdmi_lock_sync)
                hdmi_lock_drop_seen <= 1'b1;
        end
    end

    // The live-video path has five registered stages from disp_driver's
    // raster decision to the target-box output: one in disp_driver, three in
    // sensor_osd_overlay and one in target_box_overlay.  Start the true-HDMI
    // raster five pixel clocks later so its internally generated DE/packet
    // schedule describes the pixel currently arriving at rgb_in.  Without
    // this offset, every active line loses its final pixels and begins with
    // pixels left over from the preceding blanking interval.
    always @(posedge clk_vga or negedge hdmi_stream_reset_n) begin
        if (!hdmi_stream_reset_n)
            true_hdmi_start_delay <= 5'b00000;
        else
            true_hdmi_start_delay <= {true_hdmi_start_delay[3:0], 1'b1};
    end
    assign true_hdmi_reset = !true_hdmi_start_delay[4];


    assign camera_xclk = loc_clk24m;
    //摄像头
    camera_init
    #(
        .SYS_CLOCK      ( 50_000_000   ),//系统时钟采用50MHz
        .SCL_CLOCK      ( 400_000      ),//SCL总线时钟采用400kHz
        .CAMERA_TYPE    ( "ov5640"     ),//"ov5640" or "ov7725"
        .IMAGE_TYPE     ( 0            ),// 0: RGB; 1: JPEG
        .IMAGE_WIDTH    ( IMAGE_WIDTH  ),// 图片宽度
        .IMAGE_HEIGHT   ( IMAGE_HEIGHT ),// 图片高度
        .IMAGE_FLIP_EN  ( 0            ),// 0: 不翻转，1: 上下翻转
        .IMAGE_MIRROR_EN( 0            ) // 0: 不镜像，1: 左右镜像
    )camera_init
    (
        .Clk         (loc_clk50m       ),
        .Rst_n       (reset_n         ),
        .Init_Done   (camera_init_done ),
        .camera_rst_n(camera_rst_n     ),
        .camera_pwdn (camera_pwdn      ),
        .i2c_sclk    (camera_sclk      ),
        .i2c_sdat    (camera_sdat      )
    );
    
    assign pclk_bufg_o = camera_pclk;

    DVP_Capture DVP_Capture(
        .Rst_n      (reset_n         ),//input
        .PCLK       (pclk_bufg_o      ),//input
        .Vsync      (camera_vsync     ),//input
        .Href       (camera_href      ),//input
        .Data       (camera_data      ),//input     [7:0]

        .ImageState (fifo_aclr        ),//output reg
        .DataValid  (fifo_wrreq       ),//output
        .DataPixel  (fifo_wrdata      ),//output    [15:0]
        .DataHs     (                 ),//output
        .DataVs     (wr_load          ),//output
        .Xaddr      (                 ),//output    [11:0],start is 1
        .Yaddr      (                 )   //output    [11:0],start is 1
    );
    

    wire rdfifo_rden;
    wire wrfifo_clr;
    wire [15:0] wrfifo_din;
    wire wrfifo_clk;
    wire rdfifo_clr;
    wire rdfifo_clk;
    wire [15:0] rdfifo_dout;
    
    
    assign wrfifo_clr = fifo_aclr;
    assign wrfifo_clk = pclk_bufg_o;
    assign rdfifo_clr = 0;
    assign rdfifo_clk = clk_vga;
    assign wrfifo_wren = fifo_wrreq;
    assign wrfifo_din = fifo_wrdata;
    assign disp_data = {rdfifo_dout[15:11],3'd0,rdfifo_dout[10:5],2'd0,rdfifo_dout[4:0],3'd0}; 

    wire [27:0] app_addr_max = IMAGE_WIDTH * IMAGE_HEIGHT;
    wire [7:0] burst_len = IMAGE_WIDTH[10:3];

    ddr3_ctrl_2port ddr3_ctrl_2port(
        .clk(clk50M)                     ,      // Continuous board reference, independent of DDR PLL
        .pll_lock(pll_lock)            ,
        .clk_200m(clk_200M)            ,      //DDR3参考时钟信号
        .sys_rst_n(reset_n)           ,      //外部复位信号
        .init_calib_complete(init_calib_complete) ,    //DDR初始化完成信号
        .pll_stop(ddr_pll_stop)          ,

        //用户接口
        .rd_load(video_vs)             ,   //输出源更新信号
        .wr_load(wr_load)             ,   //输入源更新信号
        .app_addr_rd_min(28'd0)     ,   //读DDR3的起始地址
        .app_addr_rd_max(app_addr_max)     ,   //读DDR3的结束地址
        .rd_bust_len(burst_len)         ,   //从DDR3中读数据时的突发长度
        .app_addr_wr_min(28'd0)     ,   //写DD3的起始地址
        .app_addr_wr_max(app_addr_max)     ,   //写DDR的结束地址
        .wr_bust_len(burst_len)         ,   //向DDR3中写数据时的突发长度

        .wr_clk(wrfifo_clk)             ,//wr_fifo的写时钟信号
        .wfifo_wren(wrfifo_wren)          , //wr_fifo的写使能信号
        .wfifo_din(wrfifo_din)           , //写入到wr_fifo中的数据
        .wrfifo_full(wrfifo_full_unused)  ,
        .rd_clk(rdfifo_clk)              , //rd_fifo的读时钟信号
        .rfifo_rden(rdfifo_rden)          , //rd_fifo的读使能信号
        .rdfifo_empty(rdfifo_empty_unused),
        .rfifo_dout(rdfifo_dout)          , //rd_fifo读出的数据信号 

        //DDR3   
        .ddr3_dq(IO_ddr_dq)             ,   //DDR3 数据
        .ddr3_dqs_n(IO_ddr_dqs_n)          ,   //DDR3 dqs负
        .ddr3_dqs_p(IO_ddr_dqs)          ,   //DDR3 dqs正  
        .ddr3_addr(O_ddr_addr)           ,   //DDR3 地址   
        .ddr3_ba(O_ddr_ba)             ,   //DDR3 banck 选择
        .ddr3_ras_n(O_ddr_ras_n)          ,   //DDR3 行选择
        .ddr3_cas_n(O_ddr_cas_n)          ,   //DDR3 列选择
        .ddr3_we_n(O_ddr_we_n)           ,   //DDR3 读写选择
        .ddr3_reset_n(O_ddr_reset_n)        ,   //DDR3 复位
        .ddr3_ck_p(O_ddr_clk)          ,   //DDR3 时钟正
        .ddr3_ck_n(O_ddr_clk_n)           ,   //DDR3 时钟负
        .ddr3_cke(O_ddr_cke)            ,   //DDR3 时钟使能
        .ddr3_cs_n(O_ddr_cs_n)           ,   //DDR3 片选
        .ddr3_dm(O_ddr_dqm)             ,   //DDR3_dm
        .ddr3_odt(O_ddr_odt)                //DDR3_odt   
    );
   

    //HDMI显示
    disp_driver disp_driver(
		.ClkDisp(clk_vga),
		.Rst_n(hdmi_stream_reset_n),
		.Data(disp_data),
		.DataReq(rdfifo_rden),
		.H_Addr(hcount),
		.V_Addr(vcount),
		.Disp_HS(video_hs),
		.Disp_VS(video_vs),
		.Disp_Red(video_r),
		.Disp_Green(video_g),
		.Disp_Blue(video_b),
        .Frame_Begin(),
		.Disp_DE(video_de),
		.Disp_PCLK()
	);

    red_target_detector #(.MIN_PIXELS(600)) u_red_target_detector (
        .pixel_clk(clk_vga), .rst_n(reset_n),
        .frame_sync(video_vs), .pixel_valid(video_de),
        .pixel_x(hcount), .pixel_y(vcount),
        .red(video_r), .green(video_g), .blue(video_b),
        .target_valid(target_valid),
        .target_center_x(target_center_x),
        .target_center_y(target_center_y),
        .bbox_left(target_bbox_left), .bbox_right(target_bbox_right),
        .bbox_top(target_bbox_top), .bbox_bottom(target_bbox_bottom),
        .target_pixel_count(target_pixel_count),
        .frame_toggle(target_frame_toggle));

    cdc_snapshot_mailbox #(.WIDTH(13)) u_target_cdc (
        .source_clk(clk_vga), .destination_clk(clk50M), .rst_n(reset_n),
        .source_data({target_valid, target_center_x}),
        .destination_data({target_control_valid, target_control_x})
    );

    sensor_osd_overlay u_sensor_osd (
        // Sensor values are produced in the board clk50M domain.  Keeping the
        // BCD converters on that exact clock avoids a false same-frequency CDC
        // through the PLL-derived loc_clk50m signal.
        .data_clk(clk50M),
        .data_rst_n(reset_n),
        .pixel_clk(clk_vga),
        .video_de(video_de),
        .hsync_in(video_hs),
        .vsync_in(video_vs),
        .pixel_x(hcount),
        .pixel_y(vcount),
        .red_in(video_r),
        .green_in(video_g),
        .blue_in(video_b),
        .distance_mm(distance_mm),
        .roll_cdeg(roll_cdeg),
        .pitch_cdeg(pitch_cdeg),
        .yaw_cdeg(yaw_cdeg),
        .drive_unlocked(drive_unlocked),
        .motion_state(motion_state),
        .show_encoder_counts(show_encoder_counts),
        .left_rpm(left_rpm),
        .right_rpm(right_rpm),
        .red_out(osd_video_r),
        .green_out(osd_video_g),
        .blue_out(osd_video_b),
        .video_de_out(osd_video_de),
        .hsync_out(osd_video_hs),
        .vsync_out(osd_video_vs)
    );

    target_box_overlay u_target_box_overlay (
        .pixel_clk(clk_vga), .rst_n(reset_n),
        .target_valid(target_valid),
        .bbox_left(target_bbox_left), .bbox_right(target_bbox_right),
        .bbox_top(target_bbox_top), .bbox_bottom(target_bbox_bottom),
        .pixel_x(hcount), .pixel_y(vcount),
        .video_de(osd_video_de), .hsync_in(osd_video_hs),
        .vsync_in(osd_video_vs), .red_in(osd_video_r),
        .green_in(osd_video_g), .blue_in(osd_video_b),
        .video_de_out(boxed_video_de), .hsync_out(boxed_video_hs),
        .vsync_out(boxed_video_vs), .red_out(boxed_video_r),
        .green_out(boxed_video_g), .blue_out(boxed_video_b));
//	
	// Standards-compliant 720p60 colour bars.  This path bypasses the camera,
	// DDR frame data and overlays while preserving the same HS/VS/DE generator.
	reg [23:0] test_pattern_rgb;
	always @* begin
		if (!video_de)
			test_pattern_rgb = 24'h000000;
		else if (hcount < 12'd160)
			test_pattern_rgb = 24'hFFFFFF;
		else if (hcount < 12'd320)
			test_pattern_rgb = 24'hFFFF00;
		else if (hcount < 12'd480)
			test_pattern_rgb = 24'h00FFFF;
		else if (hcount < 12'd640)
			test_pattern_rgb = 24'h00FF00;
		else if (hcount < 12'd800)
			test_pattern_rgb = 24'hFF00FF;
		else if (hcount < 12'd960)
			test_pattern_rgb = 24'hFF0000;
		else if (hcount < 12'd1120)
			test_pattern_rgb = 24'h0000FF;
		else
			test_pattern_rgb = 24'h000000;
	end

	wire [7:0] dvi_red   = HDMI_TEST_PATTERN ? test_pattern_rgb[23:16] : boxed_video_r;
	wire [7:0] dvi_green = HDMI_TEST_PATTERN ? test_pattern_rgb[15:8]  : boxed_video_g;
	wire [7:0] dvi_blue  = HDMI_TEST_PATTERN ? test_pattern_rgb[7:0]   : boxed_video_b;
	wire dvi_de = HDMI_TEST_PATTERN ? video_de : boxed_video_de;
	wire dvi_hs = HDMI_TEST_PATTERN ? video_hs : boxed_video_hs;
	wire dvi_vs = HDMI_TEST_PATTERN ? video_vs : boxed_video_vs;

	generate
		if (HDMI_TRUE_MODE) begin : g_true_hdmi_output
			// True HDMI (not DVI): CEA-861 VIC 4 video plus an AVI InfoFrame
			// in a BCH-protected data island.  The test-pattern selector is
			// retained so the camera/DDR path can be isolated without editing
			// the transmitter again.
			true_hdmi_720p60_tx u_true_hdmi (
				.pixel_clk(clk_vga),
				.serial_clk_x5(clk_vgax5),
				.reset(true_hdmi_reset),
				.use_test_pattern(HDMI_TEST_PATTERN),
				.rgb_in({boxed_video_r, boxed_video_g, boxed_video_b}),
				.tmds_clk_p(tmds_clk_p),
				.tmds_clk_n(tmds_clk_n),
				.tmds_data_p(tmds_data_p),
				.tmds_data_n(tmds_data_n)
			);
		end else begin : g_camera_dvi_legacy
			// Preserved legacy camera/DVI path for immediate rollback.
			DVI_TX_Top DVI_TX_Top(
				.I_rst_n(hdmi_stream_reset_n),
				.I_serial_clk(clk_vgax5),
				.I_rgb_clk(clk_vga),
				.I_rgb_vs(dvi_vs),
				.I_rgb_hs(dvi_hs),
				.I_rgb_de(dvi_de),
				.I_rgb_r(dvi_red),
				.I_rgb_g(dvi_green),
				.I_rgb_b(dvi_blue),
				.O_tmds_clk_p(tmds_clk_p),
				.O_tmds_clk_n(tmds_clk_n),
				.O_tmds_data_p(tmds_data_p),
				.O_tmds_data_n(tmds_data_n)
			);
		end
	endgenerate


endmodule
