function X = my_fft(x)
%MY_FFT 自编基-2 按时间抽取 (DIT) FFT。
%
% X[k] = sum_{n=0}^{N-1} x[n] * exp(-1j*2*pi*k*n/N)。
%
% 输入:
%   x -- 长度为 N 的数值向量（实数或复数；行/列向量均可）。
% 输出:
%   X -- 与 x 同形状的复数向量，自然顺序输出。
%
% 约定:
%   * 仅支持 N 为 2 的幂且 N >= 2（32/128 点为强制验收点，另支持
%     64/256 等长度供卷积使用）。
%   * 结构模拟硬件全并行级联：按级 s = 0..log2(N)-1 逐级计算，同
%     一级内所有蝶形一次性（向量化）完成，与 RTL 的级结构一一对应，
%     各级蝶形索引见 fft_stage_map。
%   * 输入做位倒序重排（仅索引重排，不改数据），输出自然序。
%   * 旋转因子由 twiddle_table 手工生成（基础角 + 对称性/周期性 +
%     精确特殊值），不调用任何 FFT 内置函数。
%
% 错误条件（错误标识 DSPCMA:fft:*）: 非向量、空输入、长度非 2 的幂、
% 含 NaN/Inf、非数值类型。

if ~isvector(x) || isempty(x)
    error('DSPCMA:fft:badShape', '输入必须是非空向量');
end
if ~isnumeric(x) && ~islogical(x)
    error('DSPCMA:fft:badType', '输入必须是数值类型');
end
x = complex(double(x));
if any(~isfinite(x(:)))
    error('DSPCMA:fft:notFinite', '输入含 NaN/Inf');
end

n = numel(x);
if bitand(n, n-1) ~= 0 || n < 2
    error('DSPCMA:fft:badLength', '长度 %d 不是 >= 2 的 2 的幂', n);
end
in_shape = size(x);
x = x(:);   % 内部统一为列向量

% ---- 位倒序重排（DIT 输入） ----
y = x(bit_reverse_index(n) + 1);

% ---- 按级蝶形（模拟硬件各级并行蝶形） ----
stages = log2(n);
for s = 0:stages-1
    half = 2^s;          % 蝶形下臂偏移 / 组内蝶形数
    M = 2 * half;        % 当前级子 DFT 块长
    W = dspcma.fft.twiddle_table(M);   % 包内成员须以全名调用
    for j = 1:half
        w = W(j);
        idx_top = j:M:n;
        idx_bot = idx_top + half;
        t = w .* y(idx_bot);
        y(idx_bot) = y(idx_top) - t;
        y(idx_top) = y(idx_top) + t;
    end
end

X = reshape(y, in_shape);
end

function p = bit_reverse_index(n)
%BIT_REVERSE_INDEX 返回 0-based 位倒序索引表，长度 n 必须为 2 的幂。
bits = log2(n);
p = zeros(1, n);
for i = 0:n-1
    v = i;
    r = 0;
    for b = 1:bits
        r = 2*r + mod(v, 2);
        v = floor(v/2);
    end
    p(i+1) = r;
end
end
