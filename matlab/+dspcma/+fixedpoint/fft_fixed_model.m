function [Y, stats] = fft_fixed_model(X, N)
%FFT_FIXED_MODEL 自编 FFT 的定点整数模型（RTL 逐位参考，AGENTS 5）。
%
% 复现计划中 RTL 的每一级整数运算:
%   * 输入 8 bit 有符号整数 X(k)（Q0），内部左移 8 位存为 Q8 16 bit；
%   * 每级蝶形: 乘积 = W(Q15, 16 bit) x B(Q8, 16 bit)，整数精确 31 bit
%     （对应 DSP48E2 原语 16x16 无舍入乘法）；特殊因子 ±1/±1j 旁路
%     （精确移位/交换，spec 1..4，无量化）；
%   * 蝶形和 = a<<15 ± W·b（Q23，33 bit 中间量）；
%   * 每级缩放 1/2：round_half_even(sum / 2^16) 存回 Q8 16 bit，
%     饱和 [-32768, 32767] 并计数；
%   * S 级后累计缩放 1/2^S = 1/N：输出 round_half_even(Q8 / 2^8)
%     饱和到 8 bit 并计数。即 Y ≈ round(FFT(X)/N)。
%
% 输入:
%   X -- N×1 (或 1×N) 有符号整数向量（[-128, 127]）。
%   N -- 点数（2 的幂，>= 2）。
% 输出:
%   Y     -- N×1 8 bit 有符号整数列向量。
%   stats -- .stage_saturate (S×1 各级饱和次数), .final_saturate,
%            .N, .stages。
%
% 与 RTL 的对应关系详见 docs/architecture.md 定点表；本模型必须与
% Verilog 仿真逐位一致。

X = double(X(:));
if numel(X) ~= N
    error('DSPCMA:fixedpoint:shape', 'X 长度须为 %d', N);
end
if any(X ~= round(X)) || any(X < -128) || any(X > 127)
    error('DSPCMA:fixedpoint:range', 'X 必须为 [-128,127] 的整数');
end
if bitand(N, N-1) ~= 0 || N < 2
    error('DSPCMA:fixedpoint:badN', 'N 必须为 >= 2 的 2 的幂');
end

stages = log2(N);
% 位倒序输入置换（RTL 中为纯布线，不改数据值）
xr = real(X); xi = imag(X);
xbr_re = zeros(N, 1);
xbr_im = zeros(N, 1);
for k = 0:N-1
    v = k; r = 0;
    for b = 1:log2(N)
        r = 2*r + mod(v, 2);
        v = floor(v/2);
    end
    xbr_re(r+1) = xr(k+1);
    xbr_im(r+1) = xi(k+1);
end
% 输入 Q8 化（精确）
yr = xbr_re * 256;
yi = xbr_im * 256;

stats.stage_saturate = zeros(stages, 1);

for s = 0:stages-1
    half = 2^s;
    M = 2 * half;
    nr = yr; ni = yi;               % 本级输入快照（硬件为并行寄存器）
    for start = 1:M:N
        for j = 1:half
            p = start + j - 1;      % 顶臂（1-based）
            q = p + half;           % 底臂
            m = j - 1;              % 旋转因子幂次
            [W, spec] = dspcma.fixedpoint.twiddle_q15(M, m);
            % ---- 复数乘法 W·b（b = 底臂输入） ----
            [mre, mim] = cmul(W, spec, nr(q), ni(q));
            % ---- 蝶形和（Q23）: 顶臂 a + W·b，底臂 a - W·b ----
            sum_re_t = nr(p) * 2^15 + mre;
            sum_im_t = ni(p) * 2^15 + mim;
            sum_re_b = nr(p) * 2^15 - mre;
            sum_im_b = ni(p) * 2^15 - mim;
            % ---- 缩放 1/2 + 舍入回 Q8 ----
            [yr(p), sre] = q23_to_q8(sum_re_t);
            [yr(q), sre2] = q23_to_q8(sum_re_b);
            [yi(p), sim] = q23_to_q8(sum_im_t);
            [yi(q), sim2] = q23_to_q8(sum_im_b);
            stats.stage_saturate(s+1) = stats.stage_saturate(s+1) + ...
                sre + sre2 + sim + sim2;
        end
    end
end

% ---- 输出 Q8 -> 8 bit ----
Yr = zeros(N, 1); Yi = zeros(N, 1);
nsat = 0;
for k = 1:N
    [Yr(k), s1] = q8_to_s8(yr(k));
    [Yi(k), s2] = q8_to_s8(yi(k));
    nsat = nsat + s1 + s2;
end
stats.final_saturate = nsat;
stats.N = N;
stats.stages = stages;
Y = Yr + 1j * Yi;
end

function [mre, mim] = cmul(W, spec, bre, bim)
%CMUL 旋转因子乘法（精确整数，对应 DSP48E2 16x16 与旁路路径）。
switch spec
    case 1   % +1
        mre = bre * 2^15;
        mim = bim * 2^15;
    case 2   % -1
        mre = -bre * 2^15;
        mim = -bim * 2^15;
    case 3   % -1j:  -j*(br+j*bi) = bi - j*br
        mre = bim * 2^15;
        mim = -bre * 2^15;
    case 4   % +1j:  j*(br+j*bi) = -bi + j*br
        mre = -bim * 2^15;
        mim = bre * 2^15;
    otherwise
        wr = W(1); wi = W(2);
        p1 = wr * bre;   % 精确 16x16 -> 31 bit
        p2 = wi * bim;
        p3 = wr * bim;
        p4 = wi * bre;
        mre = p1 - p2;
        mim = p3 + p4;
end
end

function [q, sat] = q23_to_q8(t)
%Q23_TO_Q8 round_half_even(t / 2^16)，饱和 16 bit 有符号。
base = floor(t / 2^16);          % 算术下取整（对应负数右移）
rem = t - base * 2^16;           % [0, 65535]
if rem > 32768
    q = base + 1;
elseif rem < 32768
    q = base;
else
    q = base + mod(abs(base), 2);   % 恰半: 向偶数舍入
end
if q > 32767
    q = 32767;
    sat = 1;
elseif q < -32768
    q = -32768;
    sat = 1;
else
    sat = 0;
end
end

function [o, sat] = q8_to_s8(v)
%Q8_TO_S8 round_half_even(v / 2^8)，饱和 8 bit 有符号。
base = floor(v / 256);
rem = v - base * 256;
if rem > 128
    o = base + 1;
elseif rem < 128
    o = base;
else
    o = base + mod(abs(base), 2);
end
if o > 127
    o = 127;
    sat = 1;
elseif o < -128
    o = -128;
    sat = 1;
else
    sat = 0;
end
end
