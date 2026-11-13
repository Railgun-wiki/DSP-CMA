function [W, spec] = twiddle_q15(M, m)
%TWIDDLE_Q15 定点旋转因子: 返回 (stage 内幂次 m, 块长 M) 的 Q15 量化值。
%
% W  = [w_re, w_im]，16 bit 有符号 Q15（量化 round(w*2^15)）。
% spec = 0 普通（乘法器路径）; 1=+1, 2=-1, 3=-1j, 4=+1j（旁路路径，
% 与 RTL bfly2 的特殊因子处理一致；+1 在 Q15 中不可表示，故旁路）。
%
% 量化: w_q = round(w*2^15)，饱和到 [-32768, 32767]；非特殊因子的
% 实虚部均严格小于 1，量化结果在 ±32767 内。

if mod(M, 2) ~= 0 || M < 2
    error('DSPCMA:fixedpoint:badM', 'M 必须为 >= 2 的 2 的幂');
end
w = exp(-1j * 2 * pi * m / M);
spec = 0; W = [0, 0];
if m == 0
    spec = 1;
elseif M >= 4 && m == M/4
    spec = 3;    % exp(-1j*pi/2) = -1j
elseif m == M/2
    spec = 2;
elseif M >= 4 && m == 3*M/4
    spec = 4;    % exp(-1j*3*pi/2) = +1j
else
    W = q15_pair(w);
end
end

function W = q15_pair(w)
wr = round(real(w) * 2^15);
wi = round(imag(w) * 2^15);
wr = min(max(wr, -32768), 32767);
wi = min(max(wi, -32768), 32767);
W = [wr, wi];
end
