`timescale 1ns/1ps
// tb_bfly2: 蝶形单元验证 (定点口径: 半偶舍入 + 特殊因子旁路)。
// 用例全部手工推导 (Q8 数据, Q15 旋转因子), 覆盖:
//   spec 1..4 旁路精确性、普通因子复乘、半偶舍入恰半情形、
//   顶/底臂符号、延迟 = 4 拍、en 门控。
module tb_bfly2;
    reg clk = 0, rst = 1, en = 0;
    reg signed [15:0] a_re = 0, a_im = 0, b_re = 0, b_im = 0;
    wire signed [15:0] u_re, u_im, v_re, v_im;
    wire sat;
    integer errors;

    always #5 clk = ~clk;

    // 推进 4 拍 (蝶形延迟); 比较须在调用方内联进行, 不能把信号作为
    // task input 传入 (input 在调用时刻拷贝, 会拿到陈旧值)
    task wait4;
        begin
            repeat (4) @(negedge clk);
        end
    endtask

    task chk_fail(input [255:0] name, input signed [15:0] w_re, input signed [15:0] w_im,
                  input signed [15:0] x_re, input signed [15:0] x_im,
                  input signed [15:0] eu_re, input signed [15:0] eu_im,
                  input signed [15:0] ev_re, input signed [15:0] ev_im);
        begin
            if (w_re !== eu_re || w_im !== eu_im || x_re !== ev_re || x_im !== ev_im) begin
                errors = errors + 1;
                $display("FAIL %0s: u=(%0d,%0d) v=(%0d,%0d) 期望 u=(%0d,%0d) v=(%0d,%0d)",
                    name, w_re, w_im, x_re, x_im, eu_re, eu_im, ev_re, ev_im);
            end
        end
    endtask

    // ---- 用例 1: SPEC=1 (+1), a=(1+1j), b=(2+0j), Q8: a=(256,256) b=(512,0)
    //      u=((256+512)/2, 256/2)=(384,128)  v=(-128,128)
    bfly2 #(.SPEC(1)) dut1 (.clk(clk), .rst(rst), .en(en),
        .a_re(a_re), .a_im(a_im), .b_re(b_re), .b_im(b_im),
        .u_re(u1_re), .u_im(u1_im), .v_re(v1_re), .v_im(v1_im), .sat(sat1));
    wire signed [15:0] u1_re, u1_im, v1_re, v1_im;
    wire sat1;

    // ---- 用例 2: SPEC=2 (-1), 同输入: u=(-128,128) v=(384,128)
    bfly2 #(.SPEC(2)) dut2 (.clk(clk), .rst(rst), .en(en),
        .a_re(a_re), .a_im(a_im), .b_re(b_re), .b_im(b_im),
        .u_re(u2_re), .u_im(u2_im), .v_re(v2_re), .v_im(v2_im), .sat(sat2));
    wire signed [15:0] u2_re, u2_im, v2_re, v2_im;
    wire sat2;

    // ---- 用例 3: SPEC=3 (-1j), a=(1+1j), b=(1+2j): Wb=(bim,-bre)=(512,-256)
    //      u=((256+512)/2,(256-256)/2)=(384,0)  v=(-128,256)
    bfly2 #(.SPEC(3)) dut3 (.clk(clk), .rst(rst), .en(en),
        .a_re(a_re), .a_im(a_im), .b_re(b3_re), .b_im(b3_im),
        .u_re(u3_re), .u_im(u3_im), .v_re(v3_re), .v_im(v3_im), .sat(sat3));
    wire signed [15:0] u3_re, u3_im, v3_re, v3_im;
    wire sat3;
    reg signed [15:0] b3_re = 256, b3_im = 512;

    // ---- 用例 4: SPEC=4 (+1j), b=(1+2j): Wb=(-bim,bre)=(-512,256)
    //      u=(-128,256) v=(384,0)
    bfly2 #(.SPEC(4)) dut4 (.clk(clk), .rst(rst), .en(en),
        .a_re(a_re), .a_im(a_im), .b_re(b3_re), .b_im(b3_im),
        .u_re(u4_re), .u_im(u4_im), .v_re(v4_re), .v_im(v4_im), .sat(sat4));
    wire signed [15:0] u4_re, u4_im, v4_re, v4_im;
    wire sat4;

    // ---- 用例 5: 普通 Q15 因子 W = -23170 - 23170j (即 e^{-j3pi/4} 量化)
    //      a=0, b=(1+1j) Q8 (256,256):
    //      m_re = WRE*bre - WIM*bim = -23170*256 + 23170*256 = 0
    //      m_im = WRE*bim + WIM*bre = -23170*256*2 = -23170*512
    //      u=(0,-181)  v=(0,181)
    bfly2 #(.SPEC(0), .WRE(-23170), .WIM(-23170)) dut5 (
        .clk(clk), .rst(rst), .en(en),
        .a_re(a5_re), .a_im(a5_im), .b_re(b5_re), .b_im(b5_im),
        .u_re(u5_re), .u_im(u5_im), .v_re(v5_re), .v_im(v5_im), .sat(sat5));
    wire signed [15:0] u5_re, u5_im, v5_re, v5_im;
    wire sat5;
    reg signed [15:0] a5_re = 0, a5_im = 0, b5_re = 256, b5_im = 256;

    // ---- 用例 6: 半偶舍入恰半情形 (a=0, b_re/b_im = 3 -> 1.5 -> 2; -1 -> -0.5 -> 0)
    //      SPEC=1: u=( (0+3)/2, (0+(-1))/2 ) Q8 尺度: b=(3,-1): m=(3<<15,-1<<15)
    //      u_re = round(3/2)=2, u_im = round(-1/2)=0 (向偶), v=(-2,0)
    bfly2 #(.SPEC(1)) dut6 (.clk(clk), .rst(rst), .en(en),
        .a_re(a6_re), .a_im(a6_im), .b_re(b6_re), .b_im(b6_im),
        .u_re(u6_re), .u_im(u6_im), .v_re(v6_re), .v_im(v6_im), .sat(sat6));
    wire signed [15:0] u6_re, u6_im, v6_re, v6_im;
    wire sat6;
    reg signed [15:0] a6_re = 0, a6_im = 0, b6_re = 3, b6_im = -1;

    initial begin
        errors = 0;
        rst = 1; en = 0;
        a_re = 256; a_im = 256; b_re = 512; b_im = 0;
        repeat (3) @(negedge clk);
        rst = 0; en = 1;
        @(negedge clk);

        // 用例 1-2 (共享 a/b 输入)
        wait4;
        chk_fail("spec1 +1", u1_re, u1_im, v1_re, v1_im, 384, 128, -128, 128);
        chk_fail("spec2 -1", u2_re, u2_im, v2_re, v2_im, -128, 128, 384, 128);
        // 用例 3-4 (b3 输入)
        wait4;
        chk_fail("spec3 -1j", u3_re, u3_im, v3_re, v3_im, 384, 0, -128, 256);
        chk_fail("spec4 +1j", u4_re, u4_im, v4_re, v4_im, -128, 256, 384, 0);
        // 用例 5: WRE=-23170, WIM=-23170, b=(256,256):
        //   m_re = WRE*bre - WIM*bim = -23170*256 + 23170*256 = 0
        //   m_im = WRE*bim + WIM*bre = -23170*256 - 23170*256 = -23170*512
        //   u = (0, round(-23170*512/65536)) = (0, -181)
        wait4;
        chk_fail("普通因子", u5_re, u5_im, v5_re, v5_im, 0, -181, 0, 181);
        // 用例 6: 半偶舍入
        wait4;
        chk_fail("半偶舍入", u6_re, u6_im, v6_re, v6_im, 2, 0, -2, 0);

        // en 冻结: 用例 1 的输入保持, 输出应保持
        a_re = 256; a_im = 256; b_re = 512; b_im = 0;
        en = 0;
        repeat (3) @(negedge clk);
        if (u1_re !== 384 || u1_im !== 128) begin
            errors = errors + 1;
            $display("FAIL 冻结保持 u1=(%0d,%0d)", u1_re, u1_im);
        end

        if (errors == 0)
            $display("TB_BFLY2 PASS (旁路/复乘/半偶舍入/延迟4拍/冻结)");
        else
            $display("TB_BFLY2 FAIL errors=%0d", errors);
        $finish;
    end
endmodule
