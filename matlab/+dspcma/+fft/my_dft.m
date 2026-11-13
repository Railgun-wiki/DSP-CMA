function X = my_dft(x)
%MY_DFT 手写 O(N^2) 离散傅里叶变换（独立验证 oracle）。
%
% X[k] = sum_{n=0}^{N-1} x[n] * exp(-1j*2*pi*k*n/N)。
%
% 直接按定义用显式矩阵求和实现，不使用任何 FFT 算法或内置 FFT 函数；
% 仅用于验证 my_fft/my_ifft 的正确性（AGENTS 规定的默认验收 oracle）。
% 支持任意 N >= 1。输入输出均为与输入同形状的向量。

if ~isvector(x) || isempty(x)
    error('DSPCMA:dft:badShape', '输入必须是非空向量');
end
x = complex(double(x));
if any(~isfinite(x(:)))
    error('DSPCMA:dft:notFinite', '输入含 NaN/Inf');
end
n = numel(x);
in_shape = size(x);
x = x(:);
k_col = (0:n-1).';                    % k
n_row = 0:n-1;                        % n
Wmat = exp(-1j * 2 * pi * (k_col * n_row) / n);   % N×N 旋转矩阵
X = Wmat * x;
X = reshape(X, in_shape);
end
