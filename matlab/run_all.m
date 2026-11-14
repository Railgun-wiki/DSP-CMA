function summary = run_all(mode)
%RUN_ALL 工程唯一批处理入口（AGENTS 8.3）。
%
% 用法（仓库根目录）: matlab -batch "addpath('matlab'); run_all"
% 可选 mode: 'full'（默认，完整数据与全部实验）| 'quick'（开发期缩
% 小数据量，正式交付必须使用 full）。
%
% 流程: 元数据 -> 全部单元测试 -> 卷积演示 -> 多抽头 CMA 实验 ->
% 定点模型与 RTL 向量 -> 汇总与验证状态 JSON。所有输出写入
% results/<run_id>/。

dspcma_setup();
cfg = dspcma_config_default();
if nargin < 1
    mode = 'full';
end
cfg.run_mode = mode;
rng(cfg.rng_seed, 'twister');

[run_id, out_dir] = dspcma.io.new_run_id(cfg, mode);
meta = dspcma.io.save_run_metadata(cfg, out_dir, run_id);
fprintf('== DSP-CMA run %s (%s) ==\n', run_id, mode);
fprintf('输出目录: %s\n', out_dir);
if strcmp(mode, 'quick')
    % 开发模式：缩小数据量与抽头扫描，正式实验必须用 full
    cfg.quick_scale = 0.02;   % 数据缩放比例
end

summary.run_id = run_id;
summary.out_dir = out_dir;

% ---- 1. 全部单元测试 ----
ts = run_tests([], cfg);
summary.tests = num2cell(ts.tests);   % cell of structs (JSON 数组)
summary.tests_pass = ts.n_pass;
summary.tests_total = ts.n_total;
dspcma.io.save_json(fullfile(out_dir, 'tests_summary.json'), summary);

% ---- 2. 卷积演示（用户可指定信号与滤波器） ----
n_demo = round(cfg.conv_demo.signal_len * (getfield_default(cfg, 'quick_scale', 1)));
n_demo = max(n_demo, 64);
rng(cfg.rng_seed + 1, 'twister');
xd = randn(n_demo, 1) + 1j * randn(n_demo, 1);
hd = fir_demo(cfg.conv_demo.filter_len);
stats = dspcma.convolution.conv_demo(xd, hd, cfg.conv_demo.block, out_dir);
summary.conv_demo = stats;

% ---- 3. 多抽头 CMA 实验 ----
cfg_exp = cfg;
if isfield(cfg, 'quick_scale')
    % quick 模式截取前段数据（保持整段结构）
    cfg_exp.quick_len = max(cfg.eval_len + cfg.calib_len + 8192, ...
        round(639616 * cfg.quick_scale));
end
res = dspcma.equalizer.run_tap_sweep(cfg_exp, out_dir);
summary.evm = struct( ...
    'before_pct_x', res.before.x.evm_pct, 'before_pct_y', res.before.y.evm_pct, ...
    'after_pct_x', arrayfun(@(e) e.after.x.evm_pct, res.taps), ...
    'after_pct_y', arrayfun(@(e) e.after.y.evm_pct, res.taps), ...
    'tap_lens', [res.taps.tap_len]);
summary.runtime_tapsweep_s = max(arrayfun(@(e) e.runtime_s, res.taps));
if isfield(res, 'time_baseline')
    summary.time_baseline = res.time_baseline;
end

% ---- 4. 定点模型与 RTL 测试向量 ----
fp_ok = false;
try
    fp = dspcma.fixedpoint.export_all(cfg, out_dir);
    fp_ok = true;
    summary.fixedpoint = fp;
catch fp_err
    summary.fixedpoint_error = sprintf('%s: %s', fp_err.identifier, fp_err.message);
    fprintf('!! 定点导出失败: %s\n', summary.fixedpoint_error);
end

% ---- 5. 配置快照 (F05 整改: 完整复现材料) ----
dspcma.io.save_json(fullfile(out_dir, 'config.json'), cfg);

% ---- 6. 汇总与验收门槛 (F08 整改: 证据落盘后显式抛错) ----
summary.all_tests_pass = (ts.n_pass == ts.n_total);
summary.fixedpoint_ok = fp_ok;

% 验收门槛 (AGENTS 4.4: 两路 EVM 均改善、输出有限且收敛稳定)
idx_tap = find([res.taps.tap_len] == res.tap_plot, 1);
tap_d = res.taps(idx_tap);
gates.tests = summary.all_tests_pass;
gates.fixedpoint = fp_ok;
gates.evm_improve_x = tap_d.after.x.evm_pct < res.before.x.evm_pct;
gates.evm_improve_y = tap_d.after.y.evm_pct < res.before.y.evm_pct;
gates.finite = isfield(res, 'taps') && all([res.taps.finite]);
gates.not_degenerate = tap_d.rho < 0.9;   % 工程默认: rho<0.9 视为未退化为同一路
summary.gates = gates;
summary.gates_all_pass = all(structfun(@(v) islogical(v) & v, gates));
summary.blocked = struct('vivado', 'BLOCKED: 本机无 Vivado, 仿真/Implementation 待补跑');
summary.not_run = struct('octave', 'NOT_RUN: 本机无 Octave');
dspcma.io.save_json(fullfile(out_dir, 'summary.json'), summary);
fprintf('== 完成: 测试 %d/%d, 定点导出 %d ==\n', ts.n_pass, ts.n_total, fp_ok);
fprintf('== 门槛: %d/5 PASS (Vivado=BLOCKED, Octave=NOT_RUN) ==\n', ...
    sum(structfun(@(v) islogical(v) & v, gates)));
fprintf('== 结果目录: %s ==\n', out_dir);
if ~summary.gates_all_pass
    fn = fieldnames(gates);
    vals = structfun(@(x) x, gates);
    bad = strjoin(fn(~vals), ', ');
    error('DSPCMA:run:gateFailed', '验收门槛未通过: %s — 见 %s/summary.json', ...
        bad, out_dir);
end
end

function v = getfield_default(s, name, v0)
if isfield(s, name)
    v = s.(name);
else
    v = v0;
end
end

function h = fir_demo(L)
%FIR_DEMO 演示用色散滤波器（升余弦滚降 + 相位斜率）。
% 显式 sinc 实现，不依赖 Signal Processing Toolbox（AGENTS 2）。
t = (0:L-1).' - (L - 1) / 2;
sc = ones(L, 1);
nz = t ~= 0;
sc(nz) = sin(pi * t(nz) ./ 6) ./ (pi * t(nz) / 6);
h = sc .* exp(-1j * 0.4 * t);
h = h / sqrt(sum(abs(h).^2));
end
