function x = my_ifft(X)
%MY_IFFT 自编基-2 逆 FFT。
%
% x[n] = (1/N) * sum_{k=0}^{N-1} X[k] * exp(+1j*2*pi*k*n/N)。
%
% 通过自编 FFT 的共轭关系实现: ifft(X) = conj(fft(conj(X))) / N，
% 缩放 1/N 只在本函数末端执行。
%
% 输入/输出形状与错误条件与 my_fft 一致；输出与输入同形状。

if ~isvector(X) || isempty(X)
    error('DSPCMA:fft:badShape', '输入必须是非空向量');
end
if ~isnumeric(X) && ~islogical(X)
    error('DSPCMA:fft:badType', '输入必须是数值类型');
end
if any(~isfinite(X(:)))
    error('DSPCMA:fft:notFinite', '输入含 NaN/Inf');
end
n = numel(X);
if bitand(n, n-1) ~= 0 || n < 2
    error('DSPCMA:fft:badLength', '长度 %d 不是 >= 2 的 2 的幂', n);
end

x = conj(dspcma.fft.my_fft(conj(X))) / n;   % 包内成员须以全名调用
end
