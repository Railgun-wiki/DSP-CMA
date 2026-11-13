`timescale 1ns/1ps
// tb_fft64: 64 点全并行 FFT 逐位对照 (H05)。
// 与 MATLAB 定点整数模型生成的向量 (rtl/tb/vectors/fft32_*.mem) 比较:
//   相位 A: 连续流 (帧背靠背), 逐位一致 + 首帧延迟恰 22 拍 (4*5+2);
//   相位 B: 气泡流 (帧间随机空拍), 输出次序与数据不变;
//   相位 C: 中途同步复位, 复位窗内无陈旧 out_valid, 复位后帧序完整。
// 向量格式: 每行一帧, 点 k 实部 [16k +: 8]、虚部 [16k+8 +: 8], 二补码 hex。
module tb_fft64;
    localparam integer N = 64;
    localparam integer L = 26;           // 4*S + 2, S = 6
    localparam integer FRAMES = 8;
    localparam integer BYTES = 2 * N;

    reg clk = 0, rst = 1, in_valid = 0;
    reg [1023:0] din = 0;
    wire [1023:0] dout;
    wire out_valid;
    wire [31:0] sat_cnt;

    fft64_top dut (.clk(clk), .rst(rst), .in_valid(in_valid),
                   .din(din), .dout(dout), .out_valid(out_valid),
                   .sat_cnt(sat_cnt));

    always #5 clk = ~clk;

    reg [7:0] vin [0:FRAMES*BYTES-1];
    reg [7:0] vex [0:FRAMES*BYTES-1];
    integer errors, out_frames;
    integer f, k, i, gap, guard;
    integer seed = 32'h20261114;

    function [3:0] hexval(input [7:0] ch);
        begin
            case (ch)
                "0": hexval = 4'd0;  "1": hexval = 4'd1;
                "2": hexval = 4'd2;  "3": hexval = 4'd3;
                "4": hexval = 4'd4;  "5": hexval = 4'd5;
                "6": hexval = 4'd6;  "7": hexval = 4'd7;
                "8": hexval = 4'd8;  "9": hexval = 4'd9;
                "a","A": hexval = 4'd10; "b","B": hexval = 4'd11;
                "c","C": hexval = 4'd12; "d","D": hexval = 4'd13;
                "e","E": hexval = 4'd14; "f","F": hexval = 4'd15;
                default: hexval = 4'd0;
            endcase
        end
    endfunction

    // 读向量文件: 每行一帧 (BYTES 字节 = 2*BYTES 个 hex 字符)
    task read_file(input [1023:0] path, input integer is_exp);
        integer fd, ch, hi, rf, kk;
        reg [7:0] bval;
        begin
            fd = $fopen(path, "r");
            if (fd == 0) begin
                $display("FAIL 无法打开向量文件: %0s", path);
                errors = errors + 1;
                $finish;
            end
            for (rf = 0; rf < FRAMES; rf = rf + 1) begin
                for (kk = 0; kk < BYTES; kk = kk + 1) begin
                    hi = $fgetc(fd);
                    ch = $fgetc(fd);
                    bval = {hexval(hi[7:0]), hexval(ch[7:0])};
                    if (is_exp) vex[rf*BYTES + kk] = bval;
                    else        vin[rf*BYTES + kk] = bval;
                end
                // 消费行尾 (含可能的 CR)
                ch = $fgetc(fd);
                while (ch == "\r") ch = $fgetc(fd);
                if (ch != "\n" && ch != -1) begin
                    $display("FAIL 行尾格式异常 (帧 %0d): %0c", rf, ch);
                    errors = errors + 1;
                end
            end
            $fclose(fd);
        end
    endtask

    function [1023:0] pack_in(input integer base);
        integer kk;
        begin
            pack_in = 0;
            for (kk = 0; kk < N; kk = kk + 1) begin
                pack_in[16*kk +: 8]     = vin[base + 2*kk];
                pack_in[16*kk + 8 +: 8] = vin[base + 2*kk + 1];
            end
        end
    endfunction

    function [1023:0] pack_exp(input integer base);
        integer kk;
        begin
            pack_exp = 0;
            for (kk = 0; kk < N; kk = kk + 1) begin
                pack_exp[16*kk +: 8]     = vex[base + 2*kk];
                pack_exp[16*kk + 8 +: 8] = vex[base + 2*kk + 1];
            end
        end
    endfunction

    // 输出检查 (negedge 采样, DUT 在 posedge 更新)
    always @(negedge clk) begin
        if (!rst && out_valid) begin
            if (out_frames < FRAMES * 3) begin
                if (dout !== pack_exp((out_frames % FRAMES) * BYTES)) begin
                    errors = errors + 1;
                    $display("FAIL 帧序 %0d 数据不匹配 dout=%h", out_frames, dout);
                end
            end
            out_frames = out_frames + 1;
        end
    end

    task wait_out(input integer n);
        begin
            guard = 0;
            while (out_frames < n && guard < 4 * (L + FRAMES + 64)) begin
                @(negedge clk);
                guard = guard + 1;
            end
            if (out_frames < n) begin
                errors = errors + 1;
                $display("FAIL 输出帧数不足 %0d/%0d", out_frames, n);
            end
        end
    endtask

    integer lat_cnt, lat_seen;
    task run_case(input integer ci, input integer meas_lat);
        reg [63:0] n8;
        begin
            case (ci)
                0: n8 = "impulse0";
                1: n8 = "impulsel";
                2: n8 = "constant";
                3: n8 = "toneq000";
                4: n8 = "random00";
                5: n8 = "extreme0";
            endcase
            read_file({"rtl/tb/vectors/fft64_in_", n8, ".mem"}, 0);
            read_file({"rtl/tb/vectors/fft64_exp_", n8, ".mem"}, 1);

            // ---- 相位 A: 连续流 + 可选延迟测量 ----
            out_frames = 0;
            for (f = 0; f < FRAMES; f = f + 1) begin
                @(negedge clk);
                din = pack_in(f * BYTES);
                in_valid = 1;
            end
            @(negedge clk);      // 末帧在本拍被 posedge 采样后再撤销 valid
            in_valid = 0;
            if (meas_lat) begin
                lat_cnt = FRAMES;       // 驱动循环后已过 FRAMES 拍
                lat_seen = 0;
                while (!lat_seen && lat_cnt < 8 * L) begin
                    @(negedge clk);
                    lat_cnt = lat_cnt + 1;
                    if (out_valid) lat_seen = 1;
                end
                if (!lat_seen || lat_cnt != L) begin
                    errors = errors + 1;
                    $display("FAIL 首帧延迟 %0d != %0d", lat_cnt, L);
                end else
                    $display("  首帧延迟 = %0d 拍 (期望 %0d)", lat_cnt, L);
            end
            wait_out(FRAMES);

            // ---- 相位 B: 气泡流 ----
            out_frames = 0;
            for (f = 0; f < FRAMES; f = f + 1) begin
                @(negedge clk);
                din = pack_in(f * BYTES);
                in_valid = 1;
                @(negedge clk);
                in_valid = 0;
                gap = $random(seed) % 4;
                repeat (gap) @(negedge clk);
            end
            wait_out(FRAMES);

            // ---- 相位 C: 中途同步复位 ----
            out_frames = 0;
            for (f = 0; f < 3; f = f + 1) begin
                @(negedge clk);
                din = pack_in(f * BYTES);
                in_valid = 1;
            end
            in_valid = 0;
            @(negedge clk);
            rst = 1;
            repeat (3) @(negedge clk);
            rst = 0;
            repeat (L + 4) @(negedge clk);
            if (out_frames != 0) begin
                errors = errors + 1;
                $display("FAIL 复位窗内出现陈旧输出帧 %0d", out_frames);
            end
            for (f = 0; f < FRAMES; f = f + 1) begin
                @(negedge clk);
                din = pack_in(f * BYTES);
                in_valid = 1;
            end
            @(negedge clk);
            in_valid = 0;
            wait_out(FRAMES);

            $display("  用例 %0d 完成, 累计错误 %0d", ci, errors);
        end
    endtask

    integer ci;
    initial begin
        errors = 0;
        out_frames = 0;
        rst = 1; in_valid = 0; din = 0;
        repeat (4) @(negedge clk);
        rst = 0;
        @(negedge clk);

        for (ci = 0; ci < 6; ci = ci + 1)
            run_case(ci, ci == 0);

        if (errors == 0)
            $display("TB_FFT64 PASS (逐位一致, 延迟=%0d 拍, 气泡, 中途复位, sat_cnt=%0d)",
                     L, sat_cnt);
        else
            $display("TB_FFT64 FAIL errors=%0d", errors);
        $finish;
    end
endmodule
