function [W, info] = twiddle_table(M)
%TWIDDLE_TABLE 手工生成旋转因子表 W_M^m = exp(-1j*2*pi*m/M)，m = 0..M-1。
%
% 输入:
%   M -- 表长度，必须为 2 的幂且 M >= 2。
% 输出:
%   W    -- M×1 复数列向量，W(m+1) = W_M^m。
%   info -- 结构体:
%     .base_angle_calls -- sin/cos 基础角调用次数（m = 0..floor(M/4)）。
%     .special_idx      -- 被替换为精确特殊值的索引（1-based，对应 m+1）。
%     .special_values   -- 与 special_idx 对应的精确值 {1,-1j,-1,1j}。
%
% 优化方式（B02：利用对称性与周期性）:
%   1) 仅对 m = 0..floor(M/4) 调用 cos/sin 计算基础角；
%   2) 第二象限 m∈(M/4, M/2): W^m = -conj(W^(M/2-m))（半周期因子与共轭对称）;
%   3) 后半周期 m∈[M/2, M): W^m = -W^(m-M/2)（周期 M/2 的符号翻转）;
%   4) 特殊因子 m = 0, M/4, M/2, 3M/4 直接置精确值 1, -1j, -1, 1j，
%      避免人为浮点噪声（与 RTL 特殊因子旁路对应）。
%
% 不借助任何 FFT 内置函数。基础角直接使用 cos/sin，课程未要求 CORDIC。

if ~isscalar(M) || ~isnumeric(M) || M < 2 || M ~= floor(M)
    error('DSPCMA:twiddle:badLength', 'M 必须为 >= 2 的整数标量');
end
if bitand(M, M-1) ~= 0
    error('DSPCMA:twiddle:notPowerOfTwo', 'M 必须为 2 的幂，收到 %d', M);
end

M = double(M);
W = zeros(M, 1);
quarter = floor(M/4);

special_idx = [];
special_values = {};
% 精确特殊值（m = 0, M/4, M/2, 3M/4）
special_idx = [special_idx, 1];                special_values{end+1} = 1;
if mod(M, 4) == 0
    special_idx = [special_idx, M/4 + 1];      special_values{end+1} = -1j;
end
special_idx = [special_idx, M/2 + 1];          special_values{end+1} = -1;
if mod(M, 4) == 0
    special_idx = [special_idx, 3*M/4 + 1];    special_values{end+1} = 1j;
end

% 第一象限（含端点）：基础角调用
for m = 0:quarter
    ang = -2*pi*m/M;
    W(m+1) = cos(ang) + 1j*sin(ang);
end
base_angle_calls = quarter + 1;

% 第二象限: W^m = -conj(W^(M/2 - m)), m ∈ (M/4, M/2)
for m = (quarter+1):(M/2-1)
    W(m+1) = -conj(W(M/2 - m + 1));
end

% 后半周期: W^m = -W^(m - M/2), m ∈ [M/2, M)
for m = M/2:(M-1)
    W(m+1) = -W(m - M/2 + 1);
end

% 覆盖精确特殊值
for k = 1:numel(special_idx)
    W(special_idx(k)) = special_values{k};
end

info.base_angle_calls = base_angle_calls;
info.special_idx = special_idx;
info.special_values = special_values;
end
