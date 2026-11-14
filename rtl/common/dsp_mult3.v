// dsp_mult3: 16x16 有符号乘法器, 3 拍数据延迟 (AGENTS H04)。
// 综合实现: DSP48E2 原语 (xcvu13p)。流水线配置 AREG=BREG=MREG=1,
// PREG=0, 外层输出寄存 => 恰 3 拍 (与 rtl/sim/dsp_mult3_sim.v 口径
// 一致)。端口连接按官方 unisim 声明 (D 27 bit, OPMODE 9 bit,
// USE_MULT="MULTIPLY", 独立 CEx/RSTx 控制位); 已用官方 unisim 模型
// 在 Verilator 中完成接口对接与延迟/使能/复位行为仿真。
// 仿真实现见 rtl/sim/dsp_mult3_sim.v (同名模块, 仅进入仿真文件清单;
// Vivado xsim 亦可用官方 unisim 模型替换行为模型, 见 scripts/vivado/)。
module dsp_mult3 (
    input  wire               clk,
    input  wire               rst,     // 同步高有效: 清空本原语全部流水级
    input  wire               en,      // 流水线使能, 低时冻结
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,
    output reg  signed [30:0] p        // = a*b, 恰 3 个 en 有效拍后有效
);
    // 乘法器 27x18 有符号: A/B 高位符号扩展
    wire signed [29:0] a_ext = {{14{a[15]}}, a};
    wire signed [17:0] b_ext = {{2{b[15]}}, b};
    wire [47:0] p48;

    DSP48E2 #(
        .AREG(1),
        .ACASCREG(1),
        .BREG(1),
        .BCASCREG(1),
        .MREG(1),
        .PREG(0),            // 外层输出寄存承担第 3 拍
        .CREG(1),
        .DREG(1),
        .ADREG(1),
        .ALUMODEREG(1),
        .CARRYINREG(1),
        .CARRYINSELREG(1),
        .INMODEREG(1),
        .USE_MULT("MULTIPLY")
    ) u_dsp48e2 (
        .CLK          (clk),
        .CEA1         (en),
        .CEA2         (en),
        .CEAD         (en),
        .CEALUMODE    (en),
        .CEB1         (en),
        .CEB2         (en),
        .CEC          (en),
        .CECARRYIN    (en),
        .CECTRL       (en),
        .CED          (en),
        .CEINMODE     (en),
        .CEM          (en),
        .CEP          (en),
        .RSTA         (rst),
        .RSTB         (rst),
        .RSTM         (rst),
        .RSTP         (rst),
        .RSTC         (rst),
        .RSTD         (rst),
        .RSTCTRL      (rst),
        .RSTALUMODE   (rst),
        .RSTALLCARRYIN(rst),
        .RSTINMODE    (rst),
        .A            (a_ext),
        .B            (b_ext),
        .C            (48'd0),
        .D            (27'd0),
        .ALUMODE      (4'b0000),      // P = Z + Y + X + CIN
        .OPMODE       (9'b000000011), // Z=0, Y=0, X=M
        .CARRYIN      (1'b0),
        .CARRYINSEL   (3'b000),
        .INMODE       (5'b00000),
        .ACIN         (30'd0),
        .BCIN         (18'd0),
        .PCIN         (48'd0),
        .CARRYCASCIN  (1'b0),
        .MULTSIGNIN   (1'b0),
        .P            (p48),
        .ACOUT        (),
        .BCOUT        (),
        .CARRYCASCOUT (),
        .CARRYOUT     (),
        .MULTSIGNOUT  (),
        .OVERFLOW     (),
        .PATTERNDETECT(),
        .PATTERNBDETECT(),
        .PCOUT        (),
        .UNDERFLOW    (),
        .XOROUT       ()
    );

    always @(posedge clk) begin
        if (rst)
            p <= 31'sd0;
        else if (en)
            p <= p48[30:0];
    end
endmodule
