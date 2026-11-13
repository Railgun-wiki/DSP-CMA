function y = ols_conv(x, h, N, B)
%OLS_CONV 重叠保留 (Overlap-Save) 快速线性卷积（B04）。
%
% 仅调用自编 my_fft/my_ifft（FFT -> 频域相乘 -> IFFT），与直接卷积
% conv_direct 结果一致，输出完整线性卷积 y[n]，长度
% length(x) + length(h) - 1。
%
% 输入:
%   x -- 输入信号向量（可为复数）。
%   h -- 滤波器向量（可为复数）。
%   N -- FFT 长度，2 的幂。
%   B -- 可选，每块有效输出数，默认 B = N - (length(h)-1)。
% 约束: N >= B + length(h) - 1（否则循环卷积污染，报错）。
%
% 索引示意（1-based）:
%   历史区 hist = 上一块末尾 L-1 个真实输入样本（首块为全零，
%   与直接卷积左侧补零一致）；当前区 cur 为本块 B 个输入（尾部不足
%   补零）。FFT 缓冲 buf = [hist, cur] 恰为 N 点；循环卷积输出中
%   仅 Y(L : L+B-1)（共 B 点）为无污染有效区，对应全局输出
%   y[n0 : n0+B-1]；前 L-1 点为被循环卷积污染的历史区，丢弃。
%
% 错误条件（DSPCMA:conv:*）: 空输入、非向量、N 非 2 的幂、
% N < B+L-1、N < L。

if nargin < 4
    B = [];
end
[x, h, N, B] = check_conv_args(x, h, N, B);
L = numel(h);
Lx = numel(x);
Ly = Lx + L - 1;

H = dspcma.fft.my_fft([h; zeros(N - L, 1)]);
% 尾部冲刷：末块之后补 L-1 个零输入，使最后的尾部输出也落入某块
% 有效区，避免丢失；输出最终截断到 Ly。
x_ext = [x; zeros(L - 1, 1)];
Lx_ext = numel(x_ext);
y = zeros(Ly, 1);
hist = zeros(L - 1, 1);   % 历史区（真实输入样本）
n0 = 1;                   % 当前块第一个输入样本的全局索引
while n0 <= Lx_ext
    i_end = min(n0 + B - 1, Lx_ext);
    cur = x_ext(n0:i_end);
    nb = numel(cur);
    buf = [hist; cur; zeros(N - L + 1 - nb, 1)];
    Y = dspcma.fft.my_ifft(H .* dspcma.fft.my_fft(buf));
    keep = min(B, Ly - n0 + 1);
    if keep > 0
        y(n0:n0 + keep - 1) = Y(L:L + keep - 1);
    end
    tail = x_ext(max(1, i_end - L + 2):i_end);
    hist = [zeros(L - 1 - numel(tail), 1); tail];   % 旧样本在前，不足补零
    n0 = n0 + B;
end
end

function [x, h, N, B] = check_conv_args(x, h, N, B)
if ~isvector(x) || ~isvector(h) || isempty(x) || isempty(h)
    error('DSPCMA:conv:badShape', 'x 与 h 必须为非空向量');
end
if ~isnumeric(x) || ~isnumeric(h)
    error('DSPCMA:conv:badType', 'x 与 h 必须为数值类型');
end
if any(~isfinite(x(:))) || any(~isfinite(h(:)))
    error('DSPCMA:conv:notFinite', '输入含 NaN/Inf');
end
if ~isscalar(N) || N < 2 || bitand(N, N-1) ~= 0
    error('DSPCMA:conv:badN', 'N 必须为 >= 2 的 2 的幂');
end
L = numel(h);
if N < L
    error('DSPCMA:conv:badN', 'N=%d 小于滤波器长度 %d', N, L);
end
if isempty(B)
    B = N - L + 1;
end
if ~isscalar(B) || B < 1 || B ~= floor(B)
    error('DSPCMA:conv:badBlock', '块长 B 必须为 >= 1 的整数');
end
if N < B + L - 1
    error('DSPCMA:conv:badN', 'N=%d 不满足 N >= B+L-1 = %d（循环卷积污染）', N, B + L - 1);
end
x = complex(double(x(:)));
h = complex(double(h(:)));
end
