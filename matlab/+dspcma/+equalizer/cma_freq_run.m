function out = cma_freq_run(x, y, cfg)
%CMA_FREQ_RUN 双偏振 2×2 蝶形频域 CMA（滤波与梯度相关均用自编 FFT）。
%
% 与 cma_time_run 语义逐段一致（AGENTS 4.3）:
%   * 滤波: 每段 32 点用重叠保留 (OLS)，FFT 长度 N_fft 为满足
%     N_fft >= seg_len + tap_len - 1 的最小 2 的幂。FFT 缓冲排列为
%     [当前段(0..31) | 补零 | 历史(最高 tap_len-1 个 bin，倒序)]，
%     使 bin b 对应相对时刻 r ≡ b (mod N_fft)；滤波输出取 bin
%     1..seg_len，梯度相关取 bin 1..tap_len，均无循环卷积污染。
%   * 梯度: acc[l] = sum_n step*e[n]*z[n]*conj(input[n-l]) 由
%     ifft(fft(a).*conj(fft(buffer))) 的无污染 bin 直接得到，
%     a = step*e.*z 为段内样本。抽头不取共轭，误差 e = R-|z|^2。
%   * 每 par_num=4 段累积一组梯度，除以 par_num 更新；更新在下一
%     时钟生效（clk_dly=1）；不足整组的尾部梯度按参考口径丢弃。
%   * 抽头以时域向量维护，每时钟变换到频域（特殊单位因子旁路由
%     FFT 内部精确值承担）。
%
% 输入/输出契约与 cma_time_run 相同（zx/zy/errx/erry/taps_final/
% seg_num/clk_num/dropped/N_fft，可选 tap_hist）。
% 仅承诺 clk_dly = 1（DSPCMA:cma:clkDly）。

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

N_fft = 2 ^ ceil(log2(seg_len + tap_len - 1));
hist_len = tap_len - 1;

seg_num = floor(numel(x) / seg_len);
clk_num = ceil(seg_num / par_num);
total_len = seg_len * seg_num;
dropped = numel(x) - total_len;
x = x(1:total_len);
y = y(1:total_len);

hxx = init_tap('xx', tap_len, cfg);
hyy = init_tap('yy', tap_len, cfg);
hxy = init_tap('xy', tap_len, cfg);
hyx = init_tap('yx', tap_len, cfg);

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
    tap_hist_xx(:, 1) = hxx;
    tap_hist_yy(:, 1) = hyy;
    tap_hist_xy(:, 1) = hxy;
    tap_hist_yx(:, 1) = hyx;
end

hist_x = zeros(hist_len, 1);
hist_y = zeros(hist_len, 1);
seg_in_clk = 0;

for k = 1:seg_num
    if seg_in_clk == 0
        % 本时钟内抽头固定（AGENTS 4.3: 更新周期内滤波器冻结）。
        % 快照"本时钟实际使用的抽头"作为 final 语义（与参考
        % xx(:, clk_num) 一致: 末次更新不用于任何段）。
        h_use_xx = hxx; h_use_yy = hyy; h_use_xy = hxy; h_use_yx = hyx;
        Hxx = dspcma.fft.my_fft([hxx; zeros(N_fft - tap_len, 1)]);
        Hxy = dspcma.fft.my_fft([hxy; zeros(N_fft - tap_len, 1)]);
        Hyx = dspcma.fft.my_fft([hyx; zeros(N_fft - tap_len, 1)]);
        Hyy = dspcma.fft.my_fft([hyy; zeros(N_fft - tap_len, 1)]);
    end

    n0 = (k - 1) * seg_len + 1;
    n1 = n0 + seg_len - 1;
    xs = x(n0:n1);
    ys = y(n0:n1);

    % FFT 缓冲: bin 1..seg_len = 当前段(相对 0..seg_len-1)；
    % hist 为最旧在前的历史向量，自然顺序放置后 bin seg_len+j 恰对应
    % 相对时刻 j-(hist_len+1)，即 bin 32+j ↔ x(n0-(hist_len+1-j))。
    % 循环卷积/相关的代表元映射与该排列一致，无污染。
    X = dspcma.fft.my_fft([xs; zeros(N_fft - seg_len - hist_len, 1); hist_x]);
    Y = dspcma.fft.my_fft([ys; zeros(N_fft - seg_len - hist_len, 1); hist_y]);

    % ---- 滤波（重叠保留有效区 = 当前段） ----
    Zx = dspcma.fft.my_ifft(Hxx .* X + Hxy .* Y);
    Zy = dspcma.fft.my_ifft(Hyx .* X + Hyy .* Y);
    zx_seg = Zx(1:seg_len);
    zy_seg = Zy(1:seg_len);
    zx(n0:n1) = zx_seg;
    zy(n0:n1) = zy_seg;

    % ---- 误差与梯度（频域相关，取无污染 bin） ----
    ex = Rx - abs(zx_seg).^2;
    ey = Ry - abs(zy_seg).^2;
    errx(n0:n1) = ex;
    erry(n0:n1) = ey;

    ax = step .* ex .* zx_seg;
    ay = step .* ey .* zy_seg;
    Ax = dspcma.fft.my_fft([ax; zeros(N_fft - seg_len, 1)]);
    Ay = dspcma.fft.my_fft([ay; zeros(N_fft - seg_len, 1)]);
    Gxx = dspcma.fft.my_ifft(Ax .* conj(X));
    Gxy = dspcma.fft.my_ifft(Ax .* conj(Y));
    Gyx = dspcma.fft.my_ifft(Ay .* conj(X));
    Gyy = dspcma.fft.my_ifft(Ay .* conj(Y));
    accxx = accxx + Gxx(1:tap_len);
    accxy = accxy + Gxy(1:tap_len);
    accyx = accyx + Gyx(1:tap_len);
    accyy = accyy + Gyy(1:tap_len);

    % ---- 滑动历史（仅保留输入样本，AGENTS 4.3） ----
    hist_x = [hist_x; xs];
    hist_x = hist_x(end - hist_len + 1:end);
    hist_y = [hist_y; ys];
    hist_y = hist_y(end - hist_len + 1:end);

    seg_in_clk = seg_in_clk + 1;
    if seg_in_clk == par_num
        hxx = hxx + accxx / par_num;
        hyy = hyy + accyy / par_num;
        hxy = hxy + accxy / par_num;
        hyx = hyx + accyx / par_num;
        accxx = zeros(tap_len, 1);
        accyy = zeros(tap_len, 1);
        accxy = zeros(tap_len, 1);
        accyx = zeros(tap_len, 1);
        seg_in_clk = 0;
        if exist('tap_hist_xx', 'var') && ceil((k + 1) / par_num) <= clk_num
            c = ceil((k + 1) / par_num);
            tap_hist_xx(:, c) = hxx;
            tap_hist_yy(:, c) = hyy;
            tap_hist_xy(:, c) = hxy;
            tap_hist_yx(:, c) = hyx;
        end
    end
end

out.zx = zx;
out.zy = zy;
out.errx = errx;
out.erry = erry;
out.seg_num = seg_num;
out.clk_num = clk_num;
out.dropped = dropped;
out.N_fft = N_fft;
out.tap_len = tap_len;
out.final.xx = h_use_xx;
out.final.yy = h_use_yy;
out.final.xy = h_use_xy;
out.final.yx = h_use_yx;
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

function v = init_tap(name, tap_len, cfg)
%INIT_TAP 初始化单支路抽头: 对角支路中心抽头 1，交叉支路 0，可覆盖。
fname = ['h' name '_init'];
v = zeros(tap_len, 1);
if isfield(cfg, fname) && ~isempty(cfg.(fname))
    v = complex(double(cfg.(fname)(:)));
    if numel(v) ~= tap_len
        error('DSPCMA:cma:badInit', '%s 长度须为 %d', fname, tap_len);
    end
elseif strcmp(name, 'xx') || strcmp(name, 'yy')
    v((tap_len + 1) / 2) = 1;
end
end
