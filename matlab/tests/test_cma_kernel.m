function out = test_cma_kernel(cfg)
%TEST_CMA_KERNEL 频域 CMA 内核验证（B05 验收证据，AGENTS 第 7 节）。
%
% 与独立时域实现 cma_time_run（CMA_reference.m 的函数化移植）对照:
%   1) 固定抽头输出（随机复数抽头、step=0）vs 直接卷积有效区;
%   2) 单次更新（1 时钟 = 4 段）梯度与抽头快照;
%   3) 多次更新短程运行（20 时钟）输出与各时钟抽头;
%   4) 更新时序: 前 4 段用初始抽头，第 5 段起用首次更新抽头;
%   5) 非整组尾部: 不足 4 段的梯度丢弃，最终抽头=最后整组抽头;
%   6) clk_dly ~= 1 拒绝。
% 通过条件: 短程稳定测试相对误差 <= 1e-8（同时报告绝对误差）。

rng(cfg.rng_seed, 'twister');
out.name = 'CMA kernel';
out.checks = struct('what', {}, 'status', {}, 'value', {});
thresh = 1e-8;

    function add(what, ok, val)
        if ok
            st = 'PASS';
        else
            st = 'FAIL';
        end
        out.checks(end+1) = struct('what', what, 'status', st, 'value', val); %#ok<AGROW>
    end

    function [sx, sy] = gen_4qam(n)
        b1 = randi([0 3], n, 1);
        sx = 2 * (bitand(b1, 2) > 0) - 1 + 1j * (2 * bitand(b1, 1) - 1);
        b2 = randi([0 3], n, 1);
        sy = 2 * (bitand(b2, 2) > 0) - 1 + 1j * (2 * bitand(b2, 1) - 1);
    end

    function [x, y] = channel(sx, sy, Lc)
        % 2x2 蝶形 FIR 信道（含偏振耦合）
        cxx = randn(Lc, 1) + 1j * randn(Lc, 1);
        cyy = randn(Lc, 1) + 1j * randn(Lc, 1);
        cxy = 0.3 * (randn(Lc, 1) + 1j * randn(Lc, 1));
        cyx = 0.3 * (randn(Lc, 1) + 1j * randn(Lc, 1));
        x = dspcma.convolution.conv_direct(sx, cxx) + dspcma.convolution.conv_direct(sy, cxy);
        y = dspcma.convolution.conv_direct(sy, cyy) + dspcma.convolution.conv_direct(sx, cyx);
        s = max(max(abs(x)), max(abs(y)));
        x = x(1:numel(sx)) / s * 1.2;
        y = y(1:numel(sx)) / s * 1.2;
    end

    function e = rel(a, b)
        e = dspcma.metrics.rel_l2(a, b);
    end

h_init_default = zeros(cfg.tap_len, 1);
h_init_default((cfg.tap_len + 1) / 2) = 1;

% ---- 1) 固定抽头输出 vs 直接卷积 ----
tap_len = cfg.tap_len;
hxx = randn(tap_len, 1) + 1j * randn(tap_len, 1);
hxy = randn(tap_len, 1) + 1j * randn(tap_len, 1);
hyx = randn(tap_len, 1) + 1j * randn(tap_len, 1);
hyy = randn(tap_len, 1) + 1j * randn(tap_len, 1);
cfg0 = cfg;
cfg0.step = 0;
cfg0.hxx_init = hxx; cfg0.hxy_init = hxy;
cfg0.hyx_init = hyx; cfg0.hyy_init = hyy;
[x, y] = channel(gen_4qam(640), gen_4qam(640), 5);
ct = dspcma.equalizer.cma_time_run(x, y, cfg0);
cf = dspcma.equalizer.cma_freq_run(x, y, cfg0);
zx_ref = dspcma.convolution.conv_direct(x, hxx) + dspcma.convolution.conv_direct(y, hxy);
zy_ref = dspcma.convolution.conv_direct(y, hyy) + dspcma.convolution.conv_direct(x, hyx);
e_tx = rel(ct.zx, zx_ref(1:640));
e_ty = rel(ct.zy, zy_ref(1:640));
e_fx = rel(cf.zx, zx_ref(1:640));
e_fy = rel(cf.zy, zy_ref(1:640));
add('固定抽头:时域vs直接卷积', e_tx <= 1e-10 && e_ty <= 1e-10, ...
    sprintf('%.2e/%.2e', e_tx, e_ty));
add('固定抽头:频域vs直接卷积', e_fx <= 1e-10 && e_fy <= 1e-10, ...
    sprintf('%.2e/%.2e', e_fx, e_fy));
add('固定抽头:频vs时', rel(cf.zx, ct.zx) <= thresh && rel(cf.zy, ct.zy) <= thresh, ...
    sprintf('%.2e/%.2e', rel(cf.zx, ct.zx), rel(cf.zy, ct.zy)));

% ---- 2) 单次更新（1 时钟 = 4 段 = 128 样本） ----
cfg1 = cfg;
cfg1.record_taps = true;
n1 = 4 * cfg.seg_len;
[xt, yt] = channel(gen_4qam(n1), gen_4qam(n1), 5);
ct = dspcma.equalizer.cma_time_run(xt, yt, cfg1);
cf = dspcma.equalizer.cma_freq_run(xt, yt, cfg1);
e_z = max(rel(cf.zx, ct.zx), rel(cf.zy, ct.zy));
e_t = max([rel(cf.final.xx, ct.final.xx), rel(cf.final.yy, ct.final.yy), ...
           rel(cf.final.xy, ct.final.xy), rel(cf.final.yx, ct.final.yx)]);
a_z = max(max(abs(cf.zx - ct.zx)), max(abs(cf.zy - ct.zy)));
a_t = max(max(abs(cf.final.xx - ct.final.xx)));
add('单次更新:输出一致', e_z <= thresh, sprintf('rel=%.2e abs=%.2e', e_z, a_z));
add('单次更新:抽头一致', e_t <= thresh, sprintf('rel=%.2e abs=%.2e', e_t, a_t));
% 1 时钟整除时 final=更新前快照（与参考 xx(:,clk_num) 一致）；用 5 段
% （非整组）验证末次更新已生效并被下一个时钟使用。
n1b = 5 * cfg.seg_len;
[xt, yt] = channel(gen_4qam(n1b), gen_4qam(n1b), 5);
cfb = dspcma.equalizer.cma_freq_run(xt, yt, cfg1);
ctb = dspcma.equalizer.cma_time_run(xt, yt, cfg1);
upd_ok = max(abs(cfb.final.xx - h_init_default)) > 0 ...
    && rel(cfb.final.xx, ctb.final.xx) <= thresh;
add('更新已生效(5段非整组)', upd_ok, ...
    sprintf('diff=%.2e rel=%.2e', max(abs(cfb.final.xx - h_init_default)), ...
    rel(cfb.final.xx, ctb.final.xx)));

% ---- 3) 多次更新短程运行（20 时钟） ----
cfg2 = cfg;
cfg2.record_taps = true;
n2 = 20 * cfg.par_num * cfg.seg_len;
[xt, yt] = channel(gen_4qam(n2), gen_4qam(n2), 5);
ct = dspcma.equalizer.cma_time_run(xt, yt, cfg2);
cf = dspcma.equalizer.cma_freq_run(xt, yt, cfg2);
e_z = max(rel(cf.zx, ct.zx), rel(cf.zy, ct.zy));
e_th = 0;
for c = 1:ct.clk_num
    e_th = max(e_th, rel(cf.tap_hist.xx(:, c), ct.tap_hist.xx(:, c)));
    e_th = max(e_th, rel(cf.tap_hist.yy(:, c), ct.tap_hist.yy(:, c)));
    e_th = max(e_th, rel(cf.tap_hist.xy(:, c), ct.tap_hist.xy(:, c)));
    e_th = max(e_th, rel(cf.tap_hist.yx(:, c), ct.tap_hist.yx(:, c)));
end
add('20时钟:输出一致', e_z <= thresh, sprintf('%.2e', e_z));
add('20时钟:各时钟抽头一致', e_th <= thresh, sprintf('%.2e', e_th));

% ---- 4) 更新时序: 第 5 段起使用首次更新抽头 ----
h_init = zeros(cfg.tap_len, 1);
h_init((cfg.tap_len + 1) / 2) = 1;   % 默认中心抽头初始化
seq_ok = isequal(cf.tap_hist.xx(:, 1), h_init) ...
    && max(abs(cf.tap_hist.xx(:, 1) - ct.tap_hist.xx(:, 1))) == 0;
% 第 2 时钟抽头 = 初始 + 第 1 时钟累积梯度/par_num（频域口径验证过一致）
diff21 = cf.tap_hist.xx(:, 2) - cf.tap_hist.xx(:, 1);
grad_ok = rel(diff21, ct.tap_hist.xx(:, 2) - ct.tap_hist.xx(:, 1)) <= thresh;
add('更新时序:首时钟=初始抽头', seq_ok, 'col1==init');
add('更新时序:次时钟=初始+梯度/4', grad_ok, sprintf('%.2e', ...
    rel(diff21, ct.tap_hist.xx(:, 2) - ct.tap_hist.xx(:, 1))));

% ---- 5) 非整组尾部: 7 段（最后 3 段梯度丢弃） ----
n3 = 7 * cfg.seg_len;
[xt, yt] = channel(gen_4qam(n3), gen_4qam(n3), 5);
ct = dspcma.equalizer.cma_time_run(xt, yt, cfg1);
cf = dspcma.equalizer.cma_freq_run(xt, yt, cfg1);
tail_ok = isequal(ct.clk_num, 2) && isequal(cf.clk_num, 2);
e_t = max([rel(cf.final.xx, ct.final.xx), rel(cf.final.xy, ct.final.xy)]);
% 最终抽头应等于第 2 时钟快照（尾部梯度未应用）
same_as_last_clock = max(abs(cf.final.xx - cf.tap_hist.xx(:, 2))) == 0 ...
    && max(abs(ct.final.xx - ct.tap_hist.xx(:, 2))) == 0;
add('非整组:时钟数与抽头一致', tail_ok && e_t <= thresh && same_as_last_clock, ...
    sprintf('clk=%d/%d rel=%.2e', cf.clk_num, ct.clk_num, e_t));

% ---- 6) 抽头长度 17/65 的 N_fft 与一致性 ----
for tl = [17 65]
    cfgt = cfg;
    cfgt.tap_len = tl;
    cfgt.record_taps = true;
    n4 = 8 * cfg.par_num * cfg.seg_len;
    [xt, yt] = channel(gen_4qam(n4), gen_4qam(n4), 5);
    ct = dspcma.equalizer.cma_time_run(xt, yt, cfgt);
    cf = dspcma.equalizer.cma_freq_run(xt, yt, cfgt);
    exp_nfft = 2 ^ ceil(log2(cfg.seg_len + tl - 1));
    ok = isequal(cf.N_fft, exp_nfft) ...
        && rel(cf.final.xx, ct.final.xx) <= thresh ...
        && rel(cf.zx, ct.zx) <= thresh;
    add(sprintf('tap=%d: N_fft=%d 一致', tl, exp_nfft), ok, ...
        sprintf('rel=%.2e', max(rel(cf.zx, ct.zx), rel(cf.final.xx, ct.final.xx))));
end

% ---- 7) clk_dly ~= 1 拒绝 ----
cfgd = cfg;
cfgd.clk_dly = 2;
ok_dly = true;
try
    dspcma.equalizer.cma_time_run(x, y, cfgd);
    ok_dly = false;
catch err
    ok_dly = startsWith(err.identifier, 'DSPCMA:cma:clkDly');
end
try
    dspcma.equalizer.cma_freq_run(x, y, cfgd);
    ok_dly = false;
catch err
    ok_dly = ok_dly && startsWith(err.identifier, 'DSPCMA:cma:clkDly');
end
add('clk_dly=2 拒绝', ok_dly, 'DSPCMA:cma:clkDly');
end
