function stats = conv_demo(x, h, N, out_dir)
%CONV_DEMO 快速卷积演示（B03：信号与滤波器由使用者指定）。
%
% 对指定信号 x 与滤波器 h，用重叠相加 (ola_conv) 与重叠保留
% (ols_conv) 计算完整线性卷积，并与直接卷积 conv_direct 对照；
% 可选保存对照星座/波形图与指标 JSON。
%
% 输入:
%   x, h    -- 使用者指定的信号与滤波器（复数向量）。
%   N       -- FFT 长度（2 的幂，须满足 N >= B+L-1）。
%   out_dir -- 可选；给定则保存 <out_dir>/conv_demo.png 与
%              <out_dir>/metrics_conv_demo.json。
% 输出:
%   stats   -- 结构体: 信号/滤波器长度、FFT 长度、两种算法与直接
%              卷积的相对 L2 误差、各算法耗时（秒）。

stats.x_len = numel(x);
stats.h_len = numel(h);
stats.N = N;
stats.B_default = N - numel(h) + 1;

t0 = tic;
y_direct = dspcma.convolution.conv_direct(x, h);
stats.t_direct = toc(t0);

t0 = tic;
y_ola = dspcma.convolution.ola_conv(x, h, N);
stats.t_ola = toc(t0);

t0 = tic;
y_ols = dspcma.convolution.ols_conv(x, h, N);
stats.t_ols = toc(t0);

stats.len_match = numel(y_ola) == numel(y_direct) && numel(y_ols) == numel(y_direct);
stats.err_ola = dspcma.metrics.rel_l2(y_ola, y_direct);
stats.err_ols = dspcma.metrics.rel_l2(y_ols, y_direct);

if nargin >= 4 && ~isempty(out_dir)
    fig = figure('Visible', 'off', 'Position', [100 100 900 620]);
    subplot(2, 1, 1);
    plot(real(y_direct), 'b'); hold on;
    plot(real(y_ols), 'r--');
    legend('直接卷积 Re', 'OLS Re'); grid on;
    xlabel('n'); ylabel('幅度');
    title(sprintf('快速卷积 vs 直接卷积 (N=%d, |x|=%d, |h|=%d)', N, numel(x), numel(h)));
    subplot(2, 1, 2);
    semilogy(abs(y_direct - y_ols) + eps, 'b'); hold on;
    semilogy(abs(y_direct - y_ola) + eps, 'r--');
    legend('|直接-OLS|', '|直接-OLA|'); grid on;
    xlabel('n'); ylabel('绝对误差');
    dspcma.io.save_figure(fig, fullfile(out_dir, 'conv_demo.png'));
    dspcma.io.save_json(fullfile(out_dir, 'metrics_conv_demo.json'), stats);
end
end
