// bfly2: 基-2 DIT 蝶形 (a ± W*b)/2, 数据 Q8 16 bit, 旋转因子 Q15。
// 定点口径 (docs/architecture.md 定点表):
//   * W·b: 4 路精确 16x16 乘积 (dsp_mult3, 恰 3 拍) 或特殊因子旁路
//     (spec 1=+1, 2=-1, 3=-1j, 4=+1j; 精确移位/交换, 旁路经同样 3 拍
//     寄存对齐, AGENTS 5 "四条路径及旁路必须对齐");
//   * 和 = a<<15 ± W·b (Q23, 33 bit 有符号);
//   * 每级缩放 1/2: round_half_even(sum/2^16) 回 Q8 16 bit, 饱和计数。
// 结构: a/b 各 3 拍延迟链 (与乘法对齐) -> 蝶形组合舍入 -> 输出寄存,
// 级延迟恰 4 拍; en 低时整级冻结。
module bfly2 #(
    parameter signed [2:0]  SPEC = 0,   // 0 普通, 1=+1, 2=-1, 3=-1j, 4=+1j
    parameter signed [15:0] WRE  = 0,
    parameter signed [15:0] WIM  = 0
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               en,
    input  wire signed [15:0] a_re,
    input  wire signed [15:0] a_im,
    input  wire signed [15:0] b_re,
    input  wire signed [15:0] b_im,
    output reg  signed [15:0] u_re,     // (a + Wb)/2
    output reg  signed [15:0] u_im,
    output reg  signed [15:0] v_re,     // (a - Wb)/2
    output reg  signed [15:0] v_im,
    output reg                sat       // 本拍任一输出发生饱和
);
    // ---- a/b 路延迟 (3 拍, 与乘法路径对齐) ----
    reg signed [15:0] a_re_d1, a_re_d2, a_re_d3;
    reg signed [15:0] a_im_d1, a_im_d2, a_im_d3;
    reg signed [15:0] b_re_d1, b_re_d2, b_re_d3;
    reg signed [15:0] b_im_d1, b_im_d2, b_im_d3;
    // ---- 复乘结果 (组合, 与 a_d3 同拍有效) ----
    wire signed [30:0] m_re_eff, m_im_eff;

    generate
        if (SPEC == 0) begin : g_mult
            wire signed [30:0] p_rr, p_ri, p_ir, p_ii;
            dsp_mult3 u_rr (.clk(clk), .rst(rst), .en(en), .a(WRE), .b(b_re), .p(p_rr));
            dsp_mult3 u_ri (.clk(clk), .rst(rst), .en(en), .a(WRE), .b(b_im), .p(p_ri));
            dsp_mult3 u_ir (.clk(clk), .rst(rst), .en(en), .a(WIM), .b(b_re), .p(p_ir));
            dsp_mult3 u_ii (.clk(clk), .rst(rst), .en(en), .a(WIM), .b(b_im), .p(p_ii));
            assign m_re_eff = p_rr - p_ii;   // WRE*bre - WIM*bim
            assign m_im_eff = p_ri + p_ir;   // WRE*bim + WIM*bre
        end else begin : g_bypass
            // 旁路: 由第 3 拍的 b_d3 精确组合 (无乘法量化)
            assign m_re_eff = bypass_re(SPEC, b_re_d3, b_im_d3);
            assign m_im_eff = bypass_im(SPEC, b_re_d3, b_im_d3);
        end
    endgenerate

    function signed [30:0] bypass_re(input signed [2:0] sp, input signed [15:0] br, input signed [15:0] bi);
        begin
            case (sp)
                3'd1:    bypass_re = br <<< 15;      // +1
                3'd2:    bypass_re = -(br <<< 15);   // -1
                3'd3:    bypass_re = bi <<< 15;      // -1j: +bim
                default: bypass_re = -(bi <<< 15);   // +1j: -bim
            endcase
        end
    endfunction

    function signed [30:0] bypass_im(input signed [2:0] sp, input signed [15:0] br, input signed [15:0] bi);
        begin
            case (sp)
                3'd1:    bypass_im = bi <<< 15;
                3'd2:    bypass_im = -(bi <<< 15);
                3'd3:    bypass_im = -(br <<< 15);   // -1j: -bre
                default: bypass_im = br <<< 15;      // +1j: +bre
            endcase
        end
    endfunction

    // 显式符号扩展到 33 bit (Q23 对齐)
    function signed [32:0] ext_a(input signed [15:0] v);
        ext_a = {{17{v[15]}}, v} <<< 15;      // a<<15, Q23
    endfunction
    function signed [32:0] ext_m(input signed [30:0] v);
        ext_m = {{2{v[30]}}, v};
    endfunction

    // 半偶舍入 Q23 -> Q8 并饱和 (与 MATLAB q23_to_q8 逐位一致)。
    // 返回 {sat, q[15:0]}, 避免函数输出形参 (Verilog-2001 保守口径)。
    function [16:0] q23_round_sat(input signed [32:0] t);
        reg signed [32:0] base;
        reg [15:0] rem;
        reg signed [32:0] q;
        reg sat_o;
        begin
            base = t >>> 16;          // 算术右移 = floor 除法
            rem  = t[15:0];           // floor 语义下余数非负
            if (rem > 16'd32768)
                q = base + 33'sd1;
            else if (rem < 16'd32768)
                q = base;
            else if (base[0] == 1'b0)
                q = base;             // 恰半向偶
            else
                q = base + 33'sd1;
            if (q > 33'sd32767) begin
                q = 33'sd32767;
                sat_o = 1'b1;
            end else if (q < -33'sd32768) begin
                q = -33'sd32768;
                sat_o = 1'b1;
            end else begin
                sat_o = 1'b0;
            end
            q23_round_sat = {sat_o, q[15:0]};
        end
    endfunction

    // 蝶形: 顶臂 (a+m)/2, 底臂 (a-m)/2, 实虚两路 + 饱和
    task do_butterfly(
        input signed [15:0] are,
        input signed [15:0] aim,
        input signed [30:0] mre,
        input signed [30:0] mim,
        output signed [15:0] ure,
        output signed [15:0] uim,
        output signed [15:0] vre,
        output signed [15:0] vim,
        output sat_o
    );
        reg signed [32:0] sum_t, sum_b;
        reg [16:0] ru, rv, rui, rvi;
        begin
            sum_t = ext_a(are) + ext_m(mre);    // Q23 有符号
            sum_b = ext_a(are) - ext_m(mre);
            ru = q23_round_sat(sum_t);
            rv = q23_round_sat(sum_b);
            sum_t = ext_a(aim) + ext_m(mim);
            sum_b = ext_a(aim) - ext_m(mim);
            rui = q23_round_sat(sum_t);
            rvi = q23_round_sat(sum_b);
            ure = ru[15:0]; uim = rui[15:0];
            vre = rv[15:0]; vim = rvi[15:0];
            sat_o = ru[16] | rv[16] | rui[16] | rvi[16];
        end
    endtask

    // ---- 蝶形组合计算 (读第 3 拍寄存值; 输出寄存另起一拍 => 级延迟 4 拍) ----
    reg signed [15:0] r_u_re, r_u_im, r_v_re, r_v_im;
    reg r_sat;
    always @* begin
        r_u_re = 16'sd0; r_u_im = 16'sd0; r_v_re = 16'sd0; r_v_im = 16'sd0;
        r_sat = 1'b0;
        do_butterfly(a_re_d3, a_im_d3, m_re_eff, m_im_eff,
                     r_u_re, r_u_im, r_v_re, r_v_im, r_sat);
    end

    // ---- 流水线 (en 门控: 冻结时整级暂停) ----
    always @(posedge clk) begin
        if (rst) begin
            a_re_d1 <= 16'sd0; a_re_d2 <= 16'sd0; a_re_d3 <= 16'sd0;
            a_im_d1 <= 16'sd0; a_im_d2 <= 16'sd0; a_im_d3 <= 16'sd0;
            b_re_d1 <= 16'sd0; b_re_d2 <= 16'sd0; b_re_d3 <= 16'sd0;
            b_im_d1 <= 16'sd0; b_im_d2 <= 16'sd0; b_im_d3 <= 16'sd0;
            u_re <= 16'sd0; u_im <= 16'sd0; v_re <= 16'sd0; v_im <= 16'sd0;
            sat <= 1'b0;
        end else if (en) begin
            a_re_d1 <= a_re; a_re_d2 <= a_re_d1; a_re_d3 <= a_re_d2;
            a_im_d1 <= a_im; a_im_d2 <= a_im_d1; a_im_d3 <= a_im_d2;
            b_re_d1 <= b_re; b_re_d2 <= b_re_d1; b_re_d3 <= b_re_d2;
            b_im_d1 <= b_im; b_im_d2 <= b_im_d1; b_im_d3 <= b_im_d2;
            u_re <= r_u_re; u_im <= r_u_im;
            v_re <= r_v_re; v_im <= r_v_im;
            sat <= r_sat;
        end
    end
endmodule
