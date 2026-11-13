function e = evm_rms(s, r)
%EVM_RMS 计算 RMS EVM: sqrt(sum(|s-r|^2) / sum(|r|^2))。
%
% s -- 实际（校准后）符号向量; r -- 参考符号向量（同形状）。
% 百分数 = 100*e; dB = 20*log10(e)。零误差允许 e = 0（dB = -Inf 由调
% 用方处理）; 零参考能量 sum(|r|^2) == 0 必须报错（DSPCMA:evm:zeroRef）。

if ~isequal(size(s), size(r)) || isempty(r)
    error('DSPCMA:evm:shapeMismatch', 's 与 r 必须为同形状非空向量');
end
s = double(s(:));
r = double(r(:));
if any(~isfinite(s)) || any(~isfinite(r))
    error('DSPCMA:evm:notFinite', '输入含 NaN/Inf');
end
er = sum(abs(r).^2);
if er == 0
    error('DSPCMA:evm:zeroRef', '参考能量为零，EVM 无定义');
end
e = sqrt(sum(abs(s - r).^2) / er);
end
