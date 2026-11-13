function out = test_convolution(cfg)
%TEST_CONVOLUTION 快速卷积验证（B03/B04 验收证据）。
%
% 覆盖: 复数随机、非整块、单点、空输入策略、单抽头、跨块边界、
% 尾部冲刷、滤波器长于信号、显式块长 B、非法参数错误标识。
% 通过条件: OLA/OLS 与直接卷积相对 L2 <= 1e-10 且长度完全一致。

rng(cfg.rng_seed, 'twister');
out.name = 'Convolution';
out.checks = struct('what', {}, 'status', {}, 'value', {});
thresh = 1e-10;

    function add(what, ok, val)
        if ok
            st = 'PASS'; v = val;
        else
            st = 'FAIL'; v = val;
        end
        out.checks(end+1) = struct('what', what, 'status', st, 'value', v); %#ok<AGROW>
    end

    function [ok, val] = compare(x, h, N, B)
        yd = dspcma.convolution.conv_direct(x, h);
        if nargin >= 4
            ya = dspcma.convolution.ola_conv(x, h, N, B);
            yo = dspcma.convolution.ols_conv(x, h, N, B);
        else
            ya = dspcma.convolution.ola_conv(x, h, N);
            yo = dspcma.convolution.ols_conv(x, h, N);
        end
        ok = (numel(ya) == numel(yd)) && (numel(yo) == numel(yd)) ...
            && dspcma.metrics.rel_l2(ya, yd) <= 1e-10 ...
            && dspcma.metrics.rel_l2(yo, yd) <= 1e-10;
        val = sprintf('len=%d/%d errA=%.1e errS=%.1e', numel(ya), numel(yd), ...
            dspcma.metrics.rel_l2(ya, yd), dspcma.metrics.rel_l2(yo, yd));
    end

% ---- 复数随机、多种长度组合 ----
cases = {64, 33, 64; 256, 33, 256; 1000, 33, 128; 777, 17, 64; 65, 65, 128};
for c = 1:size(cases, 1)
    Lx = cases{c, 1}; Lh = cases{c, 2}; N = cases{c, 3};
    x = randn(Lx, 1) + 1j * randn(Lx, 1);
    h = randn(Lh, 1) + 1j * randn(Lh, 1);
    [ok, val] = compare(x, h, N);
    add(sprintf('随机 %dx%d N=%d', Lx, Lh, N), ok, val);
end

% ---- 非整块 + 显式块长 B（含 B < L-1 的重叠保留历史区拼接） ----
x = randn(500, 1) + 1j * randn(500, 1);
h = randn(33, 1) + 1j * randn(33, 1);
[ok, val] = compare(x, h, 64, 7);
add('非整块 B=7 < L-1', ok, val);
[ok, val] = compare(x, h, 256, 100);
add('非整块 B=100', ok, val);
[ok, val] = compare(x, h, 64, 1);
add('单点块 B=1', ok, val);

% ---- 单点信号 / 单点滤波器 / 单抽头 ----
[ok, val] = compare(randn(1, 1) + 1j, h, 64);
add('单点信号', ok, val);
h1 = 0.5 - 0.25j;
[ok, val] = compare(x, h1, 128);
add('单抽头滤波器', ok, val);
[ok, val] = compare(x, [1; zeros(30, 1); 2j], 64);
add('稀疏抽头(跨块)', ok, val);

% ---- 滤波器长于信号 ----
xs = randn(10, 1) + 1j * randn(10, 1);
[ok, val] = compare(xs, h, 128);
add('滤波器长于信号', ok, val);

% ---- 尾部冲刷: 输出长度必须为 Lx+Lh-1 且末段正确 ----
Lx = 97; Lh = 33; N = 128;
x = randn(Lx, 1) + 1j * randn(Lx, 1);
h = randn(Lh, 1) + 1j * randn(Lh, 1);
yd = dspcma.convolution.conv_direct(x, h);
ya = dspcma.convolution.ola_conv(x, h, N);
yo = dspcma.convolution.ols_conv(x, h, N);
len_ok = numel(ya) == Lx + Lh - 1 && numel(yo) == Lx + Lh - 1;
tail_ok = max(abs(ya(Lx:end) - yd(Lx:end))) < 1e-8 && max(abs(yo(Lx:end) - yd(Lx:end))) < 1e-8;
add('尾部冲刷长度', len_ok, sprintf('%d/%d', numel(ya), Lx + Lh - 1));
add('尾部冲刷新值', tail_ok, sprintf('%.1e', max(abs(yo(Lx:end) - yd(Lx:end)))));

% ---- 实数输入 ----
[ok, val] = compare(randn(300, 1), randn(17, 1), 64);
add('实数输入', ok, val);

% ---- 空输入策略: 统一报错 ----
err_ok = check_err(@() dspcma.convolution.conv_direct([], h));
err_ok = err_ok && check_err(@() dspcma.convolution.ola_conv([], h, 64));
err_ok = err_ok && check_err(@() dspcma.convolution.ols_conv(x, [], 64));
add('空输入报错', err_ok, 'DSPCMA:conv:*');

% ---- 非法 N / 违反 N>=B+L-1 报错 ----
err_ok = check_err(@() dspcma.convolution.ola_conv(x, h, 60));
err_ok = err_ok && check_err(@() dspcma.convolution.ols_conv(x, h, 64, 50));
add('非法N/违反约束报错', err_ok, 'DSPCMA:conv:badN');

% ---- 演示入口可用（信号与滤波器由使用者指定） ----
stats = dspcma.convolution.conv_demo(x, h, 128);
add('conv_demo 指标', stats.err_ols <= thresh && stats.err_ola <= thresh, ...
    sprintf('errO=%.1e errS=%.1e', stats.err_ola, stats.err_ols));

    function ok = check_err(fn)
        ok = false;
        try
            fn();
        catch err
            ok = startsWith(err.identifier, 'DSPCMA:conv:');
        end
    end
end
