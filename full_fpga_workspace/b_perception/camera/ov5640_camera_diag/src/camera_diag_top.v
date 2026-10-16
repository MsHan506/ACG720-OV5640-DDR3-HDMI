module camera_diag_top (
    input  wire       clk50M,
    output wire       camera_sclk,
    inout  wire       camera_sdat,
    input  wire       camera_vsync,
    input  wire       camera_href,
    input  wire       camera_pclk,
    output wire       camera_xclk,
    input  wire [7:0] camera_data,
    output wire       camera_rst_n,
    output wire       camera_pwdn,
    output wire [8:0] led
);
    reg [19:0] por_count = 20'd0;
    wire por_n = &por_count;
    always @(posedge clk50M)
        if (!por_n) por_count <= por_count + 1'b1;

    wire camera_init_done;
    wire camera_xclk_fast_unused;

    camera_pll u_camera_pll (
        .clkout0(camera_xclk_fast_unused),
        .clkout1(camera_xclk),
        .clkin  (clk50M)
    );

    camera_init #(
        .SYS_CLOCK       (50_000_000),
        .SCL_CLOCK       (400_000),
        .CAMERA_TYPE     ("ov5640"),
        .IMAGE_TYPE      (0),
        .IMAGE_WIDTH     (640),
        .IMAGE_HEIGHT    (480),
        .IMAGE_FLIP_EN   (0),
        .IMAGE_MIRROR_EN (0)
    ) u_camera_init (
        .Clk          (clk50M),
        .Rst_n        (por_n),
        .Init_Done    (camera_init_done),
        .camera_rst_n (camera_rst_n),
        .camera_pwdn  (camera_pwdn),
        .i2c_sclk     (camera_sclk),
        .i2c_sdat     (camera_sdat)
    );

    reg [23:0] pclk_count = 24'd0;
    reg [3:0]  frame_count = 4'd0;
    reg        href_seen = 1'b0;
    reg        data_seen = 1'b0;
    reg [7:0]  last_data = 8'd0;
    reg        last_vsync = 1'b0;

    always @(posedge camera_pclk) begin
        pclk_count <= pclk_count + 1'b1;
        last_vsync <= camera_vsync;
        if (camera_vsync && !last_vsync)
            frame_count <= frame_count + 1'b1;
        if (camera_href)
            href_seen <= 1'b1;
        if (camera_href && camera_data != last_data)
            data_seen <= 1'b1;
        last_data <= camera_data;
    end

    assign led[0] = camera_init_done;
    assign led[1] = pclk_count[23];
    assign led[2] = frame_count[3];
    assign led[3] = href_seen;
    assign led[4] = data_seen;
    assign led[8:5] = 4'b0000;
endmodule
