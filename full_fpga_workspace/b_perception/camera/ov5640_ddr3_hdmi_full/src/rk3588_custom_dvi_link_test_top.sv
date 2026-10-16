// Wrapper selecting DVI mode in the open RTL TMDS encoder/serializer.
// Unlike rk3588_gowin_dvi_link_test_top, this does not use Gowin DVI_TX IP.
module rk3588_custom_dvi_link_test_top (
    input  wire       clk50M,
    input  wire       reset_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire [3:0] led
);
    rk3588_hdmi_link_test_top #(
        .CUSTOM_DVI_OUTPUT(1'b1)
    ) u_test (
        .clk50M(clk50M),
        .reset_n(reset_n),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_data_p(tmds_data_p),
        .tmds_data_n(tmds_data_n),
        .led(led)
    );
endmodule
