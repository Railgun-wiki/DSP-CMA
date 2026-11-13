function out = test_fft(cfg)
%TEST_FFT 自编 FFT/IFFT 正确性验证（B01 验收证据）。
%
% 对照 oracle 为手写 O(N^2) 的 my_dft（不使用内置 FFT）。
% 覆盖: 32/128 点强制验收 + 64/256 支持长度; 冲激、常数、单频、复数
% 随机; 往返 IFFT; 行/列形状; 非法长度与非法输入的错误标识。
% 通过条件: 相对 L2 误差 <= 1e-10（零参考用绝对误差）。

rng(cfg.rng_seed, 'twister');
out.name = 'FFT/IFFT';
out.checks = struct('what', {}, 'status', {}, 'value', {});
thresh = 1e-10;

% ---- 冲激: x = e_0 -> X 全 1 ----
for N = [32 64 128 256]
    x = zeros(N, 1); x(1) = 1;
    X = dspcma.fft.my_fft(x);
    e = dspcma.metrics.rel_l2(X, ones(N, 1));
    add(sprintf('%d点冲激->全1', N), e <= thresh, sprintf('%.3e', e));
end

% ---- 冲激在末位 ----
for N = [32 128]
    x = zeros(N, 1); x(N) = 1;
    X = dspcma.fft.my_fft(x);
    w = exp(-1j*2*pi*(0:N-1).'*((N-1)/N));
    e = dspcma.metrics.rel_l2(X, w);
    add(sprintf('%d点末位冲激', N), e <= thresh, sprintf('%.3e', e));
end

% ---- 常数: X 仅 DC = N ----
for N = [32 128]
    x = (3 + 4j) * ones(N, 1);
    X = dspcma.fft.my_fft(x);
    ref = zeros(N, 1); ref(1) = N * (3 + 4j);
    e = dspcma.metrics.rel_l2(X, ref);
    add(sprintf('%d点常数->DC', N), e <= thresh, sprintf('%.3e', e));
end

% ---- 单频: x[n] = exp(1j*2*pi*k0*n/N) -> X = N*e_{k0} ----
for N = [32 128]
    for k0 = [0, floor(N/4), floor(N/3), N-1]
        n = (0:N-1).';
        x = exp(1j*2*pi*k0*n/N);
        X = dspcma.fft.my_fft(x);
        ref = zeros(N, 1); ref(k0+1) = N;
        e = dspcma.metrics.rel_l2(X, ref);
        add(sprintf('%d点单频bin%d', N, k0), e <= thresh, sprintf('%.3e', e));
    end
end

% ---- 复数随机 vs my_dft ----
for N = [32 64 128 256]
    x = (randn(N, 1) + 1j*randn(N, 1));
    X = dspcma.fft.my_fft(x);
    e = dspcma.metrics.rel_l2(X, dspcma.fft.my_dft(x));
    add(sprintf('%d点随机vsDFT', N), e <= thresh, sprintf('%.3e', e));
end

% ---- IFFT 往返 ----
for N = [32 64 128 256]
    x = (randn(N, 1) + 1j*randn(N, 1));
    xr = dspcma.fft.my_ifft(dspcma.fft.my_fft(x));
    e = dspcma.metrics.rel_l2(xr, x);
    add(sprintf('%d点FFT/IFFT往返', N), e <= thresh, sprintf('%.3e', e));
end

% ---- IFFT 定义直验: x[n] = sum(X*exp(+j..))/N ----
N = 128;
X = (randn(N, 1) + 1j*randn(N, 1));
k = (0:N-1).'; n = (0:N-1).';
ref = (exp(1j*2*pi*(k*n.')/N) * X) / N;
e = dspcma.metrics.rel_l2(dspcma.fft.my_ifft(X), ref);
add('IFFT定义直验128', e <= thresh, sprintf('%.3e', e));

% ---- 形状契约: 行向量入 -> 行向量出; 列入 -> 列出 ----
xrow = (randn(1, 32) + 1j*randn(1, 32));
Xrow = dspcma.fft.my_fft(xrow);
add('行向量形状保持', isequal(size(Xrow), [1 32]) && ...
    isequal(size(dspcma.fft.my_ifft(Xrow)), [1 32]), '1x32');
xcol = (randn(32, 1) + 1j*randn(32, 1));
add('列向量形状保持', isequal(size(dspcma.fft.my_fft(xcol)), [32 1]), '32x1');

% ---- 级结构映射与逐级一致性（模拟硬件并行结构） ----
for N = [32 128]
    mp = dspcma.fft.fft_stage_map(N);
    ok_struct = (numel(mp) == log2(N));
    rowsum = 0;
    for s = 1:numel(mp)
        rowsum = rowsum + size(mp(s).pairs, 1);
        ok_struct = ok_struct && (mp(s).M == 2^s) ...
            && all(mp(s).pairs(:,1) < mp(s).pairs(:,2)) ...
            && all(mp(s).pairs(:,2) - mp(s).pairs(:,1) == 2^(s-1));
    end
    ok_struct = ok_struct && (rowsum == N/2 * log2(N));
    add(sprintf('%d点级结构映射', N), ok_struct, ...
        sprintf('%d级%d蝶形', numel(mp), rowsum));
end

% ---- 非法输入的错误标识 ----
err_ok = check_error_id(@() dspcma.fft.my_fft((1:48).'));
err_ok = err_ok && check_error_id(@() dspcma.fft.my_fft([]));
err_ok = err_ok && check_error_id(@() dspcma.fft.my_fft([1 NaN 3 4].'));
err_ok = err_ok && check_error_id(@() dspcma.fft.my_ifft((1:12).'));
add('非法输入错误标识', err_ok, 'DSPCMA:fft:*');

% ---- 自检: 本测试源码未调用内置 fft/ifft（排除注释行） ----
src = fileread([mfilename('fullpath'), '.m']);
lines = regexp(src, '\r?\n', 'split');
code_lines = lines(~startsWith(strtrim(lines), '%'));
clean = strjoin(code_lines, '\n');
no_builtin = isempty(regexp(clean, '\bfft\(', 'once')) && ...
             isempty(regexp(clean, '\bifft\(', 'once')) && ...
             isempty(regexp(clean, '\bdftmtx\(', 'once'));
add('测试未用内置FFT', no_builtin, 'grep');

    function add(what, ok, val)
        if ok
            st = 'PASS';
        else
            st = 'FAIL';
        end
        out.checks(end+1) = struct('what', what, 'status', st, 'value', val); %#ok<AGROW>
    end

    function ok = check_error_id(fn)
        ok = false;
        try
            fn();
        catch err
            ok = startsWith(err.identifier, 'DSPCMA:fft:');
        end
    end
end
