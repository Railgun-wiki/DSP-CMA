function res = run_tap_sweep(cfg, out_dir)
%RUN_TAP_SWEEP 完整数据上的多抽头频域 CMA 实验（B05/B06 主证据）。
%
% 对 cfg.tap_sweep 中每个抽头长度:
%   * 频域 CMA（cma_freq_run）全量运行;
%   * 独立校准段（评估窗之前 cfg.calib_len 点）估计 4QAM 增益/相位并
%     冻结，应用于精确 cfg.eval_len 点尾部评估窗;
%   * 均衡前后 DD-EVM（百分数/dB）、CMA 收敛代价、耗时、有效样本数;
%   * 退化检查（两偏振复相关系数）、有限性检查;
%   * 默认抽头额外跑时域基线全长对照（报告全长指标差异）。
% 评估窗为末尾精确 eval_len 点（替代参考脚本 end-131072:end 的
% 131073 点）。产出星座图、收敛曲线、tapsweep 指标 JSON。
% 指标 JSON 不包含逐点样本（只存标量指标与窗口定义）。

if nargin < 2
    out_dir = tempdir;
end
[rx, ry, dmeta] = dspcma.io.load_tdtr(cfg);
res.data = dmeta;
res.n_total = numel(rx);
if isfield(cfg, 'quick_len') && ~isempty(cfg.quick_len)
    n_use = min(cfg.quick_len, res.n_total);
    rx = rx(1:n_use);
    ry = ry(1:n_use);
    res.n_total = n_use;
    res.quick = true;
end

% ---- 窗口定义（1-based，冻结口径） ----
eval_len = cfg.eval_len;
calib_len = cfg.calib_len;
eval_start = res.n_total - eval_len + 1;
calib_start = eval_start - calib_len;
if calib_start < 1
    error('DSPCMA:equalizer:tooShort', '数据不足校准段+评估窗');
end
ev = eval_start:res.n_total;
ca = calib_start:eval_start - 1;
res.eval_window = [ev(1), ev(end)];
res.calib_window = [ca(1), ca(end)];
res.eval_len = eval_len;
res.calib_len = calib_len;

% ---- 均衡前 DD-EVM（同窗同口径） ----
res.before = pol_metrics(rx, ry, ca, ev, cfg.ideal_4qam);
res.before.rms_eval = [sqrt(mean(abs(rx(ev)).^2)), sqrt(mean(abs(ry(ev)).^2))];
% 数据 4QAM 相位相干度（|E[x^4]|/E[|x|^4]）：接近 0 表示数据逐符号
% 相位均匀随机（证据: 见报告信道诊断节）
res.data.coherence_raw_x = abs(mean(rx.^4)) / mean(abs(rx).^4);
res.data.coherence_raw_y = abs(mean(ry.^4)) / mean(abs(ry).^4);
% 等模圆环 + 均匀相位的解析 DD-EVM 下限（相位随机化贡献的不可约项）:
% EVM^2 = (4 - 4*E[cos dθ])/2, E[cos dθ] = sin(pi/4)/(pi/4)
ecos = sin(pi/4) / (pi/4);
res.ring_floor_evm_pct = 100 * sqrt((4 - 4 * ecos) / 2);

% ---- 各抽头长度 ----
res.taps = struct('tap_len', {}, 'N_fft', {}, 'seg_num', {}, 'clk_num', {}, ...
    'dropped', {}, 'runtime_s', {}, 'after', {}, 'calib', {}, 'rho', {}, ...
    'finite', {}, 'cost_last', {}, 'final_tap_rms', {}, ...
    'modulus_sq_x', {}, 'modulus_sq_y', {}, ...
    'excess_evm_pct_x', {}, 'excess_evm_pct_y', {});
res.cost = struct();
if numel(cfg.tap_sweep) >= 2
    tap_plot = cfg.tap_sweep(2);     % 默认 33（配置顺序 17/33/65）
else
    tap_plot = cfg.tap_sweep(1);
end
res.tap_plot = tap_plot;

for ti = 1:numel(cfg.tap_sweep)
    t = cfg.tap_sweep(ti);
    cfg_t = cfg;
    cfg_t.tap_len = t;
    t0 = tic;
    runF = dspcma.equalizer.cma_freq_run(rx, ry, cfg_t);
    t_run = toc(t0);

    after = pol_metrics(runF.zx, runF.zy, ca, ev, cfg.ideal_4qam);
    cost = dspcma.metrics.cma_cost(runF.errx, runF.erry, cfg.seg_len, cfg.par_num);
    finite = all(isfinite(runF.zx)) && all(isfinite(runF.zy));
    rho = dspcma.metrics.pol_degeneracy(after.x.s, after.y.s);

    res.taps(ti) = orderfields(struct( ...
        'tap_len', t, 'N_fft', runF.N_fft, 'seg_num', runF.seg_num, ...
        'clk_num', runF.clk_num, 'dropped', runF.dropped, 'runtime_s', t_run, ...
        'after', strip_samples(after), ...
        'calib', struct('x', after.x.cal, 'y', after.y.cal), ...
        'rho', rho, 'finite', finite, 'cost_last', cost.cost_total(end), ...
        'final_tap_rms', sqrt(mean(abs(runF.final.xx).^2)), ...
        'modulus_sq_x', mean(abs(runF.zx(ev)).^2), ...
        'modulus_sq_y', mean(abs(runF.zy(ev)).^2), ...
        'excess_evm_pct_x', after.x.evm_pct - res.ring_floor_evm_pct, ...
        'excess_evm_pct_y', after.y.evm_pct - res.ring_floor_evm_pct));
    res.cost.(sprintf('tap%d', t)) = cost;

    % 时域基线全长对照（仅绘图默认抽头，报告全长差异）
    if t == tap_plot
        t0 = tic;
        runT = dspcma.equalizer.cma_time_run(rx, ry, cfg_t);
        t_time = toc(t0);
        afterT = pol_metrics(runT.zx, runT.zy, ca, ev, cfg.ideal_4qam);
        res.time_baseline.runtime_s = t_time;
        res.time_baseline.tap_rel_diff = max(abs(runT.final.xx - runF.final.xx)) / max(abs(runT.final.xx));
        res.time_baseline.output_rel_diff = dspcma.metrics.rel_l2(runF.zx, runT.zx);
        res.time_baseline.evm_pct_x = afterT.x.evm_pct;
        res.time_baseline.evm_pct_y = afterT.y.evm_pct;
    end

    % ---- 星座图（确定性采样，一致坐标范围） ----
    stride = max(1, floor(eval_len / 20000));
    idx_local = 1:stride:numel(ev);
    samp = ev(idx_local);
    lim = 2.5;
    if t == tap_plot
        fig = figure('Visible', 'off', 'Position', [80 80 980 460]);
        subplot(1, 2, 1);
        bx = res.before.x.s(idx_local);
        plot(real(bx), imag(bx), '.', 'Color', [0.85 0.2 0.2], 'MarkerSize', 2);
        axis equal; axis([-lim lim -lim lim]); grid on;
        title(sprintf('X 偏振均衡前 (DD-EVM=%.1f%%)', res.before.x.evm_pct));
        xlabel('I'); ylabel('Q');
        subplot(1, 2, 2);
        by = res.before.y.s(idx_local);
        plot(real(by), imag(by), '.', 'Color', [0.2 0.3 0.85], 'MarkerSize', 2);
        axis equal; axis([-lim lim -lim lim]); grid on;
        title(sprintf('Y 偏振均衡前 (DD-EVM=%.1f%%)', res.before.y.evm_pct));
        xlabel('I'); ylabel('Q');
        sgtitle(sprintf('均衡前星座（校准后, %d 点采样）', numel(samp)));
        dspcma.io.save_figure(fig, fullfile(out_dir, 'constellation_before.png'));

        fig = figure('Visible', 'off', 'Position', [80 80 980 460]);
        sx = after.x.s(idx_local);
        sy = after.y.s(idx_local);
        subplot(1, 2, 1);
        plot(real(sx), imag(sx), '.', 'Color', [0.85 0.2 0.2], 'MarkerSize', 2);
        axis equal; axis([-lim lim -lim lim]); grid on;
        title(sprintf('X 偏振均衡后 tap=%d (DD-EVM=%.2f%%)', t, after.x.evm_pct));
        xlabel('I'); ylabel('Q');
        subplot(1, 2, 2);
        plot(real(sy), imag(sy), '.', 'Color', [0.2 0.3 0.85], 'MarkerSize', 2);
        axis equal; axis([-lim lim -lim lim]); grid on;
        title(sprintf('Y 偏振均衡后 tap=%d (DD-EVM=%.2f%%)', t, after.y.evm_pct));
        xlabel('I'); ylabel('Q');
        sgtitle(sprintf('均衡后星座 tap=%d（校准后, %d 点采样）', t, numel(samp)));
        dspcma.io.save_figure(fig, fullfile(out_dir, sprintf('constellation_tap%d.png', t)));
    end
end

% ---- 收敛曲线 ----
fig = figure('Visible', 'off', 'Position', [80 80 880 460]);
leg = {};
hold on;
for ti = 1:numel(cfg.tap_sweep)
    t = cfg.tap_sweep(ti);
    c = res.cost.(sprintf('tap%d', t)).cost_total;
    semilogy(c, 'LineWidth', 1);
    leg{end+1} = sprintf('tap=%d', t); %#ok<AGROW>
end
grid on;
xlabel('时钟周期（4 段/时钟）'); ylabel('CMA 代价 e^2 均值（两偏振和）');
title('CMA 收敛曲线（全量数据）');
legend(leg, 'Location', 'northeast');
dspcma.io.save_figure(fig, fullfile(out_dir, 'convergence.png'));

% ---- 抽头对比柱状图 ----
fig = figure('Visible', 'off', 'Position', [80 80 880 460]);
after_pct_x = arrayfun(@(e) e.after.x.evm_pct, res.taps);
after_pct_y = arrayfun(@(e) e.after.y.evm_pct, res.taps);
b = bar([after_pct_x(:), after_pct_y(:)]);
b(1).FaceColor = [0.85 0.33 0.25];
b(2).FaceColor = [0.25 0.45 0.85];
xticklabels(arrayfun(@(t) sprintf('tap=%d', t), cfg.tap_sweep, 'UniformOutput', false));
hold on;
yline(res.before.x.evm_pct, '--', sprintf('均衡前 X %.1f%%', res.before.x.evm_pct), 'Color', [0.6 0.2 0.2]);
yline(res.before.y.evm_pct, '--', sprintf('均衡前 Y %.1f%%', res.before.y.evm_pct), 'Color', [0.2 0.3 0.6]);
grid on;
ylabel('DD-EVM (%)');
title('不同抽头长度均衡后 DD-EVM（评估窗 131072 点）');
dspcma.io.save_figure(fig, fullfile(out_dir, 'tapsweep_evm.png'));

% ---- 指标 JSON（仅标量，不含逐点样本） ----
res.before = strip_samples(res.before);
if isfield(res, 'time_baseline')
    res.time_baseline.cost = [];
end
dspcma.io.save_json(fullfile(out_dir, 'metrics_tapsweep.json'), res);
end

% ================= 内部函数 =================

function m = pol_metrics(zx, zy, ca, ev, ideal)
%POL_METRICS 单组输出的两偏振 DD-EVM（校准段 ca 冻结参数，评估窗 ev）。
m.x = one_pol(zx, ca, ev, ideal);
m.y = one_pol(zy, ca, ev, ideal);
end

function m = one_pol(z, ca, ev, ideal)
cal = dspcma.metrics.calibrate_4qam(z(ca), ideal);
r = dspcma.metrics.dd_evm(z(ev), cal, ideal);
m.evmm = r.evmm;
m.evm_pct = r.evm_pct;
m.evm_db = r.evm_db;
m.n = r.n;
m.cal = struct('phase', cal.phase, 'gain', cal.gain);
m.s = r.s;   % 供绘图；JSON 导出前经 strip_samples 去除
end

function m = strip_samples(m)
if isfield(m, 'x') && isfield(m.x, 's')
    m.x = rmfield(m.x, {'s'});
    m.y = rmfield(m.y, {'s'});
end
end
