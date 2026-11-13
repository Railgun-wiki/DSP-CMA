function y = ola_conv(x, h, N, B)
%OLA_CONV 重叠相加 (Overlap-Add) 快速线性卷积（B04）。
%
% 仅调用自编 my_fft/my_ifft（FFT -> 频域相乘 -> IFFT），与直接卷积
% conv_direct 结果一致，输出完整线性卷积 y[n]，长度
% length(x) + length(h) - 1。
%
% 输入:
%   x -- 输入信号向量（可为复数）。
%   h -- 滤波器向量（可为复数）。
%   N -- FFT 长度，2 的幂。
%   B -- 可选，输入块长，默认 B = N - (length(h)-1)。
% 约束: N >= B + length(h) - 1（否则循环卷积污染，报错）。
%
% 索引示意（1-based）:
%   输入块 b 占 x[(b-1)*B+1 : b*B]（尾部不足补零）；
%   该块与 h 的卷积共 B+L-1 个输出 Y(1:B+L-1)，整体累加进全局输出
%   y[(b-1)*B+1 : (b-1)*B+B+L-2]：前 B 点为本块"新增"输出，尾部
%   L-1 点落在后续块的输出区间内重叠相加（累加区）。
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
y = zeros(Ly, 1);
n0 = 1;   % 当前块第一个输入样本的全局索引
while n0 <= Lx
    xb = x(n0:min(n0 + B - 1, Lx));
    nb = numel(xb);
    X = dspcma.fft.my_fft([xb; zeros(N - nb, 1)]);
    Y = dspcma.fft.my_ifft(H .* X);
    keep = min(B + L - 1, Ly - n0 + 1);   % 整块卷积累加（含尾部重叠区）
    y(n0:n0 + keep - 1) = y(n0:n0 + keep - 1) + Y(1:keep);
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
