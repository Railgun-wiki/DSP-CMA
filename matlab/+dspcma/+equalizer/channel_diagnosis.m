function res = channel_diagnosis(cfg, zx, zy, out_dir)
%CHANNEL_DIAGNOSIS 信道相位特性诊断（均衡结果解释的证据链）。
%
% 背景: 实验数据显示均衡后星座为等模圆环、相位逐符号均匀随机。
% 本函数固化诊断证据:
%   1) 输入与均衡输出的 4QAM 相位相干度 |E[z^4]|/E[|z|^4]
%      （理想 4QAM 为 1；逐符号均匀相位为 0）;
%   2) 逐样本折叠相位（mod pi/2 折叠）对时间的散点图——区分频偏
%      （线性漂移）、慢随机游走（块状漂移）与逐符号独立均匀随机;
%   3) 折叠相位直方图与紧致度统计;
%   4) 相位残差的自相关长度（z^4 滞后自相关）;
%   5) 等模圆环 + 均匀相位的解析 DD-EVM 下限（评估口径一致）。
% 诊断结论: 相位随机化存在于原始数据（相干度~0.01），CMA（对相位盲）
% 无法也无需处理；残余 DD-EVM 由该特性决定。
%
% 输入 zx/zy 为两偏振的均衡输出（全长）；rx 由 cfg 重新载入。
% F04 整改: 新增 z^4 滞后相关 (含打乱对照, 证据时间结构) 与两偏振
% ±maxlag 延迟搜索互相关 (零延迟值不足以证明独立解复用)。

if nargin < 3
    out_dir = tempdir;
end
[rx, ~, ~] = dspcma.io.load_tdtr(cfg);

res.coherence_raw = abs(mean(rx.^4)) / mean(abs(rx).^4);
if nargin >= 2 && ~isempty(zx)
    res.coherence_eq = abs(mean(zx.^4)) / mean(abs(zx).^4);
else
    res.coherence_eq = [];
end

ecos = sin(pi/4) / (pi/4);
res.ring_floor_evm_pct = 100 * sqrt((4 - 4 * ecos) / 2);

% 模值收敛统计（CMA 目标 R=2）
res.modulus_sq_mean = mean(abs(zx).^2);
res.modulus_sq_std = std(abs(zx).^2);

% ---- z^4 滞后自相关: 原序列 vs 打乱对照 (时间结构证据, F04 整改)。
% 若逐符号独立均匀相位成立, 滞后相关应接近打乱对照; 显著高于对照
% 说明存在时间结构, 信道模型需另行认定 (不在此指定具体模型)。
rs = RandStream('twister', 'Seed', 20261114);   % 局部流, 不污染全局
wz = zx .^ 4;
wz = wz - mean(wz);
lags_z4 = [1 64 256];
res.z4_lags = lags_z4;
res.z4_lag_corr = zeros(1, numel(lags_z4));
res.z4_lag_corr_shuffled = zeros(1, numel(lags_z4));
wperm = wz(randperm(rs, numel(wz)));
for k = 1:numel(lags_z4)
    L = lags_z4(k);
    res.z4_lag_corr(k) = abs(mean(wz(1:end-L) .* conj(wz(1+L:end)))) / mean(abs(wz).^2);
    res.z4_lag_corr_shuffled(k) = abs(mean(wperm(1:end-L) .* conj(wperm(1+L:end)))) / mean(abs(wperm).^2);
end

% ---- 两偏振互相关的延迟搜索 (±maxlag 内最大值, F04 整改):
% 零延迟相关小不能证明两路独立, 需检查是否存在对齐后的延迟副本。
rng(20261114, 'twister');
cal_y = dspcma.metrics.calibrate_4qam(zy);
sy_ = zy * exp(-1j * cal_y.phase) / cal_y.gain;
cal_x = dspcma.metrics.calibrate_4qam(zx);
sx_ = zx * exp(-1j * cal_x.phase) / cal_x.gain;
maxlag = 64;
nl = 2 * maxlag + 1;
cc = zeros(1, nl);
for L = -maxlag:maxlag
    if L < 0
        a = sx_(-L+1:end);
        b = sy_(1:end+L);
    else
        a = sx_(1:end-L);
        b = sy_(L+1:end);
    end
    cc(L + maxlag + 1) = abs(mean(a .* conj(b))) / sqrt(mean(abs(a).^2) * mean(abs(b).^2));
end
res.xcorr_maxlag = maxlag;
res.xcorr_max = max(cc);
res.xcorr_lag_at_max = find(cc == max(cc), 1) - maxlag - 1;
res.xcorr_zero = cc(maxlag + 1);

% 图: 折叠相位散点 + 直方图
cal = dspcma.metrics.calibrate_4qam(zx);
s = zx * exp(-1j * cal.phase) / cal.gain;
ang = angle(s);
fold = mod(ang + pi/4, pi/2) - pi/4;
res.folded_phase_std = std(fold);
res.tight_015 = mean(abs(fold) < 0.15);
res.tight_030 = mean(abs(fold) < 0.30);

fig = figure('Visible', 'off', 'Position', [80 80 1150 700]);
subplot(2, 2, [1 2]);
n1 = round(0.15 * numel(zx));
idx1 = n1:min(n1 + 49999, numel(zx));
plot(idx1, fold(idx1), '.', 'MarkerSize', 1);
grid on; ylabel('折叠相位 / rad'); xlabel('样本');
title(sprintf('逐样本折叠相位 (%d..%d)：无漂移/无块结构 => 逐符号均匀随机', idx1(1), idx1(end)));
ylim([-0.8 0.8]);
subplot(2, 2, 3);
histogram(fold, 180);
grid on; xlabel('折叠相位 / rad'); ylabel('样本数');
title(sprintf('折叠相位直方图 (std=%.3f, 均匀分布一致)', res.folded_phase_std));
subplot(2, 2, 4);
histogram(abs(zx(idx1)).^2, 120);
grid on; xlabel('|z|^2'); ylabel('样本数');
title(sprintf('|z|^2 分布 (mean=%.2f, CMA 目标 R=2)', res.modulus_sq_mean));
dspcma.io.save_figure(fig, fullfile(out_dir, 'phase_diagnosis.png'));
dspcma.io.save_json(fullfile(out_dir, 'metrics_phase_diagnosis.json'), res);
end
