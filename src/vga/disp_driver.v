/*============================================================================
*
*  LOGIC CORE:          显示设备驱动模块		
*  MODULE NAME:         disp_driver()
*  COMPANY:             武汉芯路恒科技有限公司
*                       http://xiaomeige.taobao.com
*  author:              小梅哥
*  Website:             www.corecourse.cn
*  REVISION HISTORY:  
*
*  Revision 1.0  04/10/2019
*  Description: Initial Release.
*
*  FUNCTIONAL DESCRIPTION:
===========================================================================*/
`include "disp_parameter_cfg.v"

module disp_driver(
	ClkDisp,
	Rst_n,
	
	Data,
	DataReq,
	
	H_Addr,
	V_Addr,
	
	Disp_HS,
	Disp_VS,
	Disp_Red,
	Disp_Green,
	Disp_Blue,
    Frame_Begin,
	Disp_DE,
	Disp_PCLK
);

	input ClkDisp;
	input Rst_n;
	input [`Red_Bits + `Green_Bits + `Blue_Bits - 1:0] Data;
	output DataReq;
	
	output [11:0] H_Addr;
	output [11:0] V_Addr;
	
	output reg Disp_HS;
	output reg Disp_VS;

	output reg [`Red_Bits - 1 :0]Disp_Red;
	output reg [`Green_Bits - 1 :0]Disp_Green;
	output reg [`Blue_Bits - 1 :0]Disp_Blue;
	
    output reg Frame_Begin; //一帧图像起始标识信号，ClkDisp时钟域
	output reg Disp_DE;
	output Disp_PCLK;
	
	wire hcount_ov;
	wire vcount_ov;
	
	//----------------内部寄存器定义----------------
	reg [11:0] hcount_r;     //行扫描计数器
	reg [11:0] vcount_r;     //场扫描计数器

	`ifdef HW_VGA
		assign Disp_PCLK = ~ClkDisp;
	`else
		assign Disp_PCLK = ClkDisp;
	`endif	

	assign DataReq = Disp_DE;
	
	// Counter range is 0..total-1.  Do not subtract one from the active
	// boundaries: doing so moves one pixel/line from the back porch to the
	// front porch and produces a non-CEA timing.
	// Use the CEA/HDMI phase convention used by the true-HDMI packet core:
	// active video first, followed by front porch, sync and back porch.  A
	// cyclic phase shift does not change the 1650x750 raster, but keeping both
	// blocks in the same phase lets the camera/OSD pixels line up exactly with
	// the HDMI core's cx/cy active-video interval.
	parameter hdat_begin = 12'd0;
	parameter hdat_end = `H_Total_Time - `H_Front_Porch -
		`H_Sync_Time - `H_Back_Porch - `H_Left_Border - `H_Right_Border;
	
	parameter vdat_begin = 12'd0;
	parameter vdat_end = `V_Total_Time - `V_Front_Porch -
		`V_Sync_Time - `V_Back_Porch - `V_Top_Border - `V_Bottom_Border;
	
	assign H_Addr = Disp_DE?(hcount_r - hdat_begin):12'd0;
	assign V_Addr = Disp_DE?(vcount_r - vdat_begin):12'd0;

	//行扫描
	assign hcount_ov = (hcount_r >= `H_Total_Time - 1);
	
	always@(posedge ClkDisp or negedge Rst_n)
	if(!Rst_n)
		hcount_r <= 0;
	else if(hcount_ov)
		hcount_r <= 0;
	else
		hcount_r <= hcount_r + 1'b1;

	//场扫描
	assign vcount_ov = (vcount_r >= `V_Total_Time - 1);

	always@(posedge ClkDisp or negedge Rst_n)
	if(!Rst_n)
		vcount_r <= 0;
	else if(hcount_ov) begin
		if(vcount_ov)
			vcount_r <= 0;
		else
			vcount_r <= vcount_r + 1'd1;
	end
	else 
		vcount_r <= vcount_r;
	
	always@(posedge ClkDisp or negedge Rst_n) begin
		if(!Rst_n) begin
			Disp_DE <= 1'b0;
			Disp_HS <= 1'b0;
			Disp_VS <= 1'b0;
			{Disp_Red,Disp_Green,Disp_Blue} <= 24'd0;
		end else begin
			Disp_DE <= ((hcount_r >= hdat_begin)&&(hcount_r < hdat_end))
						&&((vcount_r >= vdat_begin)&&(vcount_r < vdat_end));
			// CEA-861 1280x720p60 uses positive HSYNC and VSYNC.
			Disp_HS <= (hcount_r >= hdat_end + `H_Front_Porch) &&
				(hcount_r < hdat_end + `H_Front_Porch + `H_Sync_Time);
			Disp_VS <= (vcount_r >= vdat_end + `V_Front_Porch) &&
				(vcount_r < vdat_end + `V_Front_Porch + `V_Sync_Time);
			{Disp_Red,Disp_Green,Disp_Blue} <= (Disp_DE)?Data:24'd0;
		end
	end
	
  /*******************************************/
  reg Disp_VS_dly1;
  always@(posedge ClkDisp or negedge Rst_n)
  begin
    if(!Rst_n)
      Disp_VS_dly1 <= 1'b0;
    else
      Disp_VS_dly1 <= Disp_VS;
  end

  always@(posedge ClkDisp or negedge Rst_n)
  begin
    if(!Rst_n)
      Frame_Begin <= 1'b0;
    else if(!Disp_VS_dly1 && Disp_VS)
      Frame_Begin <= 1'b1;
    else
      Frame_Begin <= 1'b0;
  end
  /*******************************************/

endmodule
