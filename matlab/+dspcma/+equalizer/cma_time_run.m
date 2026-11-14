function out = cma_time_run(x, y, cfg)
%CMA_TIME_RUN 双偏振 2×2 蝶形时域 CMA（CMA_reference.m 的函数化基线）。
%
% 语义与 data/reference/CMA_reference.m 完全一致（不取抽头共轭，
% .' 乘法；误差 e = R - |z|^2；更新 mu*e*z*conj(input)；每 par_num
% 段累积梯度后除以 par_num 更新；clk_dly=1 时下一时钟生效）。
%
% z_x[n] = sum_l hxx(l) * x[n-l+1] + hxy(l) * y[n-l+1]  (l = 1..tap_len)
% z_y[n] = sum_l hyx(l) * x[n-l+1] + hyy(l) * y[n-l+1]
%
% 输入:
%   x, y -- 两偏振输入（复数列向量，长度相同）。
%   cfg  -- seg_len/tap_len/clk_dly/par_num/step/Rx/Ry，另可选:
%          .hxx_init/.hxy_init/.hyx_init/.hyy_init（默认中心抽头初始化）
%          .record_taps（默认 false，记录每时钟抽头快照）
% 输出: zx/zy/errx/erry（截断后长度）、taps_final、seg_num/clk_num、
%       dropped（裁去的非整段样本数）、tap_hist（可选）。
%
% 仅承诺 clk_dly = 1；其他值拒绝（DSPCMA:cma:clkDly）。

[x, y] = check_pair(x, y);
seg_len = cfg.seg_len; tap_len = cfg.tap_len;
clk_dly = cfg.clk_dly; par_num = cfg.par_num;
step = cfg.step; Rx = cfg.Rx; Ry = cfg.Ry;
if clk_dly ~= 1
    error('DSPCMA:cma:clkDly', '仅承诺 clk_dly=1（与参考一致），收到 %d', clk_dly);
end
if numel(x) < seg_len
    error('DSPCMA:cma:tooShort', '输入长度 %d 不足一段 (%d 点)', numel(x), seg_len);
end
if ~isscalar(seg_len) || seg_len < 1 || mod(seg_len, 1) ~= 0
    error('DSPCMA:cma:badCfg', 'seg_len 必须为 >= 1 整数');
end
if ~isscalar(tap_len) || tap_len < 1 || mod(tap_len, 2) == 0
    error('DSPCMA:cma:badCfg', 'tap_len 必须为正奇数');
end
if ~isscalar(par_num) || par_num < 1 || mod(par_num, 1) ~= 0
    error('DSPCMA:cma:badCfg', 'par_num 必须为 >= 1 整数');
end
if ~isscalar(step) || step < 0
    error('DSPCMA:cma:badCfg', 'step 必须为非负标量 (0 = 抽头冻结)');
end
if ~isscalar(Rx) || Rx <= 0 || ~isscalar(Ry) || Ry <= 0
    error('DSPCMA:cma:badCfg', 'Rx/Ry 必须为正标量');
end

seg_num = floor(numel(x) / seg_len);
clk_num = ceil(seg_num / par_num);
total_len = seg_len * seg_num;
dropped = numel(x) - total_len;
x = x(1:total_len);
y = y(1:total_len);

xp = [zeros(tap_len - 1, 1); x];
yp = [zeros(tap_len - 1, 1); y];

taps = init_taps(tap_len, cfg, clk_num, clk_dly);
xx = taps.xx; yy = taps.yy; xy = taps.xy; yx = taps.yx;

zx = zeros(total_len, 1);
zy = zeros(total_len, 1);
errx = zeros(total_len, 1);
erry = zeros(total_len, 1);

accxx = zeros(tap_len, 1);
accyy = zeros(tap_len, 1);
accxy = zeros(tap_len, 1);
accyx = zeros(tap_len, 1);

if isfield(cfg, 'record_taps') && cfg.record_taps
    tap_hist_xx = zeros(tap_len, clk_num);
    tap_hist_yy = zeros(tap_len, clk_num);
    tap_hist_xy = zeros(tap_len, clk_num);
    tap_hist_yx = zeros(tap_len, clk_num);
    tap_hist_xx(:, 1) = xx(:, 1);
    tap_hist_yy(:, 1) = yy(:, 1);
    tap_hist_xy(:, 1) = xy(:, 1);
    tap_hist_yx(:, 1) = yx(:, 1);
end

for k = 1:seg_num
    clk_pos = ceil(k / par_num);
    xx_curr = xx(:, clk_pos);
    yy_curr = yy(:, clk_pos);
    xy_curr = xy(:, clk_pos);
    yx_curr = yx(:, clk_pos);
    for i = 1:seg_len
        cur = (k - 1) * seg_len + i;
        pidx = cur + tap_len - 1;
        input_x = xp(pidx:-1:pidx - tap_len + 1);
        input_y = yp(pidx:-1:pidx - tap_len + 1);
        zx(cur) = xx_curr.' * input_x + xy_curr.' * input_y;
        zy(cur) = yx_curr.' * input_x + yy_curr.' * input_y;
        errx(cur) = Rx - abs(zx(cur))^2;
        erry(cur) = Ry - abs(zy(cur))^2;
        accxx = accxx + step * errx(cur) * zx(cur) * conj(input_x);
        accyy = accyy + step * erry(cur) * zy(cur) * conj(input_y);
        accxy = accxy + step * errx(cur) * zx(cur) * conj(input_y);
        accyx = accyx + step * erry(cur) * zy(cur) * conj(input_x);
    end
    if mod(k, par_num) == 0
        upd = clk_pos + clk_dly;
        xx(:, upd) = xx(:, upd - 1) + accxx / par_num;
        yy(:, upd) = yy(:, upd - 1) + accyy / par_num;
        xy(:, upd) = xy(:, upd - 1) + accxy / par_num;
        yx(:, upd) = yx(:, upd - 1) + accyx / par_num;
        accxx = zeros(tap_len, 1);
        accyy = zeros(tap_len, 1);
        accxy = zeros(tap_len, 1);
        accyx = zeros(tap_len, 1);
    end
    if exist('tap_hist_xx', 'var') && mod(k, par_num) == 0 && clk_pos < clk_num
        c = clk_pos + 1;
        tap_hist_xx(:, c) = xx(:, c);
        tap_hist_yy(:, c) = yy(:, c);
        tap_hist_xy(:, c) = xy(:, c);
        tap_hist_yx(:, c) = yx(:, c);
    end
end

out.zx = zx;
out.zy = zy;
out.errx = errx;
out.erry = erry;
out.seg_num = seg_num;
out.clk_num = clk_num;
out.dropped = dropped;
out.tap_len = tap_len;
out.final.xx = xx(:, clk_num);
out.final.yy = yy(:, clk_num);
out.final.xy = xy(:, clk_num);
out.final.yx = yx(:, clk_num);
if exist('tap_hist_xx', 'var')
    out.tap_hist.xx = tap_hist_xx;
    out.tap_hist.yy = tap_hist_yy;
    out.tap_hist.xy = tap_hist_xy;
    out.tap_hist.yx = tap_hist_yx;
end
end

function [x, y] = check_pair(x, y)
if ~isvector(x) || ~isvector(y) || isempty(x) || isempty(y)
    error('DSPCMA:cma:badShape', 'x 与 y 必须为非空向量');
end
if numel(x) ~= numel(y)
    error('DSPCMA:cma:shapeMismatch', 'x 与 y 长度不同');
end
if any(~isfinite(x(:))) || any(~isfinite(y(:)))
    error('DSPCMA:cma:notFinite', '输入含 NaN/Inf');
end
x = complex(double(x(:)));   % 两路统一转列向量并返回 (F06 整改)
y = complex(double(y(:)));
end

function t = init_taps(tap_len, cfg, clk_num, clk_dly)
%INIT_TAPS 抽头初始化: 对角支路中心抽头 1，交叉支路 0；可由 cfg 覆盖。
n_col = clk_num + clk_dly;
t = struct('xx', [], 'yy', [], 'xy', [], 'yx', []);
names = {'xx', 'yy', 'xy', 'yx'};
for a = 1:4
    M = zeros(tap_len, n_col);
    fname = ['h' names{a} '_init'];
    if isfield(cfg, fname) && ~isempty(cfg.(fname))
        v = complex(double(cfg.(fname)(:)));
        if numel(v) ~= tap_len
            error('DSPCMA:cma:badInit', '%s 长度须为 %d', fname, tap_len);
        end
        M(:, 1) = v;
    elseif a <= 2   % xx / yy: 中心抽头 1
        M((tap_len + 1) / 2, 1) = 1;
    end
    t.(names{a}) = M;
end
end
