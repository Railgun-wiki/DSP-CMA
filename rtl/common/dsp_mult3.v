// dsp_mult3: 16x16 有符号乘法器, 3 拍数据延迟 (AGENTS H04)。
// 综合实现: DSP48E2 原语 (xcvu13p), A/B/M 各 1 级寄存器 + 外层输出
// 寄存器 => 恰 3 拍 (PREG=0, 与 rtl/sim/dsp_mult3_sim.v 口径一致)。
// 仿真实现见 rtl/sim/dsp_mult3_sim.v (同名模块, 仅进入仿真文件清单,
// 不进入综合源清单; AGENTS 6.3/7 允许隔离行为模型)。
// 端口:
//   clk, rst(同步高有效), en(流水线使能, 低时冻结)
//   a, b: 16 bit 有符号 Q8
//   p:    31 bit 有符号 = a*b (恰 3 个 en 有效拍后有效)
module dsp_mult3 (
    input  wire               clk,
    input  wire               rst,
    input  wire               en,
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,
    output reg  signed [30:0] p
);
    // DSP48E2: 乘法器 27x18 有符号; A/B 各 1 级输入寄存, M 1 级, P 1 级
    wire signed [29:0] a_ext = {{14{a[15]}}, a};   // 30 bit, 高位符号扩展
    wire signed [17:0] b_ext = {{2{b[15]}}, b};    // 18 bit
    wire [47:0] p48;

    DSP48E2 #(
        .AREG(1),
        .BREG(1),
        .MREG(1),
        .PREG(0),
        .CREG(1),
        .DREG(1),
        .ADREG(1),
        .ALUMODEREG(1),
        .CARRYINREG(1),
        .CARRYINSELREG(1),
        .OPMODEREG(1),
        .USE_MULT("MULTIPLIER")
    ) u_dsp48e2 (
        .CLK          (clk),
        .CE           (en),
        .RST          (rst),
        .A            (a_ext),
        .B            (b_ext),
        .C            (48'd0),
        .D            (25'd0),
        .ALUMODE      (4'b0000),      // P = Z + Y + X + CIN
        .OPMODE       (7'b0000011),   // Z=0, Y=0, X=M
        .CARRYIN      (1'b0),
        .CARRYINSEL   (3'b000),
        .P            (p48),
        .CARRYCASCIN  (1'b0),
        .MULTSIGNIN   (1'b0),
        // 未用输出悬空
        .CARRYOUT     (),
        .CARRYCASCOUT (),
        .MULTSIGNOUT  (),
        .PATTERNDETECT(),
        .PATTERNBDETECT()
    );

    always @(posedge clk) begin
        if (rst)
            p <= 31'sd0;
        else if (en)
            p <= p48[30:0];
    end
endmodule
