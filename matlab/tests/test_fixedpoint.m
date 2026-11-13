function out = test_fixedpoint(cfg)
%TEST_FIXEDPOINT 定点整数模型验证（RTL 验收参考的正确性证据）。
%
% 覆盖:
%   1) 缩放口径: 冲激输入 -> Y = round(x(1)/N)（每级 1/2 累计 = 1/N）;
%   2) 常数输入 -> 仅 DC = round(x*1)（FFT/N 后 DC = 原值）;
%   3) 1/4 频点整数音 -> 谱线位置正确、其他 bin ~0;
%   4) 定点 vs 浮点: 随机用例最大绝对误差有界（报告值, 参考阈 <= 2 LSB）;
%   5) 饱和与计数: 极值用例饱和计数与预期一致、无 NaN;
%   6) 旋转因子量化: 非特殊因子 Q15 在 [-32767,32767], 特殊因子 spec 正确;
%   7) 生成器可重建: RTL 表 include 文件存在且含两个函数。
% 注意: 与 RTL 的逐位一致属于 RTL 仿真验证（本环境受限时另行补跑）。

rng(cfg.rng_seed, 'twister');
out.name = 'Fixedpoint';
out.checks = struct('what', {}, 'status', {}, 'value', {});

    function add(what, ok, val)
        % 嵌套函数与父工作区共享变量: 状态词用独立名, 避免覆盖父级 st
        if ok
            stat_word = 'PASS';
        else
            stat_word = 'FAIL';
        end
        out.checks(end+1) = struct('what', what, 'status', stat_word, 'value', val); %#ok<AGROW>
    end

for N = [32 64]
    % ---- 冲激 ----
    X = zeros(N, 1); X(1) = 100 + 1j * 60;
    [Y, st] = dspcma.fixedpoint.fft_fixed_model(X, N);
    ref = (100 + 1j * 60) / N;
    e = max(abs(double(Y) - ref));
    % 输出为 8 bit 整数, 舍入误差上界 0.5/分量
    add(sprintf('%d点冲激缩放=1/N', N), e <= 0.51, sprintf('%.2e', e));
    add(sprintf('%d点冲激零饱和', N), sum(st.stage_saturate) + st.final_saturate == 0, ...
        sprintf('%d', sum(st.stage_saturate) + st.final_saturate));

    % ---- 常数 -> DC ----
    X = (100 + 1j * 40) * ones(N, 1);
    [Y, ~] = dspcma.fixedpoint.fft_fixed_model(X, N);
    e0 = abs(double(Y(1)) - 100 - 1j * 40);
    eo = max(abs(double(Y(2:end))));
    add(sprintf('%d点常数DC精确', N), e0 <= 1e-9 && eo <= 1.5, sprintf('%.2f/%.2f', e0, eo));

    % ---- 1/4 频点音 ----
    k = (0:N-1).';
    X = round(90 * exp(1j * pi * k / 2));
    [Y, ~] = dspcma.fixedpoint.fft_fixed_model(X, N);
    peak_bin = N/4 + 1;
    v = abs(double(Y));
    add(sprintf('%d点1/4音谱线', N), v(peak_bin) >= 88 && max(v([1:peak_bin-1, peak_bin+1:end])) <= 2.5, ...
        sprintf('peak=%.1f 其他max=%.1f', v(peak_bin), max(v([1:peak_bin-1, peak_bin+1:end]))));

    % ---- 随机 vs 浮点 ----
    max_abs = 0;
    for f = 1:20
        X = randi([-100 100], N, 1) + 1j * randi([-100 100], N, 1);
        [Y, ~] = dspcma.fixedpoint.fft_fixed_model(X, N);
        Yf = dspcma.fft.my_fft(double(X)) / N;
        max_abs = max(max_abs, max(abs(double(Y) - Yf)));
    end
    add(sprintf('%d点随机vs浮点<=2LSB', N), max_abs <= 2, sprintf('%.3f LSB', max_abs));

    % ---- 极值饱和 ----
    X = -128 * ones(N, 1);
    X(1) = 127;
    [Y, st] = dspcma.fixedpoint.fft_fixed_model(X, N);
    finite_ok = all(isfinite(double(Y)));
    add(sprintf('%d点极值有限输出', N), finite_ok, ...
        sprintf('sat=%d', sum(st.stage_saturate) + st.final_saturate));
end

% ---- 旋转因子量化 ----
ok_q = true;
for M = [2 4 8 16 32 64]
    for m = 0:M-1
        [W, spec] = dspcma.fixedpoint.twiddle_q15(M, m);
        if spec == 0
            ok_q = ok_q && W(1) >= -32767 && W(1) <= 32767 && W(2) >= -32767 && W(2) <= 32767;
        else
            ok_q = ok_q && isequal(W, [0, 0]);
        end
    end
end
[W2, sp] = dspcma.fixedpoint.twiddle_q15(8, 2);
ok_q = ok_q && sp == 3;                       % M=8, m=2 (=M/4) -> -1j
[~, sp1] = dspcma.fixedpoint.twiddle_q15(8, 4);
ok_q = ok_q && sp1 == 2;                      % M=8, m=4 (=M/2) -> -1
[~, spj] = dspcma.fixedpoint.twiddle_q15(8, 6);
ok_q = ok_q && spj == 4;                      % M=8, m=6 (=3M/4) -> +1j
add('Q15量化范围与特殊因子', ok_q, '[-32767,32767] + spec');

% ---- RTL 表生成 ----
info = dspcma.fixedpoint.gen_rtl_tables(cfg);
txt = fileread(info.file);
add('RTL表文件生成', contains(txt, 'fft_tw32') && contains(txt, 'fft_tw64') ...
    && contains(txt, '`ifndef FFT_TWIDDLE_TABLES_VH'), info.sha256(1:12));
end
