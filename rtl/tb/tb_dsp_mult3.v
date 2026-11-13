`timescale 1ns/1ps
// tb_dsp_mult3: 乘法器原语包装验证 (H04)。
// 检查: 1) 随机 2000 组 16x16 有符号乘积逐位正确且延迟恰 3 拍;
//       2) en 冻结时流水线保持不变; 3) 同步复位清零且复位后无陈旧输出。
module tb_dsp_mult3;
    reg clk = 0, rst = 1, en = 0;
    reg signed [15:0] a = 0, b = 0;
    wire signed [30:0] p;
    integer seed = 32'h20261114;
    integer i, errors;
    reg signed [31:0] e0, e1, e2;   // 期望流水: e0 = 3 拍前驱动值

    dsp_mult3 dut (.clk(clk), .rst(rst), .en(en), .a(a), .b(b), .p(p));

    always #5 clk = ~clk;

    // 推进一拍并校验 p == e0 (3 拍前驱动), 然后驱动 (na, nb)
    task step(input signed [15:0] na, input signed [15:0] nb);
        begin
            if (p !== e0[30:0]) begin
                errors = errors + 1;
                $display("FAIL p=%0d 期望 %0d (t=%0t)", p, e0, $time);
            end
            e0 = e1; e1 = e2; e2 = na * nb;
            a = na; b = nb;
            @(negedge clk);
        end
    endtask

    initial begin
        errors = 0;
        e0 = 0; e1 = 0; e2 = 0;
        rst = 1; en = 0; a = 0; b = 0;
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);

        // ---- 1) 随机乘积, 延迟恰 3 拍 ----
        en = 1;
        for (i = 0; i < 2000; i = i + 1)
            step($random(seed), $random(seed));

        // ---- 2) en 冻结保持 ----
        a = 16'sd100; b = 16'sd3;
        e0 = 100 * 3; e1 = 100 * 3; e2 = 100 * 3;   // 流水填满 (100,3)
        repeat (3) @(negedge clk);
        if (p !== 100 * 3) begin
            errors = errors + 1;
            $display("FAIL 填充后 p=%0d 期望 %0d", p, 100 * 3);
        end
        en = 0;                                   // 冻结 3 拍
        a = 16'sd77; b = 16'sd7;                  // 改输入不被采样
        repeat (3) @(negedge clk);
        if (p !== 100 * 3) begin
            errors = errors + 1;
            $display("FAIL 冻结期 p=%0d 应保持 %0d", p, 100 * 3);
        end
        en = 1;                                   // 解冻 3 拍
        repeat (3) @(negedge clk);
        if (p !== 77 * 7) begin
            errors = errors + 1;
            $display("FAIL 解冻后 p=%0d 期望 %0d", p, 77 * 7);
        end

        // ---- 3) 同步复位清零, 复位后无陈旧输出 ----
        rst = 1; en = 1;
        @(negedge clk);
        if (p !== 31'sd0) begin
            errors = errors + 1;
            $display("FAIL 复位拍 p=%0d 应清零", p);
        end
        rst = 0; en = 0;
        repeat (3) @(negedge clk);
        if (p !== 31'sd0) begin
            errors = errors + 1;
            $display("FAIL 复位后 p=%0d 应保持 0", p);
        end

        if (errors == 0)
            $display("TB_DSP_MULT3 PASS (延迟=3拍, 乘积逐位, en 门控, 复位清零)");
        else
            $display("TB_DSP_MULT3 FAIL errors=%0d", errors);
        $finish;
    end
endmodule
